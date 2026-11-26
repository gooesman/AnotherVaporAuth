// A silent, disposable substitute for steam.exe. It never opens a Steam
// registry key, loads account data, accesses the network, or creates a window.
#include <windows.h>
#include <shellapi.h>
#include <fstream>
#include <string>
#include <filesystem>

int APIENTRY wWinMain(HINSTANCE, HINSTANCE, wchar_t*, int) {
  wchar_t image[32768]{};
  wchar_t cwd[32768]{};
  if (!GetModuleFileNameW(nullptr, image, 32768) ||
      !GetCurrentDirectoryW(32768, cwd)) return 2;
  int argc = 0;
  auto argv = CommandLineToArgvW(GetCommandLineW(), &argc);
  if (!argv) return 3;
  const bool shutdown = argc == 2 && std::wstring(argv[1]) == L"-shutdown";
  const bool valid = argc == 1 || shutdown;
  LocalFree(argv);
  if (!valid) return 4;
  const auto directory = std::filesystem::path(image).parent_path();
  const auto marker = directory / (shutdown ? L"fixture-shutdown.bin" : L"fixture-start.bin");
  const auto temporary = directory / L"fixture-marker.tmp";
  {
    std::ofstream out(temporary, std::ios::binary);
    const DWORD pid = GetCurrentProcessId();
    out.write(reinterpret_cast<const char*>(&pid), sizeof(pid));
    const std::wstring working(cwd);
    out.write(reinterpret_cast<const char*>(working.data()),
              static_cast<std::streamsize>(working.size() * sizeof(wchar_t)));
    out.close();
    if (!out.good()) return 5;
  }
  // Publish only a complete marker; the parent must never read a partial PID
  // or working-directory payload while the child is flushing its stream.
  return MoveFileExW(temporary.c_str(), marker.c_str(), MOVEFILE_WRITE_THROUGH) ? 0 : 6;
}
