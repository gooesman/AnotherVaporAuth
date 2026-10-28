#ifndef RUNNER_STEAM_CLIENT_BRIDGE_H_
#define RUNNER_STEAM_CLIENT_BRIDGE_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <memory>

// Fast, local Win32 operations only. Dart owns shutdown polling and the
// loginusers.vdf transaction; this bridge never terminates a Steam process.
class SteamClientBridge {
 public:
  explicit SteamClientBridge(flutter::BinaryMessenger* messenger);
  ~SteamClientBridge();

  SteamClientBridge(const SteamClientBridge&) = delete;
  SteamClientBridge& operator=(const SteamClientBridge&) = delete;

 private:
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif  // RUNNER_STEAM_CLIENT_BRIDGE_H_
