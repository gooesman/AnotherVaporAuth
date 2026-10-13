// Compile the actual production implementation, excluding only registration
// with Flutter's running engine. No Steam registry/account methods are called.
#define STEAM_CLIENT_BRIDGE_NATIVE_TEST
#include "../../windows/runner/steam_client_bridge.cpp"

#include <filesystem>
#include <fstream>
#include <iostream>
#include <stdexcept>

namespace {
namespace fs = std::filesystem;
struct Reply {
  bool success = false;
  Value value;
  std::string error;
  Value details;
};
class TestResult final : public Result {
 public:
  explicit TestResult(Reply* reply) : reply_(reply) {}
 protected:
  void SuccessInternal(const Value* value) override {
    reply_->success = true;
    if (value) reply_->value = *value;
  }
  void ErrorInternal(const std::string& code, const std::string&,
                     const Value* details) override {
    reply_->error = code;
    if (details) reply_->details = *details;
  }
  void NotImplementedInternal() override { reply_->error = "not_implemented"; }
 private:
  Reply* reply_;
};
int checks = 0;
int64_t reported_launch_error = 0;
DWORD direct_launch_error = ERROR_SUCCESS;
void Check(bool condition, const char* name) {
  if (!condition) throw std::runtime_error(name);
  ++checks;
}
std::string Utf8(const fs::path& path) {
  std::string value;
  Error error;
  Check(ToUtf8(path.wstring(), &value, &error), "utf8-path");
  return value;
}
Reply Call(const char* method, Map arguments) {
  Reply reply;
  flutter::MethodCall<Value> call(method, std::make_unique<Value>(std::move(arguments)));
  HandleMethod(call, std::make_unique<TestResult>(&reply));
  return reply;
}
Map Path(const fs::path& path) { return {{Value("path"), Value(Utf8(path))}}; }
bool SameFile(const fs::path& left, const fs::path& right) {
  // Compare volume/file identity, not spelling: GetFinalPathNameByHandleW
  // expands runner TEMP's 8.3 components (e.g. RUNNER~1).
  std::error_code error;
  return fs::equivalent(left, right, error) && !error;
}
fs::path CanonicalDirectory(const fs::path& directory) {
  Handle handle(CreateFileW(directory.c_str(), FILE_READ_ATTRIBUTES,
      FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr,
      OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, nullptr));
  Check(handle.get() != INVALID_HANDLE_VALUE, "open-private-test-directory");
  wchar_t buffer[32768]{};
  const DWORD length = GetFinalPathNameByHandleW(handle.get(), buffer, 32768,
                                                FILE_NAME_NORMALIZED);
  Check(length > 0 && length < 32768, "resolve-private-test-directory");
  std::wstring resolved(buffer, length);
  if (resolved.rfind(L"\\\\?\\UNC\\", 0) == 0) {
    resolved = L"\\\\" + resolved.substr(8);
  } else if (resolved.rfind(L"\\\\?\\", 0) == 0) {
    resolved = resolved.substr(4);
  }
  Check(SameFile(directory, fs::path(resolved)), "private-directory-identity");
  return fs::path(resolved);
}
void Write(const fs::path& path, const std::string& bytes) {
  std::ofstream file(path, std::ios::binary);
  file << bytes;
  Check(file.good(), "write-synthetic-fixture");
}
std::string Read(const fs::path& path) {
  std::ifstream file(path, std::ios::binary);
  return std::string(std::istreambuf_iterator<char>(file), std::istreambuf_iterator<char>());
}
void WaitFixture(const fs::path& directory, bool shutdown) {
  const auto marker = directory / (shutdown ? L"fixture-shutdown.bin" : L"fixture-start.bin");
  std::string bytes;
  for (int index = 0; index < 100; ++index) {
    bytes = Read(marker);
    if (bytes.size() > sizeof(DWORD)) break;
    Sleep(50);
  }
  Check(bytes.size() > sizeof(DWORD) && (bytes.size() - sizeof(DWORD)) % sizeof(wchar_t) == 0,
        "fixture-started-and-reported");
  DWORD pid = 0;
  memcpy(&pid, bytes.data(), sizeof(pid));
  Handle process(OpenProcess(SYNCHRONIZE | PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid));
  if (process.get()) {
    Check(WaitForSingleObject(process.get(), 5000) == WAIT_OBJECT_0, "fixture-exited");
    DWORD exit_code = 1;
    Check(GetExitCodeProcess(process.get(), &exit_code) && exit_code == 0, "fixture-clean-exit");
  }
  std::wstring cwd((bytes.size() - sizeof(DWORD)) / sizeof(wchar_t), L'\0');
  memcpy(cwd.data(), bytes.data() + sizeof(DWORD), bytes.size() - sizeof(DWORD));
  Check(SameFile(fs::path(cwd), directory), "child-working-directory");
}
void CheckPrivateAcl(const fs::path& directory) {
  PACL acl = nullptr;
  PSECURITY_DESCRIPTOR descriptor = nullptr;
  Check(GetNamedSecurityInfoW(const_cast<wchar_t*>(directory.c_str()), SE_FILE_OBJECT,
      DACL_SECURITY_INFORMATION, nullptr, nullptr, &acl, nullptr, &descriptor) == ERROR_SUCCESS,
      "read-backup-acl");
  SECURITY_DESCRIPTOR_CONTROL control{};
  DWORD revision = 0;
  const bool restricted = acl && acl->AceCount == 2 &&
      GetSecurityDescriptorControl(descriptor, &control, &revision) &&
      (control & SE_DACL_PROTECTED) != 0;
  LocalFree(descriptor);
  Check(restricted, "backup-has-two-protected-aces");
}
void Run(const fs::path& root, const fs::path& fixture) {
  const auto steam = root / L"Program Files" / L"Steam \u6d4b\u8bd5";
  fs::create_directories(steam);
  fs::copy_file(fixture, steam / L"steam.exe");
  std::wstring canonical;
  Error error;
  Check(PathArgument(Path(steam), &canonical, &error), "directory-argument-resolves-exe");
  Check(SameFile(fs::path(canonical), steam / L"steam.exe"), "resolved-exe-exact");
  Check(!PathArgument(Path(steam / L"steam.exe"), &canonical, &error), "exe-is-not-directory");
  Check(!PathArgument(Path(root / L"missing"), &canonical, &error), "missing-directory-rejected");
  auto begin = Call("beginLoginCapture", Path(steam));
  Check(begin.success, "capture-lease-starts");
  Check(Call("start", Path(steam)).success, "real-createprocess-start");
  WaitFixture(steam, false);
  Check(login_capture_lease && login_capture_lease->launched_pid != 0,
        "lease-bound-to-launched-fixture");
  auto end = Path(steam);
  end[Value("attempt")] = begin.value;
  Check(Call("endLoginCapture", end).success && !login_capture_lease, "lease-closed");
  Check(Call("shutdown", Path(steam)).success, "fixed-shutdown-argument");
  WaitFixture(steam, true);

  const auto invalid = root / L"invalid PE";
  fs::create_directory(invalid);
  Write(invalid / L"steam.exe", "this is not an executable");
  const auto failed = Call("start", Path(invalid));
  Check(!failed.success && failed.error == "steam_start_failed", "invalid-pe-diagnostic-code");
  const auto* details = std::get_if<Map>(&failed.details);
  const auto* number = details ? FindArgument(*details, "win32Error") : nullptr;
  const auto* error_number = number ? std::get_if<int64_t>(number) : nullptr;
  reported_launch_error = error_number ? *error_number : 0;
  // Windows versions can report different loader errors for this invalid PE.
  // Require exactly the real CreateProcessW error on the same fixture; merely
  // accepting any nonzero error would miss a broken bridge diagnostic.
  const auto invalid_executable = (invalid / L"steam.exe").wstring();
  std::wstring command = L"\"" + invalid_executable + L"\"";
  STARTUPINFOW startup{};
  startup.cb = static_cast<DWORD>(sizeof(startup));
  PROCESS_INFORMATION process{};
  const BOOL started = CreateProcessW(invalid_executable.c_str(), command.data(),
      nullptr, nullptr, FALSE, 0, nullptr, invalid.c_str(), &startup, &process);
  direct_launch_error = started ? ERROR_SUCCESS : GetLastError();
  if (started) {
    CloseHandle(process.hThread);
    CloseHandle(process.hProcess);
  }
  Check(!started && direct_launch_error != ERROR_SUCCESS, "invalid-pe-rejected-by-win32");
  Check(error_number && *error_number == static_cast<int64_t>(direct_launch_error),
        "exact-native-win32-launch-error");

  const auto config = steam / L"config";
  const auto backup = config / L"ava-switch-backups" / L"switch-native-test";
  fs::create_directories(backup);
  Check(Call("secureDirectory", Path(backup)).success, "secure-new-backup");
  CheckPrivateAcl(backup);
  Write(backup / L"auto-login.json", "{\"synthetic\":true}");
  Check(!Call("secureDirectory", Path(backup)).success, "nonempty-backup-rejected");
  const auto temp = config / L".ava-native-test";
  fs::create_directory(temp);
  Check(Call("secureDirectory", Path(temp)).success, "secure-temp-directory");
  Write(config / L"loginusers.vdf", "synthetic-before");
  Write(temp / L"loginusers.vdf", "synthetic-after");
  Map replacement = Path(config / L"loginusers.vdf");
  replacement[Value("replacementPath")] = Value(Utf8(temp / L"loginusers.vdf"));
  Check(Call("replaceFile", replacement).success, "actual-replacefile");
  Check(Read(config / L"loginusers.vdf") == "synthetic-after", "replacement-bytes");
  Check(!fs::exists(temp / L"loginusers.vdf"), "atomic-source-consumed");
  replacement[Value("path")] = Value(Utf8(config / L"unrelated.txt"));
  Check(Call("replaceFile", replacement).error == "unsafe_file_path", "unmanaged-file-rejected");
}
}  // namespace

int wmain() {
  SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX | SEM_NOOPENFILEERRORBOX);
  // GetTempFileName reserves a unique child. Only that exact new child is ever
  // removed. This suite does not discover or read the real Steam installation.
  wchar_t temporary[MAX_PATH]{};
  wchar_t reserved[MAX_PATH]{};
  wchar_t image[32768]{};
  if (!GetTempPathW(MAX_PATH, temporary) ||
      !GetTempFileNameW(temporary, L"gst", 0, reserved) ||
      !GetModuleFileNameW(nullptr, image, 32768)) return 2;
  const fs::path root(reserved);
  DeleteFileW(reserved);
  fs::create_directory(root);
  try {
    // Production deliberately refuses alias/reparse paths for configuration
    // writes. Use the canonical spelling of our new, isolated test root for
    // those tests; no production safety check is weakened for the harness.
    Run(CanonicalDirectory(root), fs::path(image).parent_path() / L"steam_client_launch_fixture.exe");
    fs::remove_all(root);
    std::cout << "{\"success\":true,\"checks\":" << checks << "}\n";
    return 0;
  } catch (const std::exception& error) {
    // Errors contain only fixed assertion names, not local accounts or paths.
    std::cout << "{\"success\":false,\"checks\":" << checks
              << ",\"failedCheck\":\"" << error.what()
              << "\",\"reportedWin32Error\":" << reported_launch_error
              << ",\"directWin32Error\":" << direct_launch_error << "}\n";
    std::error_code ignored;
    fs::remove_all(root, ignored);
    return 1;
  }
}
