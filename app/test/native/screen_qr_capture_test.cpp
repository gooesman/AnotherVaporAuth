// Native regression harness. Run on a private, never-input desktop and sample
// only a synthetic memory bitmap. This never captures the user's desktop,
// switches desktops, writes screenshots, or opens Steam/account data.
#define AVA_SCREEN_QR_CAPTURE_TESTING
#include "../../windows/runner/screen_qr_capture.cpp"

#include <iostream>
#include <stdexcept>

struct ScreenQrCaptureTestPeer {
  static auto& Get(ScreenQrCapture& capture) { return *capture.impl_; }
};

namespace {

void Require(bool condition, const char* message) {
  if (!condition) throw std::runtime_error(message);
}

struct Reply {
  unsigned envelopes = 0;
  unsigned results = 0;
  bool decoded = false;
  bool success = false;
  std::string code;
  Value value;
  Value details;
};

class DecodedResult final : public Result {
 public:
  explicit DecodedResult(Reply* reply) : reply_(reply) {}

 protected:
  void SuccessInternal(const Value* result) override {
    ++reply_->results;
    reply_->success = true;
    if (result != nullptr) reply_->value = *result;
  }
  void ErrorInternal(const std::string& code, const std::string&,
                     const Value* details) override {
    ++reply_->results;
    reply_->code = code;
    if (details != nullptr) reply_->details = *details;
  }
  void NotImplementedInternal() override {
    ++reply_->results;
    reply_->code = "not_implemented";
  }

 private:
  Reply* reply_;
};

class TestMessenger final : public flutter::BinaryMessenger {
 public:
  void Send(const std::string&, const uint8_t*, size_t,
            flutter::BinaryReply = nullptr) const override {}

  void SetMessageHandler(const std::string&, flutter::BinaryMessageHandler handler) override {
    handler_ = std::move(handler);
  }

  std::shared_ptr<Reply> Capture() {
    Require(static_cast<bool>(handler_), "capture channel was not registered");
    auto reply = std::make_shared<Reply>();
    Map options;
    options[Value("instruction")] = Value("Drag to select. Esc to cancel.");
    options[Value("accent")] = Value(int64_t{0xff3b82f6});
    flutter::MethodCall<Value> call("captureRegion", std::make_unique<Value>(std::move(options)));
    const auto& codec = flutter::StandardMethodCodec::GetInstance();
    auto request = codec.EncodeMethodCall(call);
    handler_(request->data(), request->size(), [reply](const uint8_t* bytes, size_t size) {
      ++reply->envelopes;
      if (bytes == nullptr || size == 0) return;
      // Decode the real EngineMethodResult envelope synchronously. In
      // particular, Complete has already released every snapshot buffer.
      DecodedResult result(reply.get());
      reply->decoded = flutter::StandardMethodCodec::GetInstance()
          .DecodeAndProcessResponseEnvelope(bytes, size, &result);
    });
    return reply;
  }

 private:
  flutter::BinaryMessageHandler handler_;
};

// The harness has no screenshot fallback. CreateDesktop/SetThreadDesktop must
// succeed, or the executable fails before it creates any HWND or GDI source.
class IsolatedDesktop {
 public:
  IsolatedDesktop() {
    previous_ = GetThreadDesktop(GetCurrentThreadId());
    const std::wstring name = L"SteamKitCaptureTest-" + std::to_wstring(GetCurrentProcessId());
    desktop_ = CreateDesktopW(name.c_str(), nullptr, nullptr, 0,
        DESKTOP_CREATEWINDOW | DESKTOP_READOBJECTS | DESKTOP_WRITEOBJECTS, nullptr);
    Require(desktop_ != nullptr, "CreateDesktop failed; refusing the interactive desktop");
    if (!SetThreadDesktop(desktop_)) {
      CloseDesktop(desktop_);
      desktop_ = nullptr;
      Require(false, "SetThreadDesktop failed; refusing the interactive desktop");
    }
  }
  ~IsolatedDesktop() {
    SetThreadDesktop(previous_);
    if (desktop_ != nullptr) CloseDesktop(desktop_);
  }

 private:
  HDESK previous_ = nullptr;
  HDESK desktop_ = nullptr;
};

struct Fixture {
  static constexpr int kWidth = 640;
  static constexpr int kHeight = 480;
  CaptureTestHooks hooks;
  MemoryBitmap source;
  TestMessenger messenger;
  HWND owner = nullptr;
  std::unique_ptr<ScreenQrCapture> capture;
  std::shared_ptr<Reply> reply;

  Fixture() {
    hooks.desktop = RECT{-120, -80, kWidth - 120, kHeight - 80};
    hooks.cursor = POINT{0, 0};
    capture_test_hooks = &hooks;
    Require(source.Create(nullptr, kWidth, kHeight), "synthetic DIB allocation failed");
    hooks.source = source.dc;
    Pattern();
    owner = CreateWindowExW(WS_EX_TOOLWINDOW, L"STATIC", L"Synthetic capture owner",
        WS_POPUP, 20, 20, 240, 160, nullptr, nullptr, GetModuleHandleW(nullptr), nullptr);
    Require(owner != nullptr, "synthetic owner creation failed");
    ShowWindow(owner, SW_SHOWNOACTIVATE);
    capture = std::make_unique<ScreenQrCapture>(&messenger, owner);
  }

  ~Fixture() {
    capture.reset();
    if (owner != nullptr) DestroyWindow(owner);
    capture_test_hooks = nullptr;
  }

  void Pattern() {
    GdiFlush();
    for (int y = 0; y < kHeight; ++y) {
      for (int x = 0; x < kWidth; ++x) {
        const size_t pixel = (static_cast<size_t>(y) * kWidth + x) * 4;
        source.pixels[pixel] = static_cast<uint8_t>(x % 251);
        source.pixels[pixel + 1] = static_cast<uint8_t>(y % 241);
        source.pixels[pixel + 2] = static_cast<uint8_t>((x + y) % 239);
        source.pixels[pixel + 3] = 0;  // Deliberately emulate undefined BGRX alpha.
      }
    }
  }

  auto& State() { return ScreenQrCaptureTestPeer::Get(*capture); }

  void Begin() {
    reply = messenger.Capture();
    Require(reply->envelopes == 0, "capture replied before preparation");
    Require(State().overlay_ != nullptr, "selector was not created");
    Require(!IsWindowVisible(owner), "owner must be hidden before any frame wait");
    Require(hooks.transitions_disabled, "hide animation was not suspended");
  }

  void Tick() {
    Require(State().overlay_ != nullptr, "cannot tick a closed selector");
    SendMessageW(State().overlay_, WM_TIMER, kPrepareTimer, 0);
  }

  void Ready() {
    Begin();
    Tick();
    Require(!State().ready_, "snapshot was sampled before the second frame boundary");
    Require(State().snapshot_.pixels == nullptr, "snapshot was allocated too early");
    Tick();
    Require(reply->envelopes == 0, "preparation returned an unexpected error");
    Require(State().ready_, "selector was not ready after the second frame boundary");
    Require(State().activation_armed_, "activation cancellation was not armed");
    Paint();
  }

  void Paint() {
    const unsigned before = hooks.presents;
    Require(State().overlay_ != nullptr, "cannot paint a closed selector");
    UpdateWindow(State().overlay_);
    GdiFlush();
    Require(reply->envelopes == 0, "paint unexpectedly failed");
    Require(hooks.presents <= before + 1, "one paint published multiple visible frames");
  }

  void Cursor(int x, int y) {
    hooks.cursor = POINT{hooks.desktop.left + x, hooks.desktop.top + y};
  }

  void Down(int x, int y) {
    Cursor(x, y);
    SendMessageW(State().overlay_, WM_LBUTTONDOWN, MK_LBUTTON, 0);
  }

  void Move(int x, int y) {
    Cursor(x, y);
    SendMessageW(State().overlay_, WM_MOUSEMOVE, MK_LBUTTON, 0);
  }

  void Up(int x, int y) {
    Cursor(x, y);
    SendMessageW(State().overlay_, WM_LBUTTONUP, 0, 0);
  }

  void Closed() {
    Require(reply->envelopes == 1 && reply->results == 1 && reply->decoded,
            "capture must encode exactly one complete response");
    Require(State().pending_ == nullptr && State().overlay_ == nullptr,
            "selector or reply survived completion");
    Require(State().snapshot_.dc == nullptr && State().dimmed_.dc == nullptr &&
            State().frame_.dc == nullptr, "capture bitmap survived completion");
    Require(IsWindowVisible(owner) != FALSE, "owner was not restored");
    Require(!hooks.transitions_disabled, "owner transition preference was not restored");
  }

  void PixelEquals(const MemoryBitmap& bitmap, int x, int y, bool dimmed) {
    GdiFlush();
    const size_t pixel = (static_cast<size_t>(y) * kWidth + x) * 4;
    for (size_t component = 0; component < 3; ++component) {
      const unsigned original = source.pixels[pixel + component];
      const unsigned expected = dimmed ? (original * 159 + 127) / 255 : original;
      Require(bitmap.pixels[pixel + component] == expected, "composed pixel was incorrect");
    }
  }
};

void TestFrameBoundaryAndOpaqueCrop() {
  Fixture test;
  test.Begin();
  SendMessageW(test.State().overlay_, WM_ACTIVATE, WA_INACTIVE, 0);
  Require(test.reply->envelopes == 0, "initial inactive message canceled preparation");
  test.Tick();
  Require(test.hooks.flushes == 1 && test.State().snapshot_.pixels == nullptr,
          "first compositor boundary unexpectedly sampled pixels");
  // Replace the synthetic source after the first boundary. The crop must show
  // the new contents, not a cached/early image of the owner transition.
  const size_t changed = (size_t{230} * Fixture::kWidth + 210) * 4;
  test.source.pixels[changed] = 199;
  test.Tick();
  Require(test.hooks.flushes == 2 && test.State().ready_, "second frame was not prepared");
  test.Paint();
  test.Down(200, 220);
  test.Move(260, 280);
  test.Paint();
  test.Up(260, 280);
  test.Closed();
  Require(test.reply->success, "selected region did not succeed");
  const Map& image = std::get<Map>(test.reply->value);
  Require(std::get<int32_t>(image.at(Value("width"))) == 60 &&
          std::get<int32_t>(image.at(Value("height"))) == 60, "crop dimensions changed");
  const auto& pixels = std::get<std::vector<uint8_t>>(image.at(Value("bgra")));
  Require(pixels.size() == 60 * 60 * 4, "encoded crop length was incorrect");
  for (size_t y = 0; y < 60; ++y) {
    for (size_t x = 0; x < 60; ++x) {
      const size_t result_pixel = (y * 60 + x) * 4;
      const size_t source_pixel = ((220 + y) * Fixture::kWidth + 200 + x) * 4;
      Require(std::memcmp(pixels.data() + result_pixel, test.source.pixels + source_pixel, 3) == 0,
              "encoded crop outlived or differed from its original pixels");
      Require(pixels[result_pixel + 3] == 255, "BGRX capture was not made opaque");
    }
  }
}

void TestStableBufferedDragging() {
  Fixture test;
  test.Ready();
  test.PixelEquals(test.State().frame_, 550, 350, true);
  test.Down(200, 220);
  test.Paint();
  const DWORD before = GetGuiResources(GetCurrentProcess(), GR_GDIOBJECTS);
  for (int iteration = 0; iteration < 150; ++iteration) {
    const bool large = iteration % 2 == 0;
    const unsigned presents = test.hooks.presents;
    test.Move(large ? 450 : 300, large ? 400 : 320);
    test.Paint();
    Require(test.hooks.presents == presents + 1, "drag did not publish exactly one composed frame");
    test.PixelEquals(test.State().frame_, 250, 270, false);
    test.PixelEquals(test.State().frame_, 400, 350, !large);
    test.PixelEquals(test.State().frame_, 550, 350, true);
  }
  Require(GetGuiResources(GetCurrentProcess(), GR_GDIOBJECTS) <= before,
          "drag frames leaked GDI handles");
  SendMessageW(test.State().overlay_, WM_KEYDOWN, VK_ESCAPE, 0);
  test.Closed();
  Require(test.reply->success && std::holds_alternative<std::monostate>(test.reply->value),
          "escape did not return cancellation");
}

void TestCancellationMessages() {
  struct CancelMessage { UINT message; WPARAM argument; bool needs_drag; };
  const CancelMessage cases[] = {
      {WM_KEYDOWN, VK_ESCAPE, false}, {WM_SYSKEYDOWN, VK_ESCAPE, false},
      {WM_RBUTTONDOWN, 0, false}, {WM_CLOSE, 0, false},
      {WM_CANCELMODE, 0, false}, {WM_ACTIVATE, WA_INACTIVE, false},
      {WM_CAPTURECHANGED, 0, true},
  };
  for (const auto& entry : cases) {
    Fixture test;
    test.Ready();
    if (entry.needs_drag) test.Down(220, 240);
    SendMessageW(test.State().overlay_, entry.message, entry.argument, 0);
    test.Closed();
    Require(test.reply->success && std::holds_alternative<std::monostate>(test.reply->value),
            "cancellation did not return a null success envelope");
  }
}

void TestFailureStages() {
  for (int failure = 0; failure < 5; ++failure) {
    Fixture test;
    if (failure == 0) test.hooks.flush_result = E_FAIL;
    if (failure == 1) test.hooks.fail_copy = true;
    if (failure == 2) test.hooks.fail_display = true;
    if (failure == 3) test.hooks.source = nullptr;
    if (failure == 4) test.hooks.desktop = RECT{0, 0, 20000, 20000};
    test.Begin();
    test.Tick();
    if (failure != 0) test.Tick();
    test.Closed();
    Require(!test.reply->success, "injected API failure returned success");
    const Map& details = std::get<Map>(test.reply->details);
    const std::string expected_stage = failure == 0 ? "prepare" : failure == 2 ? "display" : "snapshot";
    Require(std::get<std::string>(details.at(Value("stage"))) == expected_stage,
            "API failure lost its safe diagnostic stage");
    if (failure == 0) {
      Require(test.reply->code == "capture_prepare_failed", "prepare failure code changed");
      Require(details.find(Value("win32Error")) != details.end(), "compositor HRESULT was lost");
    }
  }
}

void TestOwnerReappearingAndTinyDrag() {
  {
    Fixture test;
    test.Begin();
    test.Tick();
    ShowWindow(test.owner, SW_SHOWNOACTIVATE);
    test.Tick();
    test.Closed();
    Require(test.reply->code == "capture_prepare_failed", "visible owner was captured");
    Require(test.hooks.flushes == 1, "owner visibility was not checked before second frame");
  }
  {
    Fixture test;
    test.Ready();
    test.Down(220, 240);
    test.Up(224, 244);
    Require(test.reply->envelopes == 0 && test.State().ready_, "tiny drag should be retryable");
    test.Paint();
    test.Down(250, 260);
    // Physical cursor positions are clamped to the virtual desktop, including
    // a monitor left/above the primary monitor.
    test.Up(-2000, -2000);
    test.Closed();
    const Map& image = std::get<Map>(test.reply->value);
    Require(std::get<int32_t>(image.at(Value("width"))) == 250 &&
            std::get<int32_t>(image.at(Value("height"))) == 260,
            "negative-origin/clamped reverse selection was incorrect");
  }
}

void TestBusyAndCleanup() {
  Fixture test;
  test.Ready();
  const HWND overlay = test.State().overlay_;
  auto busy = test.messenger.Capture();
  Require(busy->envelopes == 1 && busy->decoded && busy->code == "capture_busy",
          "duplicate request did not receive capture_busy");
  Require(test.reply->envelopes == 0 && test.State().overlay_ == overlay,
          "duplicate request disturbed the active selection");
  SendMessageW(overlay, WM_CLOSE, 0, 0);
  test.Closed();
  const DWORD before = GetGuiResources(GetCurrentProcess(), GR_GDIOBJECTS);
  for (int iteration = 0; iteration < 15; ++iteration) {
    test.Ready();
    SendMessageW(test.State().overlay_, WM_CLOSE, 0, 0);
    test.Closed();
  }
  Require(GetGuiResources(GetCurrentProcess(), GR_GDIOBJECTS) <= before,
          "repeated capture/cancel leaked GDI handles");
}

}  // namespace

int main() {
  try {
    IsolatedDesktop desktop;
    TestFrameBoundaryAndOpaqueCrop();
    std::cout << "PASS frame boundaries, hidden owner, opaque crop and real codec reply\n";
    TestStableBufferedDragging();
    std::cout << "PASS single-presentation dragging, stable dimming and GDI handles\n";
    TestCancellationMessages();
    std::cout << "PASS escape, right-click, close, cancel-mode, focus and capture-loss\n";
    TestFailureStages();
    std::cout << "PASS compositor, copy, source, size and display failures\n";
    TestOwnerReappearingAndTinyDrag();
    std::cout << "PASS owner reappearing, tiny-drag retry and negative desktop origin\n";
    TestBusyAndCleanup();
    std::cout << "PASS busy request and repeated lifecycle resource cleanup\n";
    return 0;
  } catch (const std::exception& error) {
    std::cerr << "FAIL screen capture native harness: " << error.what()
              << " (last Win32 error " << GetLastError() << ")\n";
    return 1;
  }
}
