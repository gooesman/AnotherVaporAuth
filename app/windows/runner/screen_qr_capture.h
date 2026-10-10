#ifndef RUNNER_SCREEN_QR_CAPTURE_H_
#define RUNNER_SCREEN_QR_CAPTURE_H_

#include <flutter/binary_messenger.h>
#include <windows.h>

#include <memory>

// Owns a non-modal native region selector. Pixels stay in memory and only the
// selected rectangle is delivered to Flutter.
class ScreenQrCapture {
 public:
  ScreenQrCapture(flutter::BinaryMessenger* messenger, HWND owner);
  ~ScreenQrCapture();

  ScreenQrCapture(const ScreenQrCapture&) = delete;
  ScreenQrCapture& operator=(const ScreenQrCapture&) = delete;

 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};

#endif  // RUNNER_SCREEN_QR_CAPTURE_H_
