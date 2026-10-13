#include <winsock2.h>
#include "steam_acceleration_bridge.h"

#include <aclapi.h>
#include <iphlpapi.h>
#include <netioapi.h>
#include <sddl.h>
#include <shlobj.h>
#include <tlhelp32.h>
#include <winhttp.h>
#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <cstdint>
#include <cwctype>
#include <filesystem>
#include <string>
#include <vector>

namespace {
using Value = flutter::EncodableValue;
using Map = flutter::EncodableMap;

std::string Utf8(const wchar_t* text) {
  if (!text) return {};
  const int size = WideCharToMultiByte(CP_UTF8, 0, text, -1, nullptr, 0, nullptr, nullptr);
  if (size < 2) return {};
  std::string result(static_cast<size_t>(size), '\0');
  WideCharToMultiByte(CP_UTF8, 0, text, -1, result.data(), size, nullptr, nullptr);
  result.pop_back();
  return result;
}

std::wstring Wide(const std::string& text) {
  if (text.empty() || text.size() > 32767 || text.find('\0') != std::string::npos) return {};
  const int size = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.data(),
      static_cast<int>(text.size()), nullptr, 0);
  if (size < 1) return {};
  std::wstring result(static_cast<size_t>(size), L'\0');
  MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.data(),
      static_cast<int>(text.size()), result.data(), size);
  return result;
}

std::wstring PrivateRoot() {
  PWSTR roaming = nullptr;
  if (FAILED(SHGetKnownFolderPath(FOLDERID_RoamingAppData, 0, nullptr, &roaming))) return {};
  std::filesystem::path path(roaming);
  CoTaskMemFree(roaming);
  return (path / L"dotslash.pro" / L"AVA" / L"steam_acceleration").wstring();
}

bool EqualPath(const std::wstring& a, const std::wstring& b) {
  return !a.empty() && !b.empty() && _wcsicmp(a.c_str(), b.c_str()) == 0;
}

bool RestrictDirectory(const std::string& input) {
  std::error_code error;
  const auto requested = std::filesystem::canonical(Wide(input), error);
  if (error) return false;
  const auto expected = std::filesystem::canonical(PrivateRoot(), error);
  if (error || !EqualPath(requested.wstring(), expected.wstring())) return false;
  // Reject a redirected root rather than accidentally securing an unrelated tree.
  if (!EqualPath(requested.wstring(), std::filesystem::path(PrivateRoot()).lexically_normal().wstring())) return false;
  HANDLE token = nullptr;
  if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) return false;
  DWORD bytes = 0;
  GetTokenInformation(token, TokenUser, nullptr, 0, &bytes);
  std::vector<BYTE> buffer(bytes);
  const BOOL read = GetTokenInformation(token, TokenUser, buffer.data(), bytes, &bytes);
  CloseHandle(token);
  if (!read) return false;
  LPWSTR sid = nullptr;
  if (!ConvertSidToStringSidW(reinterpret_cast<TOKEN_USER*>(buffer.data())->User.Sid, &sid)) return false;
  const std::wstring sddl = L"D:P(A;OICI;FA;;;SY)(A;OICI;FA;;;" + std::wstring(sid) + L")";
  LocalFree(sid);
  PSECURITY_DESCRIPTOR descriptor = nullptr;
  if (!ConvertStringSecurityDescriptorToSecurityDescriptorW(sddl.c_str(), SDDL_REVISION_1,
      &descriptor, nullptr)) return false;
  PACL acl = nullptr;
  BOOL present = FALSE;
  BOOL defaulted = FALSE;
  const BOOL valid = GetSecurityDescriptorDacl(descriptor, &present, &acl, &defaulted);
  std::wstring target = requested.wstring();
  const DWORD status = valid && present
      ? SetNamedSecurityInfoW(target.data(), SE_FILE_OBJECT,
          DACL_SECURITY_INFORMATION | PROTECTED_DACL_SECURITY_INFORMATION,
          nullptr, nullptr, acl, nullptr)
      : ERROR_INVALID_ACL;
  LocalFree(descriptor);
  return status == ERROR_SUCCESS;
}

bool IsOwnCore(DWORD pid, HANDLE process) {
  bool child = false;
  HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (snapshot == INVALID_HANDLE_VALUE) return false;
  PROCESSENTRY32W entry{};
  entry.dwSize = sizeof(entry);
  if (Process32FirstW(snapshot, &entry)) {
    do {
      if (entry.th32ProcessID == pid) {
        child = entry.th32ParentProcessID == GetCurrentProcessId();
        break;
      }
    } while (Process32NextW(snapshot, &entry));
  }
  CloseHandle(snapshot);
  if (!child) return false;
  std::wstring image(32768, L'\0');
  DWORD length = static_cast<DWORD>(image.size());
  if (!QueryFullProcessImageNameW(process, 0, image.data(), &length)) return false;
  image.resize(length);
  return EqualPath(image, (std::filesystem::path(PrivateRoot()) /
      L"v1.19.32" / L"ava-steam-core.exe").wstring());
}

Map Environment() {
  WINHTTP_CURRENT_USER_IE_PROXY_CONFIG config{};
  const bool proxy_available = WinHttpGetIEProxyConfigForCurrentUser(&config) != FALSE;
  const bool proxy = config.lpszProxy && *config.lpszProxy;
  const bool pac = config.lpszAutoConfigUrl && *config.lpszAutoConfigUrl;
  Map result{
      // WPAD merely says auto-discovery is enabled; it does not prove a proxy
      // was resolved. Do not start another route while proxy discovery remains
      // unresolved; the UI distinguishes unknown status from an external route.
      {Value("available"), Value(proxy_available && !config.fAutoDetect)},
      {Value("systemProxy"), Value(proxy)},
      {Value("httpProxy"), Value(Utf8(config.lpszProxy))},
      {Value("pac"), Value(pac)},
  };
  if (config.lpszProxy) GlobalFree(config.lpszProxy);
  if (config.lpszProxyBypass) GlobalFree(config.lpszProxyBypass);
  if (config.lpszAutoConfigUrl) GlobalFree(config.lpszAutoConfigUrl);
  ULONG size = 16 * 1024;
  std::vector<BYTE> storage(size);
  auto adapters = reinterpret_cast<IP_ADAPTER_ADDRESSES*>(storage.data());
  ULONG status = GetAdaptersAddresses(AF_UNSPEC,
      GAA_FLAG_SKIP_ANYCAST | GAA_FLAG_SKIP_MULTICAST | GAA_FLAG_SKIP_DNS_SERVER,
      nullptr, adapters, &size);
  if (status == ERROR_BUFFER_OVERFLOW && size <= 1024 * 1024) {
    storage.resize(size);
    adapters = reinterpret_cast<IP_ADAPTER_ADDRESSES*>(storage.data());
    status = GetAdaptersAddresses(AF_UNSPEC, GAA_FLAG_SKIP_ANYCAST |
        GAA_FLAG_SKIP_MULTICAST | GAA_FLAG_SKIP_DNS_SERVER, nullptr, adapters, &size);
  }
  bool tunnel = false;
  PMIB_IPFORWARD_TABLE2 routes = nullptr;
  const ULONG routes_status = GetIpForwardTable2(AF_UNSPEC, &routes);
  if (status == NO_ERROR && routes_status == NO_ERROR) {
    for (auto adapter = adapters; adapter; adapter = adapter->Next) {
      if (adapter->OperStatus != IfOperStatusUp) continue;
      std::wstring name = adapter->Description ? adapter->Description : L"";
      name += adapter->FriendlyName ? adapter->FriendlyName : L"";
      std::transform(name.begin(), name.end(), name.begin(), [](wchar_t c) {
        return static_cast<wchar_t>(std::towlower(c));
      });
      const bool candidate = adapter->IfType == IF_TYPE_TUNNEL || adapter->IfType == IF_TYPE_PPP ||
          name.find(L"wintun") != std::wstring::npos ||
          name.find(L"wireguard") != std::wstring::npos ||
          name.find(L"clash") != std::wstring::npos ||
          name.find(L"mihomo") != std::wstring::npos ||
          name.find(L"sing-box") != std::wstring::npos;
      if (!candidate) continue;
      // Some proxy apps leave their virtual interface Up after stopping. An
      // address's connected/local routes alone do not constitute an active
      // tunnel. Require an actual forwarding route on the candidate interface.
      for (ULONG index = 0; index < routes->NumEntries; ++index) {
        const auto& route = routes->Table[index];
        if (route.InterfaceLuid.Value == adapter->Luid.Value &&
            !route.Loopback && route.Protocol != MIB_IPPROTO_LOCAL) {
          tunnel = true;
          break;
        }
      }
    }
  } else {
    result[Value("available")] = Value(false);
  }
  if (routes) FreeMibTable(routes);
  // These are conservative hints, not proof that every third-party TUN is known.
  result[Value("vpnOrTunnel")] = Value(tunnel);
  return result;
}
}  // namespace

SteamAccelerationBridge::SteamAccelerationBridge(flutter::BinaryMessenger* messenger) {
  job_ = CreateJobObjectW(nullptr, nullptr);
  if (job_) {
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits{};
    limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
    if (!SetInformationJobObject(job_, JobObjectExtendedLimitInformation, &limits, sizeof(limits))) {
      CloseHandle(job_);
      job_ = nullptr;
    }
  }
  channel_ = std::make_unique<flutter::MethodChannel<Value>>(messenger,
      "ava/steam_acceleration", &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const flutter::MethodCall<Value>& call,
      std::unique_ptr<flutter::MethodResult<Value>> result) {
    const auto* args = call.arguments() ? std::get_if<Map>(call.arguments()) : nullptr;
    if (call.method_name() == "environment") { result->Success(Value(Environment())); return; }
    if (call.method_name() == "restrictDirectory" && args) {
      const auto it = args->find(Value("path"));
      if (it != args->end()) {
        const auto* path = std::get_if<std::string>(&it->second);
        if (path && RestrictDirectory(*path)) { result->Success(); return; }
      }
    }
    if (call.method_name() == "ownProcess" && args && job_) {
      const auto it = args->find(Value("pid"));
      int64_t pid = 0;
      if (it != args->end()) {
        if (const auto* value = std::get_if<int32_t>(&it->second)) pid = *value;
        if (const auto* value = std::get_if<int64_t>(&it->second)) pid = *value;
      }
      if (pid > 0 && pid <= MAXDWORD) {
        HANDLE process = OpenProcess(PROCESS_SET_QUOTA | PROCESS_TERMINATE |
            PROCESS_QUERY_LIMITED_INFORMATION, FALSE, static_cast<DWORD>(pid));
        if (process) {
          const bool owned = IsOwnCore(static_cast<DWORD>(pid), process) &&
              AssignProcessToJobObject(job_, process);
          CloseHandle(process);
          if (owned) { result->Success(); return; }
        }
      }
    }
    result->Error("native_operation_failed", "Steam acceleration operation failed");
  });
}

SteamAccelerationBridge::~SteamAccelerationBridge() {
  channel_->SetMethodCallHandler(nullptr);
  if (job_) CloseHandle(job_);  // Kills only the verified AVA-owned child.
}
