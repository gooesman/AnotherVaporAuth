#include "steam_client_bridge.h"

#include <windows.h>
#include <aclapi.h>
#include <tlhelp32.h>

#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <cstdint>
#include <cstring>
#include <limits>
#include <optional>
#include <string>
#include <utility>
#include <vector>

namespace {

using Value = flutter::EncodableValue;
using Map = flutter::EncodableMap;
using Result = flutter::MethodResult<Value>;

constexpr wchar_t kSteamKey[] = L"Software\\Valve\\Steam";
constexpr wchar_t kAutoLoginUser[] = L"AutoLoginUser";
constexpr wchar_t kRememberPassword[] = L"RememberPassword";
constexpr DWORD kMaxRegistryBytes = 65536;

struct Error {
  std::string code;
  std::string message;
  DWORD win32_error = ERROR_SUCCESS;
  DWORD rollback_error = ERROR_SUCCESS;
};

struct RegistryValue {
  bool exists = false;
  DWORD type = REG_NONE;
  std::vector<BYTE> bytes;
};

class Handle {
 public:
  explicit Handle(HANDLE value) : value_(value) {}
  ~Handle() {
    if (value_ != nullptr && value_ != INVALID_HANDLE_VALUE) {
      CloseHandle(value_);
    }
  }
  Handle(const Handle&) = delete;
  Handle& operator=(const Handle&) = delete;
  HANDLE get() const { return value_; }

 private:
  HANDLE value_;
};

class RegistryKey {
 public:
  ~RegistryKey() {
    if (value != nullptr) {
      RegCloseKey(value);
    }
  }
  HKEY value = nullptr;
};

void ReportError(Result* result, const Error& error) {
  Map details;
  if (error.win32_error != ERROR_SUCCESS) {
    details[Value("win32Error")] = Value(static_cast<int64_t>(error.win32_error));
  }
  if (error.rollback_error != ERROR_SUCCESS) {
    details[Value("rollbackWin32Error")] =
        Value(static_cast<int64_t>(error.rollback_error));
  }
  result->Error(error.code, error.message, Value(details));
}

bool ToWide(const std::string& input, std::wstring* output, Error* error) {
  if (input.find('\0') != std::string::npos ||
      input.size() > static_cast<size_t>((std::numeric_limits<int>::max)())) {
    *error = {"invalid_arguments", "Invalid text argument."};
    return false;
  }
  if (input.empty()) {
    output->clear();
    return true;
  }
  const int length = static_cast<int>(input.size());
  const int count = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                                       input.data(), length, nullptr, 0);
  if (count == 0) {
    *error = {"invalid_arguments", "Text must be valid UTF-8.", GetLastError()};
    return false;
  }
  output->resize(static_cast<size_t>(count));
  if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, input.data(), length,
                          output->data(), count) == 0) {
    *error = {"invalid_arguments", "Could not decode text.", GetLastError()};
    return false;
  }
  return true;
}

bool ToUtf8(const std::wstring& input, std::string* output, Error* error) {
  if (input.empty()) {
    output->clear();
    return true;
  }
  const int length = static_cast<int>(input.size());
  const int count = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS,
                                       input.data(), length, nullptr, 0,
                                       nullptr, nullptr);
  if (count == 0) {
    *error = {"invalid_text", "Windows returned invalid Unicode text.",
              GetLastError()};
    return false;
  }
  output->resize(static_cast<size_t>(count));
  if (WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, input.data(), length,
                          output->data(), count, nullptr, nullptr) == 0) {
    *error = {"invalid_text", "Could not encode Windows text.", GetLastError()};
    return false;
  }
  return true;
}

bool EqualPath(const std::wstring& left, const std::wstring& right) {
  return CompareStringOrdinal(left.c_str(), static_cast<int>(left.size()),
                              right.c_str(), static_cast<int>(right.size()),
                              TRUE) == CSTR_EQUAL;
}

std::wstring ParentPath(const std::wstring& path) {
  const size_t separator = path.find_last_of(L"\\/");
  if (separator == 2 && path[1] == L':') {
    return path.substr(0, 3);
  }
  return separator == std::wstring::npos ? L"" : path.substr(0, separator);
}

std::wstring BaseName(const std::wstring& path) {
  const size_t separator = path.find_last_of(L"\\/");
  return path.substr(separator == std::wstring::npos ? 0 : separator + 1);
}

// Resolve junctions and symbolic links so process matching cannot mistake
// another installation for the selected one.
bool CanonicalFile(const std::wstring& path, std::wstring* canonical,
                   Error* error) {
  Handle file(CreateFileW(path.c_str(), FILE_READ_ATTRIBUTES,
                          FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                          nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr));
  if (file.get() == INVALID_HANDLE_VALUE) {
    *error = {"invalid_steam_path", "Could not open the Steam executable.",
              GetLastError()};
    return false;
  }
  BY_HANDLE_FILE_INFORMATION info{};
  if (!GetFileInformationByHandle(file.get(), &info)) {
    *error = {"invalid_steam_path", "Could not inspect the Steam executable.",
              GetLastError()};
    return false;
  }
  if ((info.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0) {
    *error = {"invalid_steam_path", "The Steam executable is not a file."};
    return false;
  }
  const DWORD length = GetFinalPathNameByHandleW(file.get(), nullptr, 0,
                                                FILE_NAME_NORMALIZED);
  if (length == 0) {
    *error = {"invalid_steam_path", "Could not resolve the Steam executable.",
              GetLastError()};
    return false;
  }
  std::vector<wchar_t> buffer(static_cast<size_t>(length) + 1);
  const DWORD written = GetFinalPathNameByHandleW(
      file.get(), buffer.data(), static_cast<DWORD>(buffer.size()),
      FILE_NAME_NORMALIZED);
  if (written == 0 || written >= buffer.size()) {
    *error = {"invalid_steam_path", "Could not resolve the Steam executable.",
              written == 0 ? GetLastError() : ERROR_INSUFFICIENT_BUFFER};
    return false;
  }
  *canonical = std::wstring(buffer.data(), written);
  if (canonical->rfind(L"\\\\?\\UNC\\", 0) == 0) {
    *canonical = L"\\\\" + canonical->substr(8);
  } else if (canonical->rfind(L"\\\\?\\", 0) == 0) {
    *canonical = canonical->substr(4);
  }
  return true;
}

bool ValidateDirectory(std::wstring directory, std::wstring* executable,
                       Error* error) {
  std::replace(directory.begin(), directory.end(), L'/', L'\\');
  const bool drive_path = directory.size() >= 3 && directory[1] == L':' &&
                          directory[2] == L'\\';
  const bool unc_path = directory.size() > 2 && directory[0] == L'\\' &&
                        directory[1] == L'\\';
  if ((!drive_path && !unc_path) || directory.find(L'"') != std::wstring::npos ||
      directory.find(L'\0') != std::wstring::npos || directory.size() > 32000) {
    *error = {"invalid_steam_path", "Choose an absolute Steam installation path."};
    return false;
  }
  while (!directory.empty() && directory.back() == L'\\') {
    directory.pop_back();
  }
  if (!CanonicalFile(directory + L"\\steam.exe", executable, error)) {
    return false;
  }
  if (!EqualPath(BaseName(*executable), L"steam.exe")) {
    *error = {"invalid_steam_path", "The selected file does not resolve to steam.exe."};
    return false;
  }
  return true;
}

bool ReadRegistryValue(HKEY key, const wchar_t* name, RegistryValue* value,
                       Error* error) {
  // A value may grow between the size query and read. Retry a bounded number
  // of times, and fail safely if another process keeps changing it.
  for (int attempt = 0; attempt < 3; ++attempt) {
    DWORD length = 0;
    DWORD type = REG_NONE;
    LSTATUS status = RegQueryValueExW(key, name, nullptr, &type, nullptr, &length);
    if (status == ERROR_FILE_NOT_FOUND) {
      *value = RegistryValue{};
      return true;
    }
    if (status != ERROR_SUCCESS || length > kMaxRegistryBytes) {
      *error = {"registry_read_failed", "Could not read Steam login settings.",
                status != ERROR_SUCCESS ? static_cast<DWORD>(status) : ERROR_INVALID_DATA};
      return false;
    }
    // Keep a non-null buffer even for a zero-byte value: otherwise the second
    // call becomes another size query and could silently miss a concurrent edit.
    std::vector<BYTE> bytes((std::max)(static_cast<size_t>(length), size_t{1}));
    status = RegQueryValueExW(key, name, nullptr, &type, bytes.data(), &length);
    if (status == ERROR_MORE_DATA) {
      continue;
    }
    if (status == ERROR_FILE_NOT_FOUND) {
      *value = RegistryValue{};
      return true;
    }
    if (status != ERROR_SUCCESS) {
      *error = {"registry_read_failed", "Could not read Steam login settings.",
                static_cast<DWORD>(status)};
      return false;
    }
    bytes.resize(length);
    *value = RegistryValue{true, type, std::move(bytes)};
    return true;
  }
  *error = {"registry_read_failed", "Steam login settings changed during the read.",
            ERROR_MORE_DATA};
  return false;
}

bool RegistryString(const RegistryValue& value, std::wstring* text,
                    Error* error) {
  if ((value.type != REG_SZ && value.type != REG_EXPAND_SZ) ||
      value.bytes.size() % sizeof(wchar_t) != 0) {
    *error = {"registry_read_failed", "A Steam registry value has an unexpected type.",
              ERROR_INVALID_DATA};
    return false;
  }
  text->resize(value.bytes.size() / sizeof(wchar_t));
  if (!value.bytes.empty()) {
    memcpy(text->data(), value.bytes.data(), value.bytes.size());
  }
  while (!text->empty() && text->back() == L'\0') {
    text->pop_back();
  }
  if (text->find(L'\0') != std::wstring::npos) {
    *error = {"registry_read_failed", "A Steam registry string contains invalid data.",
              ERROR_INVALID_DATA};
    return false;
  }
  return true;
}

LSTATUS StoreRegistryValue(HKEY key, const wchar_t* name,
                           const RegistryValue& value) {
  if (!value.exists) {
    const LSTATUS status = RegDeleteValueW(key, name);
    return status == ERROR_FILE_NOT_FOUND ? ERROR_SUCCESS : status;
  }
  return RegSetValueExW(key, name, 0, value.type, value.bytes.data(),
                        static_cast<DWORD>(value.bytes.size()));
}

const Value* FindArgument(const Map& arguments, const char* name) {
  const auto found = arguments.find(Value(name));
  return found == arguments.end() ? nullptr : &found->second;
}

bool PathArgument(const Map& arguments, std::wstring* executable, Error* error) {
  const Value* value = FindArgument(arguments, "path");
  const auto* text = value == nullptr ? nullptr : std::get_if<std::string>(value);
  if (text == nullptr) {
    *error = {"invalid_arguments", "A Steam installation path is required."};
    return false;
  }
  std::wstring directory;
  return ToWide(*text, &directory, error) &&
          ValidateDirectory(directory, executable, error);
}

bool IsRunning(const std::wstring& executable, bool* running, Error* error) {
  *running = false;
  Handle snapshot(CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0));
  if (snapshot.get() == INVALID_HANDLE_VALUE) {
    *error = {"process_query_failed", "Could not check whether Steam is running.",
              GetLastError()};
    return false;
  }
  PROCESSENTRY32W entry{};
  entry.dwSize = static_cast<DWORD>(sizeof(entry));
  if (!Process32FirstW(snapshot.get(), &entry)) {
    const DWORD status = GetLastError();
    if (status == ERROR_NO_MORE_FILES) {
      return true;
    }
    *error = {"process_query_failed", "Could not list running processes.", status};
    return false;
  }
  std::wstring root = ParentPath(executable);
  if (root.back() != L'\\') {
    root += L"\\";
  }
  do {
    const bool steam = EqualPath(entry.szExeFile, L"steam.exe");
    const bool helper = EqualPath(entry.szExeFile, L"steamwebhelper.exe");
    if (!steam && !helper) {
      continue;
    }
    Handle process(OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE,
                                entry.th32ProcessID));
    if (process.get() == nullptr) {
      const DWORD status = GetLastError();
      // The snapshot may contain a process that has already exited.
      if (status == ERROR_INVALID_PARAMETER) {
        continue;
      }
      *error = {"process_query_failed", "Could not verify a running Steam process.", status};
      return false;
    }
    std::vector<wchar_t> buffer(32768);
    DWORD length = static_cast<DWORD>(buffer.size());
    if (!QueryFullProcessImageNameW(process.get(), 0, buffer.data(), &length)) {
      const DWORD status = GetLastError();
      DWORD exit_code = STILL_ACTIVE;
      if (GetExitCodeProcess(process.get(), &exit_code) && exit_code != STILL_ACTIVE) {
        continue;
      }
      *error = {"process_query_failed", "Could not verify a running Steam process.", status};
      return false;
    }
    std::wstring image_path;
    if (!CanonicalFile(std::wstring(buffer.data(), length), &image_path, error)) {
      DWORD exit_code = STILL_ACTIVE;
      if (GetExitCodeProcess(process.get(), &exit_code) && exit_code != STILL_ACTIVE) {
        continue;
      }
      error->code = "process_query_failed";
      error->message = "Could not resolve a running Steam process path.";
      return false;
    }
    const bool matching_helper = helper && image_path.size() > root.size() &&
        EqualPath(image_path.substr(0, root.size()), root) &&
        EqualPath(BaseName(image_path), L"steamwebhelper.exe");
    if ((steam && EqualPath(image_path, executable)) || matching_helper) {
      *running = true;
      return true;
    }
  } while (Process32NextW(snapshot.get(), &entry));
  const DWORD status = GetLastError();
  if (status != ERROR_NO_MORE_FILES) {
    *error = {"process_query_failed", "Could not finish checking running processes.", status};
    return false;
  }
  return true;
}

bool LaunchSteam(const std::wstring& executable, bool shutdown, Error* error) {
  // lpApplicationName is explicit, and the only optional argument is fixed.
  // No shell is used and no caller-controlled command text is interpreted.
  std::wstring command = L"\"" + executable + L"\"";
  if (shutdown) {
    command += L" -shutdown";
  }
  STARTUPINFOW startup{};
  startup.cb = static_cast<DWORD>(sizeof(startup));
  PROCESS_INFORMATION process{};
  const std::wstring working_directory = ParentPath(executable);
  if (!CreateProcessW(executable.c_str(), command.data(), nullptr, nullptr, FALSE,
                       0, nullptr, working_directory.c_str(), &startup, &process)) {
    *error = {shutdown ? "steam_shutdown_failed" : "steam_start_failed",
              shutdown ? "Could not request a normal Steam shutdown."
                       : "Could not start Steam.",
              GetLastError()};
    return false;
  }
  Handle process_handle(process.hProcess);
  Handle thread_handle(process.hThread);
  // Never wait for Steam here. The Dart caller polls the running state.
  return true;
}

void DiscoverPath(Result* result) {
  RegistryKey key;
  const LSTATUS status = RegOpenKeyExW(HKEY_CURRENT_USER, kSteamKey, 0,
                                       KEY_QUERY_VALUE, &key.value);
  if (status == ERROR_FILE_NOT_FOUND || status == ERROR_PATH_NOT_FOUND) {
    result->Success(Value());
    return;
  }
  if (status != ERROR_SUCCESS) {
    ReportError(result, {"registry_read_failed", "Could not locate Steam.",
                         static_cast<DWORD>(status)});
    return;
  }
  for (const wchar_t* name : {L"SteamPath", L"SteamExe"}) {
    RegistryValue value;
    Error error;
    if (!ReadRegistryValue(key.value, name, &value, &error)) {
      ReportError(result, error);
      return;
    }
    if (!value.exists) {
      continue;
    }
    std::wstring directory;
    if (!RegistryString(value, &directory, &error)) {
      continue;
    }
    if (value.type == REG_EXPAND_SZ) {
      const DWORD length = ExpandEnvironmentStringsW(directory.c_str(), nullptr, 0);
      if (length == 0 || length > 32768) {
        continue;
      }
      std::vector<wchar_t> expanded(length);
      const DWORD written = ExpandEnvironmentStringsW(directory.c_str(), expanded.data(), length);
      if (written == 0 || written > length) {
        continue;
      }
      directory = expanded.data();
    }
    if (std::wstring(name) == L"SteamExe") {
      if (!EqualPath(BaseName(directory), L"steam.exe")) {
        continue;
      }
      directory = ParentPath(directory);
    }
    std::wstring executable;
    if (ValidateDirectory(directory, &executable, &error)) {
      std::string path;
      if (!ToUtf8(ParentPath(executable), &path, &error)) {
        ReportError(result, error);
        return;
      }
      result->Success(Value(path));
      return;
    }
  }
  result->Success(Value());
}

void ReadAutoLogin(Result* result) {
  RegistryKey key;
  const LSTATUS status = RegOpenKeyExW(HKEY_CURRENT_USER, kSteamKey, 0,
                                       KEY_QUERY_VALUE, &key.value);
  Map values{{Value("autoLoginUser"), Value()},
              {Value("rememberPassword"), Value()}};
  if (status == ERROR_FILE_NOT_FOUND || status == ERROR_PATH_NOT_FOUND) {
    result->Success(Value(values));
    return;
  }
  if (status != ERROR_SUCCESS) {
    ReportError(result, {"registry_read_failed", "Could not read Steam login settings.",
                         static_cast<DWORD>(status)});
    return;
  }
  RegistryValue user;
  RegistryValue remember;
  Error error;
  if (!ReadRegistryValue(key.value, kAutoLoginUser, &user, &error) ||
      !ReadRegistryValue(key.value, kRememberPassword, &remember, &error)) {
    ReportError(result, error);
    return;
  }
  if (user.exists) {
    std::wstring wide;
    std::string text;
    if (!RegistryString(user, &wide, &error) || !ToUtf8(wide, &text, &error)) {
      ReportError(result, error);
      return;
    }
    values[Value("autoLoginUser")] = Value(text);
  }
  if (remember.exists) {
    if (remember.type != REG_DWORD || remember.bytes.size() != sizeof(DWORD)) {
      ReportError(result, {"registry_read_failed", "RememberPassword is not a DWORD.",
                           ERROR_INVALID_DATA});
      return;
    }
    DWORD number = 0;
    memcpy(&number, remember.bytes.data(), sizeof(number));
    values[Value("rememberPassword")] = Value(static_cast<int64_t>(number));
  }
  result->Success(Value(values));
}

void WriteAutoLogin(const Map& arguments, Result* result) {
  const Value* user_argument = FindArgument(arguments, "autoLoginUser");
  const Value* remember_argument = FindArgument(arguments, "rememberPassword");
  if (user_argument == nullptr || remember_argument == nullptr) {
    ReportError(result, {"invalid_arguments", "Both login settings must be supplied (or null)."});
    return;
  }
  RegistryValue user;
  RegistryValue remember;
  Error error;
  if (!std::holds_alternative<std::monostate>(*user_argument)) {
    const auto* text = std::get_if<std::string>(user_argument);
    std::wstring wide;
    if (text == nullptr) {
      ReportError(result, {"invalid_arguments", "autoLoginUser must be a string or null."});
      return;
    }
    if (!ToWide(*text, &wide, &error)) {
      ReportError(result, error);
      return;
    }
    if (wide.size() > 256) {
      ReportError(result, {"invalid_arguments", "autoLoginUser is too long."});
      return;
    }
    user.exists = true;
    user.type = REG_SZ;
    user.bytes.resize((wide.size() + 1) * sizeof(wchar_t));
    memcpy(user.bytes.data(), wide.c_str(), user.bytes.size());
  }
  if (!std::holds_alternative<std::monostate>(*remember_argument)) {
    int64_t number = -1;
    if (const auto* number32 = std::get_if<int32_t>(remember_argument)) {
      number = *number32;
    } else if (const auto* number64 = std::get_if<int64_t>(remember_argument)) {
      number = *number64;
    }
    if (number < 0 || number > static_cast<int64_t>((std::numeric_limits<DWORD>::max)())) {
      ReportError(result, {"invalid_arguments", "rememberPassword must be a DWORD integer or null."});
      return;
    }
    const DWORD dword = static_cast<DWORD>(number);
    remember.exists = true;
    remember.type = REG_DWORD;
    remember.bytes.resize(sizeof(dword));
    memcpy(remember.bytes.data(), &dword, sizeof(dword));
  }
  RegistryKey key;
  const LSTATUS open_status = RegOpenKeyExW(HKEY_CURRENT_USER, kSteamKey, 0,
      KEY_QUERY_VALUE | KEY_SET_VALUE, &key.value);
  if (open_status != ERROR_SUCCESS) {
    ReportError(result, {"registry_write_failed", "Could not open Steam login settings for writing.",
                         static_cast<DWORD>(open_status)});
    return;
  }
  RegistryValue old_user;
  RegistryValue old_remember;
  if (!ReadRegistryValue(key.value, kAutoLoginUser, &old_user, &error) ||
      !ReadRegistryValue(key.value, kRememberPassword, &old_remember, &error)) {
    ReportError(result, error);
    return;
  }
  LSTATUS status = StoreRegistryValue(key.value, kAutoLoginUser, user);
  if (status == ERROR_SUCCESS) {
    status = StoreRegistryValue(key.value, kRememberPassword, remember);
  }
  if (status != ERROR_SUCCESS) {
    const LSTATUS restore_user = StoreRegistryValue(key.value, kAutoLoginUser, old_user);
    const LSTATUS restore_remember = StoreRegistryValue(key.value, kRememberPassword, old_remember);
    const LSTATUS restore_status = restore_user != ERROR_SUCCESS ? restore_user : restore_remember;
    ReportError(result, {restore_status == ERROR_SUCCESS ? "registry_write_failed" : "registry_rollback_failed",
                         restore_status == ERROR_SUCCESS
                             ? "Could not update Steam login settings; previous settings were restored."
                             : "Could not update or fully restore Steam login settings.",
                         static_cast<DWORD>(status), static_cast<DWORD>(restore_status)});
    return;
  }
  result->Success();
}

bool FilePathArgument(const Map& arguments, const char* name,
                       std::wstring* path, Error* error) {
  const Value* value = FindArgument(arguments, name);
  const auto* text = value == nullptr ? nullptr : std::get_if<std::string>(value);
  if (text == nullptr || !ToWide(*text, path, error)) {
    *error = {"invalid_arguments", "An absolute file path is required."};
    return false;
  }
  std::replace(path->begin(), path->end(), L'/', L'\\');
  const bool drive_path = path->size() >= 3 && (*path)[1] == L':' && (*path)[2] == L'\\';
  const bool unc_path = path->size() > 2 && (*path)[0] == L'\\' && (*path)[1] == L'\\';
  if ((!drive_path && !unc_path) || path->find(L'"') != std::wstring::npos ||
      path->size() > 32000 || path->find(L':', drive_path ? 2 : 0) != std::wstring::npos) {
    *error = {"invalid_arguments", "An absolute ordinary file path is required."};
    return false;
  }
  std::vector<wchar_t> full(32768);
  const DWORD length = GetFullPathNameW(path->c_str(), static_cast<DWORD>(full.size()),
                                       full.data(), nullptr);
  if (length == 0 || length >= full.size()) {
    *error = {"invalid_arguments", "Could not resolve the file path.",
              length == 0 ? GetLastError() : ERROR_INSUFFICIENT_BUFFER};
    return false;
  }
  *path = std::wstring(full.data(), length);
  while (!path->empty() && path->back() == L'\\') {
    path->pop_back();
  }
  return true;
}

// Both the final entry and every parent must resolve to the supplied path.
// In particular, never secure or replace a file through a junction or symlink.
bool ValidateOrdinaryHandle(HANDLE handle, const std::wstring& path,
                            bool directory, Error* error) {
  BY_HANDLE_FILE_INFORMATION info{};
  if (!GetFileInformationByHandle(handle, &info)) {
    *error = {"unsafe_file_path", "Could not inspect the selected file.", GetLastError()};
    return false;
  }
  if ((info.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0 ||
      ((info.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0) != directory) {
    *error = {"unsafe_file_path", "Steam configuration paths must not be links."};
    return false;
  }
  std::vector<wchar_t> buffer(32768);
  const DWORD length = GetFinalPathNameByHandleW(handle, buffer.data(),
      static_cast<DWORD>(buffer.size()), FILE_NAME_NORMALIZED);
  if (length == 0 || length >= buffer.size()) {
    *error = {"unsafe_file_path", "Could not verify the selected file path.",
              length == 0 ? GetLastError() : ERROR_INSUFFICIENT_BUFFER};
    return false;
  }
  std::wstring resolved(buffer.data(), length);
  if (resolved.rfind(L"\\\\?\\UNC\\", 0) == 0) {
    resolved = L"\\\\" + resolved.substr(8);
  } else if (resolved.rfind(L"\\\\?\\", 0) == 0) {
    resolved = resolved.substr(4);
  }
  if (!EqualPath(resolved, path)) {
    *error = {"unsafe_file_path", "Steam configuration paths must not pass through links."};
    return false;
  }
  return true;
}

bool ValidateConfigDirectory(const std::wstring& directory, Error* error) {
  if (!EqualPath(BaseName(directory), L"config")) {
    *error = {"unsafe_file_path", "Only the Steam config directory is supported."};
    return false;
  }
  std::wstring executable;
  if (!ValidateDirectory(ParentPath(directory), &executable, error)) {
    return false;
  }
  if (!EqualPath(ParentPath(executable), ParentPath(directory))) {
    *error = {"unsafe_file_path", "The Steam installation path must not pass through links."};
    return false;
  }
  return true;
}

void SecureDirectory(const Map& arguments, Result* result) {
  Error error;
  std::wstring path;
  if (!FilePathArgument(arguments, "path", &path, &error)) {
    ReportError(result, error);
    return;
  }
  const std::wstring parent = ParentPath(path);
  const std::wstring basename = BaseName(path);
  const bool backup = EqualPath(BaseName(parent), L"ava-switch-backups") &&
      basename.size() > 7 && basename.rfind(L"switch-", 0) == 0;
  const bool temporary = basename.size() > 5 && basename.rfind(L".ava-", 0) == 0;
  const std::wstring config = backup ? ParentPath(parent) : parent;
  if ((!backup && !temporary) || !ValidateConfigDirectory(config, &error)) {
    if (error.code.empty()) {
      error = {"unsafe_file_path", "Use a new AVA backup or temporary directory inside Steam config."};
    }
    ReportError(result, error);
    return;
  }
  Handle directory(CreateFileW(path.c_str(), FILE_READ_ATTRIBUTES | WRITE_DAC,
      FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr, OPEN_EXISTING,
      FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OPEN_REPARSE_POINT, nullptr));
  if (directory.get() == INVALID_HANDLE_VALUE) {
    ReportError(result, {"backup_security_failed", "Could not open the backup directory.",
                         GetLastError()});
    return;
  }
  if (!ValidateOrdinaryHandle(directory.get(), path, true, &error)) {
    ReportError(result, error);
    return;
  }
  WIN32_FIND_DATAW entry{};
  const HANDLE search = FindFirstFileW((path + L"\\*").c_str(), &entry);
  if (search != INVALID_HANDLE_VALUE) {
    bool empty = true;
    do {
      if (std::wstring(entry.cFileName) != L"." && std::wstring(entry.cFileName) != L"..") {
        empty = false;
        break;
      }
    } while (FindNextFileW(search, &entry));
    const DWORD search_status = empty ? GetLastError() : ERROR_SUCCESS;
    FindClose(search);
    if (!empty || search_status != ERROR_NO_MORE_FILES) {
      ReportError(result, {"backup_security_failed", "The backup directory must be empty.",
                           search_status});
      return;
    }
  } else if (GetLastError() != ERROR_FILE_NOT_FOUND) {
    ReportError(result, {"backup_security_failed", "Could not inspect the backup directory.",
                         GetLastError()});
    return;
  }
  HANDLE token_value = nullptr;
  if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token_value)) {
    ReportError(result, {"backup_security_failed", "Could not identify the Windows user.",
                         GetLastError()});
    return;
  }
  Handle token(token_value);
  DWORD token_length = 0;
  GetTokenInformation(token.get(), TokenUser, nullptr, 0, &token_length);
  if (token_length == 0) {
    ReportError(result, {"backup_security_failed", "Could not inspect the Windows user token.",
                         GetLastError()});
    return;
  }
  std::vector<BYTE> token_data(token_length);
  if (!GetTokenInformation(token.get(), TokenUser, token_data.data(), token_length,
                           &token_length)) {
    ReportError(result, {"backup_security_failed", "Could not inspect the Windows user token.",
                         GetLastError()});
    return;
  }
  const auto* user = reinterpret_cast<const TOKEN_USER*>(token_data.data());
  BYTE system_sid[SECURITY_MAX_SID_SIZE]{};
  DWORD sid_length = static_cast<DWORD>(sizeof(system_sid));
  if (!CreateWellKnownSid(WinLocalSystemSid, nullptr, system_sid, &sid_length)) {
    ReportError(result, {"backup_security_failed", "Could not create the backup access rules.",
                         GetLastError()});
    return;
  }
  EXPLICIT_ACCESSW access[2]{};
  PSID trustees[2] = {user->User.Sid, system_sid};
  for (size_t index = 0; index < 2; ++index) {
    access[index].grfAccessPermissions = FILE_ALL_ACCESS;
    access[index].grfAccessMode = GRANT_ACCESS;
    access[index].grfInheritance = SUB_CONTAINERS_AND_OBJECTS_INHERIT;
    access[index].Trustee.TrusteeForm = TRUSTEE_IS_SID;
    access[index].Trustee.TrusteeType = TRUSTEE_IS_USER;
    access[index].Trustee.ptstrName = static_cast<LPWSTR>(trustees[index]);
  }
  PACL acl = nullptr;
  DWORD status = SetEntriesInAclW(2, access, nullptr, &acl);
  if (status == ERROR_SUCCESS) {
    status = SetSecurityInfo(directory.get(), SE_FILE_OBJECT,
        DACL_SECURITY_INFORMATION | PROTECTED_DACL_SECURITY_INFORMATION,
        nullptr, nullptr, acl, nullptr);
  }
  if (acl != nullptr) {
    LocalFree(acl);
  }
  if (status != ERROR_SUCCESS) {
    ReportError(result, {"backup_security_failed", "Could not restrict access to the backup directory.", status});
    return;
  }
  result->Success();
}

void ReplaceConfigFile(const Map& arguments, Result* result) {
  Error error;
  std::wstring path;
  std::wstring replacement;
  if (!FilePathArgument(arguments, "path", &path, &error) ||
      !FilePathArgument(arguments, "replacementPath", &replacement, &error)) {
    ReportError(result, error);
    return;
  }
  const std::wstring basename = BaseName(path);
  const std::wstring temporary_directory = ParentPath(replacement);
  const std::wstring temporary_name = BaseName(temporary_directory);
  if ((!EqualPath(basename, L"loginusers.vdf") && !EqualPath(basename, L"config.vdf")) ||
      !EqualPath(ParentPath(path), ParentPath(temporary_directory)) ||
      temporary_name.size() <= 5 || temporary_name.rfind(L".ava-", 0) != 0 ||
      !EqualPath(basename, BaseName(replacement)) ||
      !ValidateConfigDirectory(ParentPath(path), &error)) {
    if (error.code.empty()) {
      error = {"unsafe_file_path", "Replace only a Steam config file from an AVA temporary directory with the same filename."};
    }
    ReportError(result, error);
    return;
  }
  // Check both files without following a reparse point. The handles allow
  // deletion because ReplaceFileW must rename them while preserving target ACLs.
  Handle target(CreateFileW(path.c_str(), FILE_READ_ATTRIBUTES,
      FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr, OPEN_EXISTING,
      FILE_FLAG_OPEN_REPARSE_POINT, nullptr));
  if (target.get() == INVALID_HANDLE_VALUE) {
    ReportError(result, {"replace_file_failed", "Could not open the original Steam config file.",
                         GetLastError()});
    return;
  }
  Handle source(CreateFileW(replacement.c_str(), FILE_READ_ATTRIBUTES,
      FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr, OPEN_EXISTING,
      FILE_FLAG_OPEN_REPARSE_POINT, nullptr));
  if (source.get() == INVALID_HANDLE_VALUE) {
    ReportError(result, {"replace_file_failed", "Could not open the replacement Steam config file.",
                         GetLastError()});
    return;
  }
  if (!ValidateOrdinaryHandle(target.get(), path, false, &error) ||
      !ValidateOrdinaryHandle(source.get(), replacement, false, &error)) {
    ReportError(result, error);
    return;
  }
  if (!ReplaceFileW(path.c_str(), replacement.c_str(), nullptr, 0, nullptr, nullptr)) {
    ReportError(result, {"replace_file_failed", "Could not replace the Steam config file.",
                         GetLastError()});
    return;
  }
  result->Success();
}

void HandleMethod(const flutter::MethodCall<Value>& call,
                  std::unique_ptr<Result> result) {
  if (call.method_name() == "discoverPath") {
    DiscoverPath(result.get());
    return;
  }
  if (call.method_name() == "readAutoLogin") {
    ReadAutoLogin(result.get());
    return;
  }
  if (call.method_name() != "isRunning" && call.method_name() != "shutdown" &&
      call.method_name() != "start" && call.method_name() != "writeAutoLogin" &&
      call.method_name() != "secureDirectory" && call.method_name() != "replaceFile") {
    result->NotImplemented();
    return;
  }
  const auto* arguments = call.arguments() == nullptr
      ? nullptr : std::get_if<Map>(call.arguments());
  if (arguments == nullptr) {
    ReportError(result.get(), {"invalid_arguments", "Method arguments must be a map."});
    return;
  }
  if (call.method_name() == "writeAutoLogin") {
    WriteAutoLogin(*arguments, result.get());
    return;
  }
  if (call.method_name() == "secureDirectory") {
    SecureDirectory(*arguments, result.get());
    return;
  }
  if (call.method_name() == "replaceFile") {
    ReplaceConfigFile(*arguments, result.get());
    return;
  }
  Error error;
  std::wstring executable;
  if (!PathArgument(*arguments, &executable, &error)) {
    ReportError(result.get(), error);
    return;
  }
  if (call.method_name() == "isRunning") {
    bool running = false;
    if (!IsRunning(executable, &running, &error)) {
      ReportError(result.get(), error);
    } else {
      result->Success(Value(running));
    }
    return;
  }
  if (!LaunchSteam(executable, call.method_name() == "shutdown", &error)) {
    ReportError(result.get(), error);
  } else {
    result->Success();
  }
}

}  // namespace

SteamClientBridge::SteamClientBridge(flutter::BinaryMessenger* messenger)
    : channel_(std::make_unique<flutter::MethodChannel<Value>>(
          messenger, "ava/steam_client", &flutter::StandardMethodCodec::GetInstance())) {
  channel_->SetMethodCallHandler(HandleMethod);
}

SteamClientBridge::~SteamClientBridge() {
  channel_->SetMethodCallHandler(nullptr);
}
