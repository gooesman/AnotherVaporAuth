#ifndef RUNNER_STEAM_ACCELERATION_BRIDGE_H_
#define RUNNER_STEAM_ACCELERATION_BRIDGE_H_

#include <windows.h>
#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <memory>

class SteamAccelerationBridge {
 public:
  explicit SteamAccelerationBridge(flutter::BinaryMessenger* messenger);
  ~SteamAccelerationBridge();
  SteamAccelerationBridge(const SteamAccelerationBridge&) = delete;
  SteamAccelerationBridge& operator=(const SteamAccelerationBridge&) = delete;
 private:
  HANDLE job_ = nullptr;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};
#endif
