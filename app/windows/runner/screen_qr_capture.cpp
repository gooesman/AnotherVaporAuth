#include "screen_qr_capture.h"

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <cstdint>
#include <cstring>
#include <exception>
#include <new>
#include <string>
#include <utility>
#include <vector>

namespace {

using Value = flutter::EncodableValue;
using Map = flutter::EncodableMap;
using Result = flutter::MethodResult<Value>;

constexpr wchar_t kCaptureClass[] = L"AVA_SCREEN_QR_REGION_SELECTOR";
constexpr UINT_PTR kPrepareTimer = 1;
constexpr UINT kPrepareDelayMs = 160;
constexpr int64_t kMaxDesktopPixels = 100000000;
constexpr int64_t kMaxRegionPixels = 16000000;
constexpr uint32_t kDefaultAccent = 0xff3b82f6;

struct MemoryBitmap {
  MemoryBitmap() = default;
  MemoryBitmap(const MemoryBitmap&) = delete;
  MemoryBitmap& operator=(const MemoryBitmap&) = delete;

  HDC dc = nullptr;
  HBITMAP bitmap = nullptr;
  HGDIOBJ previous = nullptr;
  uint8_t* pixels = nullptr;

  ~MemoryBitmap() { Reset(); }

  void Reset() {
    if (dc != nullptr && previous != nullptr) {
      SelectObject(dc, previous);
    }
    if (bitmap != nullptr) DeleteObject(bitmap);
    if (dc != nullptr) DeleteDC(dc);
    dc = nullptr;
    bitmap = nullptr;
    previous = nullptr;
    pixels = nullptr;
  }

  bool Create(HDC reference, int width, int height) {
    Reset();
    dc = CreateCompatibleDC(reference);
    if (dc == nullptr) return false;
    BITMAPINFO info{};
    info.bmiHeader.biSize = static_cast<DWORD>(sizeof(BITMAPINFOHEADER));
    info.bmiHeader.biWidth = width;
    info.bmiHeader.biHeight = -height;  // Top-down, four bytes per pixel.
    info.bmiHeader.biPlanes = 1;
    info.bmiHeader.biBitCount = 32;
    info.bmiHeader.biCompression = BI_RGB;
    void* data = nullptr;
    bitmap = CreateDIBSection(reference, &info, DIB_RGB_COLORS, &data, nullptr, 0);
    if (bitmap == nullptr || data == nullptr) return false;
    previous = SelectObject(dc, bitmap);
    if (previous == nullptr || previous == HGDI_ERROR) {
      previous = nullptr;
      return false;
    }
    pixels = static_cast<uint8_t*>(data);
    return true;
  }
};

void ReplyCaptureFailure(Result* result) noexcept {
  if (result == nullptr) return;
  try {
    // Keep this response minimal: the normal error's strings/map may have
    // failed to allocate. The short code also fits MSVC's inline string buffer.
    result->Error("capture_failed");
  } catch (...) {
    try {
      // An empty platform reply requires no codec envelope allocation. If even
      // a minimal error cannot be encoded, finish the call without unwinding
      // through a Windows callback or attempting another allocation.
      result->NotImplemented();
    } catch (...) {
      // Last-resort memory failure: window/resource cleanup already happened.
    }
  }
}

void ReplyError(Result* result, const char* code, const char* message,
                 DWORD system_error = ERROR_SUCCESS) noexcept {
  try {
    Map details;
    if (system_error != ERROR_SUCCESS) {
      details[Value("win32Error")] = Value(static_cast<int64_t>(system_error));
    }
    result->Error(code, message, Value(details));
  } catch (...) {
    ReplyCaptureFailure(result);
  }
}

bool DecodeInstruction(const std::string& text, std::wstring* wide) {
  if (text.empty() || text.size() > 2048 || text.find('\0') != std::string::npos) {
    return false;
  }
  const int length = static_cast<int>(text.size());
  const int count = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                                       text.data(), length, nullptr, 0);
  if (count == 0) return false;
  wide->resize(static_cast<size_t>(count));
  return MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.data(), length,
                              wide->data(), count) == count;
}

COLORREF AccentColor(uint32_t argb) {
  return RGB((argb >> 16) & 0xff, (argb >> 8) & 0xff, argb & 0xff);
}

}  // namespace

struct ScreenQrCapture::Impl {
  Impl(flutter::BinaryMessenger* messenger, HWND owner) : owner_(owner) {
    channel_ = std::make_unique<flutter::MethodChannel<Value>>(
        messenger, "ava/screen_capture", &flutter::StandardMethodCodec::GetInstance());
    channel_->SetMethodCallHandler(
        [this](const flutter::MethodCall<Value>& call, std::unique_ptr<Result> result) noexcept {
          try {
            if (call.method_name() != "captureRegion") {
              result->NotImplemented();
              return;
            }
            Begin(call.arguments(), result);
            return;
          } catch (const std::bad_alloc&) {
          } catch (const std::exception&) {
          } catch (...) {
          }
          HandleException(std::move(result));
        });
  }

  ~Impl() {
    channel_->SetMethodCallHandler(nullptr);
    // The Flutter host is already closing. Do not show or focus it again.
    Complete(nullptr, false);
    if (registered_class_) {
      UnregisterClassW(kCaptureClass, GetModuleHandleW(nullptr));
    }
  }

  void Begin(const Value* arguments, std::unique_ptr<Result>& result) {
    if (pending_ != nullptr) {
      ReplyError(result.get(), "capture_busy", "A screen selection is already in progress.");
      return;
    }
    const Map* options = arguments == nullptr ? nullptr : std::get_if<Map>(arguments);
    if (options == nullptr) {
      ReplyError(result.get(), "invalid_arguments", "Screen capture options must be a map.");
      return;
    }
    const auto instruction = options->find(Value("instruction"));
    const auto* text = instruction == options->end()
        ? nullptr : std::get_if<std::string>(&instruction->second);
    if (text == nullptr || !DecodeInstruction(*text, &instruction_)) {
      ReplyError(result.get(), "invalid_arguments", "A valid localized selection instruction is required.");
      return;
    }
    uint32_t argb = kDefaultAccent;
    const auto color = options->find(Value("accent"));
    if (color != options->end()) {
      if (const auto* number32 = std::get_if<int32_t>(&color->second)) {
        argb = static_cast<uint32_t>(*number32);
      } else if (const auto* number64 = std::get_if<int64_t>(&color->second)) {
        if (*number64 < 0 || *number64 > 0xffffffffLL) {
          ReplyError(result.get(), "invalid_arguments", "The accent must be a 32-bit ARGB color.");
          return;
        }
        argb = static_cast<uint32_t>(*number64);
      } else {
        ReplyError(result.get(), "invalid_arguments", "The accent must be a 32-bit ARGB color.");
        return;
      }
    }
    accent_ = AccentColor(argb);
    if (!IsWindow(owner_)) {
      ReplyError(result.get(), "capture_unavailable", "The application window is unavailable.");
      return;
    }
    saved_placement_ = WINDOWPLACEMENT{};
    saved_placement_.length = static_cast<UINT>(sizeof(WINDOWPLACEMENT));
    if (!GetWindowPlacement(owner_, &saved_placement_)) {
      const DWORD status = GetLastError();
      ReplyError(result.get(), "capture_unavailable", "Could not save the application window state.", status);
      return;
    }
    if (!EnsureWindowClass()) {
      const DWORD status = GetLastError();
      ReplyError(result.get(), "capture_unavailable", "Could not create the screen selector.", status);
      return;
    }
    saved_foreground_ = GetForegroundWindow();
    saved_focus_ = GetFocus();
    owner_was_visible_ = IsWindowVisible(owner_) != FALSE;
    GetCursorPos(&initial_cursor_);
    pending_ = std::move(result);
    finishing_ = false;
    dragging_ = false;
    ready_ = false;
    overlay_ = CreateWindowExW(WS_EX_TOPMOST | WS_EX_TOOLWINDOW,
        kCaptureClass, L"AVA", WS_POPUP, 0, 0, 1, 1,
        nullptr, nullptr, GetModuleHandleW(nullptr), this);
    if (overlay_ == nullptr) {
      const DWORD status = GetLastError();
      Fail("capture_unavailable", "Could not create the screen selector.", status);
      return;
    }
    owner_hidden_ = true;
    ShowWindow(owner_, SW_HIDE);
    // Let DWM repaint the underlying desktop after AVA disappears. Selection
    // and this preparation delay are driven by the normal Windows event loop.
    if (SetTimer(overlay_, kPrepareTimer, kPrepareDelayMs, nullptr) == 0) {
      const DWORD status = GetLastError();
      Fail("capture_unavailable", "Could not prepare the screen selector.", status);
    }
  }

  bool EnsureWindowClass() {
    if (registered_class_) return true;
    WNDCLASSEXW window_class{};
    window_class.cbSize = static_cast<UINT>(sizeof(window_class));
    window_class.hInstance = GetModuleHandleW(nullptr);
    window_class.lpfnWndProc = WindowProcedure;
    window_class.lpszClassName = kCaptureClass;
    window_class.hCursor = LoadCursorW(nullptr, IDC_CROSS);
    window_class.style = CS_HREDRAW | CS_VREDRAW;
    if (RegisterClassExW(&window_class) == 0) return false;
    registered_class_ = true;
    return true;
  }

  void Prepare() {
    if (pending_ == nullptr || finishing_) return;
    KillTimer(overlay_, kPrepareTimer);
    // The host manifest uses PerMonitorV2. All dimensions and cursor positions
    // here are physical pixels, including monitors left/above the primary one.
    virtual_left_ = GetSystemMetrics(SM_XVIRTUALSCREEN);
    virtual_top_ = GetSystemMetrics(SM_YVIRTUALSCREEN);
    width_ = GetSystemMetrics(SM_CXVIRTUALSCREEN);
    height_ = GetSystemMetrics(SM_CYVIRTUALSCREEN);
    const int64_t pixel_count = static_cast<int64_t>(width_) * height_;
    if (width_ <= 0 || height_ <= 0 || pixel_count > kMaxDesktopPixels) {
      Fail("desktop_too_large", "The virtual desktop is too large to capture safely.");
      return;
    }
    HDC desktop = GetDC(nullptr);
    if (desktop == nullptr) {
      const DWORD status = GetLastError();
      Fail("capture_failed", "Could not access the desktop image.", status);
      return;
    }
    bool captured = snapshot_.Create(desktop, width_, height_) &&
                    shade_.Create(desktop, 1, 1);
    DWORD status = captured ? ERROR_SUCCESS : GetLastError();
    if (captured) {
      std::memset(shade_.pixels, 0, 4);
      captured = BitBlt(snapshot_.dc, 0, 0, width_, height_, desktop,
                         virtual_left_, virtual_top_, SRCCOPY | CAPTUREBLT) != FALSE;
      if (!captured) status = GetLastError();
    }
    ReleaseDC(nullptr, desktop);
    if (!captured) {
      Fail("capture_failed", "Could not copy the desktop image.", status);
      return;
    }
    SetupInstruction();
    ready_ = true;
    if (!SetWindowPos(overlay_, HWND_TOPMOST, virtual_left_, virtual_top_, width_, height_,
                      SWP_SHOWWINDOW)) {
      const DWORD window_status = GetLastError();
      Fail("capture_unavailable", "Could not display the screen selector.", window_status);
      return;
    }
    if (overlay_ == nullptr || pending_ == nullptr) return;
    SetForegroundWindow(overlay_);
    if (overlay_ == nullptr || pending_ == nullptr) return;
    SetFocus(overlay_);
    if (overlay_ == nullptr || pending_ == nullptr) return;
    InvalidateRect(overlay_, nullptr, FALSE);
  }

  void SetupInstruction() {
    const UINT dpi = GetDpiForWindow(owner_);
    scale_dpi_ = dpi == 0 ? 96 : dpi;
    MONITORINFO monitor{};
    monitor.cbSize = static_cast<DWORD>(sizeof(monitor));
    RECT work{virtual_left_, virtual_top_, virtual_left_ + width_, virtual_top_ + height_};
    if (GetMonitorInfoW(MonitorFromPoint(initial_cursor_, MONITOR_DEFAULTTONEAREST), &monitor)) {
      work = monitor.rcWork;
    }
    const int margin = Scale(24);
    const int panel_width = (std::max)(1, (std::min)(Scale(860),
        static_cast<int>(work.right - work.left) - margin * 2));
    instruction_rect_.left = work.left - virtual_left_ +
        ((work.right - work.left) - panel_width) / 2;
    instruction_rect_.top = work.top - virtual_top_ + margin;
    instruction_rect_.right = instruction_rect_.left + panel_width;
    instruction_rect_.bottom = instruction_rect_.top + Scale(72);
    font_ = CreateFontW(-Scale(16), 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
        DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");
  }

  int Scale(int value) const { return MulDiv(value, static_cast<int>(scale_dpi_), 96); }

  POINT CursorInSnapshot() const {
    POINT point{};
    GetCursorPos(&point);
    point.x = (std::max)(0L, (std::min)(static_cast<LONG>(width_), point.x - virtual_left_));
    point.y = (std::max)(0L, (std::min)(static_cast<LONG>(height_), point.y - virtual_top_));
    return point;
  }

  RECT Selection() const {
    return RECT{(std::min)(anchor_.x, current_.x), (std::min)(anchor_.y, current_.y),
                (std::max)(anchor_.x, current_.x), (std::max)(anchor_.y, current_.y)};
  }

  void Paint(HWND window) {
    PAINTSTRUCT paint{};
    HDC canvas = BeginPaint(window, &paint);
    if (ready_ && canvas != nullptr) {
      BitBlt(canvas, 0, 0, width_, height_, snapshot_.dc, 0, 0, SRCCOPY);
      BLENDFUNCTION blend{AC_SRC_OVER, 0, 96, 0};
      AlphaBlend(canvas, 0, 0, width_, height_, shade_.dc, 0, 0, 1, 1, blend);
      HBRUSH accent_brush = CreateSolidBrush(accent_);
      if (dragging_) {
        RECT selection = Selection();
        const int selected_width = static_cast<int>(selection.right - selection.left);
        const int selected_height = static_cast<int>(selection.bottom - selection.top);
        if (selected_width > 0 && selected_height > 0) {
          BitBlt(canvas, selection.left, selection.top, selected_width, selected_height,
                   snapshot_.dc, selection.left, selection.top, SRCCOPY);
          if (accent_brush != nullptr) {
            const int stroke = (std::max)(2, Scale(2));
            for (int index = 0; index < stroke; ++index) {
              FrameRect(canvas, &selection, accent_brush);
              InflateRect(&selection, -1, -1);
              if (selection.right <= selection.left || selection.bottom <= selection.top) break;
            }
          }
        }
      }
      HBRUSH panel_brush = CreateSolidBrush(RGB(24, 27, 33));
      if (panel_brush != nullptr) {
        FillRect(canvas, &instruction_rect_, panel_brush);
        DeleteObject(panel_brush);
      }
      if (accent_brush != nullptr) {
        RECT accent_line = instruction_rect_;
        accent_line.bottom = accent_line.top + (std::max)(2, Scale(3));
        FillRect(canvas, &accent_line, accent_brush);
        DeleteObject(accent_brush);
      }
      RECT text_rect = instruction_rect_;
      InflateRect(&text_rect, -Scale(18), -Scale(14));
      HGDIOBJ previous_font = font_ == nullptr ? nullptr : SelectObject(canvas, font_);
      SetBkMode(canvas, TRANSPARENT);
      SetTextColor(canvas, RGB(255, 255, 255));
      DrawTextW(canvas, instruction_.c_str(), static_cast<int>(instruction_.size()),
                  &text_rect, DT_CENTER | DT_WORDBREAK | DT_NOPREFIX);
      if (previous_font != nullptr && previous_font != HGDI_ERROR) {
        SelectObject(canvas, previous_font);
      }
    }
    EndPaint(window, &paint);
  }

  void CaptureSelection() {
    const RECT selection = Selection();
    const int crop_width = static_cast<int>(selection.right - selection.left);
    const int crop_height = static_cast<int>(selection.bottom - selection.top);
    if (crop_width < 8 || crop_height < 8) {
      // A click or accidental tiny drag is retryable within the same overlay.
      InvalidateRect(overlay_, nullptr, FALSE);
      return;
    }
    const int64_t pixel_count = static_cast<int64_t>(crop_width) * crop_height;
    if (pixel_count > kMaxRegionPixels) {
      Fail("region_too_large", "Select a smaller rectangle around the QR code.");
      return;
    }
    const size_t row_bytes = static_cast<size_t>(crop_width) * 4;
    const size_t snapshot_stride = static_cast<size_t>(width_) * 4;
    std::vector<uint8_t> pixels(static_cast<size_t>(pixel_count) * 4);
    // Finish pending GDI writes before accessing the DIB memory directly.
    GdiFlush();
    for (int row = 0; row < crop_height; ++row) {
      const size_t source_offset = (static_cast<size_t>(selection.top) +
          static_cast<size_t>(row)) * snapshot_stride + static_cast<size_t>(selection.left) * 4;
      uint8_t* destination = pixels.data() + static_cast<size_t>(row) * row_bytes;
      std::memcpy(destination, snapshot_.pixels + source_offset, row_bytes);
      // BI_RGB produces BGRX. Give the Dart decoder a definite opaque alpha.
      for (size_t column = 3; column < row_bytes; column += 4) destination[column] = 255;
    }
    Map image;
    image[Value("width")] = Value(static_cast<int32_t>(crop_width));
    image[Value("height")] = Value(static_cast<int32_t>(crop_height));
    image[Value("bgra")] = Value(std::move(pixels));
    Value response(std::move(image));
    Complete(&response, true);
  }

  // This path only releases handles and calls Win32; it does not allocate STL
  // objects, so it also works after a failed screenshot or codec allocation.
  void Cleanup(bool restore) noexcept {
    finishing_ = true;
    dragging_ = false;
    ready_ = false;
    if (overlay_ != nullptr) {
      const HWND window = overlay_;
      overlay_ = nullptr;
      KillTimer(window, kPrepareTimer);
      if (GetCapture() == window) ReleaseCapture();
      DestroyWindow(window);
    }
    snapshot_.Reset();
    shade_.Reset();
    if (font_ != nullptr) {
      DeleteObject(font_);
      font_ = nullptr;
    }
    if (restore && owner_hidden_ && IsWindow(owner_)) {
      if (owner_was_visible_) {
        SetWindowPlacement(owner_, &saved_placement_);
        ShowWindow(owner_, static_cast<int>(saved_placement_.showCmd));
      }
      if (IsWindow(saved_foreground_) && IsWindowVisible(saved_foreground_)) {
        SetForegroundWindow(saved_foreground_);
      } else if (owner_was_visible_) {
        SetForegroundWindow(owner_);
      }
      if (GetForegroundWindow() == owner_ && !IsIconic(owner_) && IsWindow(saved_focus_)) {
        SetFocus(saved_focus_);
      }
    }
    owner_hidden_ = false;
    finishing_ = false;
  }

  void Complete(const Value* response, bool restore) noexcept {
    auto result = std::move(pending_);
    Cleanup(restore);
    if (result != nullptr) {
      try {
        if (response == nullptr) result->Success(Value());
        else result->Success(*response);
      } catch (...) {
        ReplyCaptureFailure(result.get());
      }
    }
  }

  void Fail(const char* code, const char* message, DWORD status = ERROR_SUCCESS) noexcept {
    auto result = std::move(pending_);
    Cleanup(true);
    if (result != nullptr) ReplyError(result.get(), code, message, status);
  }

  void HandleException(std::unique_ptr<Result> unadopted = nullptr) noexcept {
    if (unadopted != nullptr) {
      // Begin has not hidden AVA or adopted this call yet. Leave any unrelated
      // in-flight selector alone (for example, an error replying to a busy call).
      ReplyCaptureFailure(unadopted.get());
      return;
    }
    auto result = std::move(pending_);
    Cleanup(true);
    ReplyCaptureFailure(result.get());
  }

  static LRESULT CALLBACK WindowProcedure(HWND window, UINT message,
                                          WPARAM wparam, LPARAM lparam) noexcept {
    try {
      return DispatchWindowMessage(window, message, wparam, lparam);
    } catch (const std::bad_alloc&) {
    } catch (const std::exception&) {
    } catch (...) {
    }
    auto* self = reinterpret_cast<Impl*>(GetWindowLongPtrW(window, GWLP_USERDATA));
    if (self != nullptr) self->HandleException();
    return 0;
  }

  static LRESULT DispatchWindowMessage(HWND window, UINT message,
                                        WPARAM wparam, LPARAM lparam) {
    auto* self = reinterpret_cast<Impl*>(GetWindowLongPtrW(window, GWLP_USERDATA));
    if (message == WM_NCCREATE) {
      const auto* creation = reinterpret_cast<const CREATESTRUCTW*>(lparam);
      self = static_cast<Impl*>(creation->lpCreateParams);
      SetWindowLongPtrW(window, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
      self->overlay_ = window;
    }
    if (self == nullptr) return DefWindowProcW(window, message, wparam, lparam);
    if (message == WM_NCDESTROY) {
      SetWindowLongPtrW(window, GWLP_USERDATA, 0);
      if (self->overlay_ == window) self->overlay_ = nullptr;
      return DefWindowProcW(window, message, wparam, lparam);
    }
    if (self->finishing_) return DefWindowProcW(window, message, wparam, lparam);
    switch (message) {
      case WM_TIMER:
        if (wparam == kPrepareTimer) self->Prepare();
        return 0;
      case WM_ERASEBKGND:
        return 1;
      case WM_PAINT:
        self->Paint(window);
        return 0;
      case WM_SETCURSOR:
        SetCursor(LoadCursorW(nullptr, IDC_CROSS));
        return TRUE;
      case WM_LBUTTONDOWN:
        if (self->ready_) {
          self->anchor_ = self->CursorInSnapshot();
          self->current_ = self->anchor_;
          self->dragging_ = true;
          SetCapture(window);
          InvalidateRect(window, nullptr, FALSE);
        }
        return 0;
      case WM_MOUSEMOVE:
        if (self->dragging_) {
          self->current_ = self->CursorInSnapshot();
          InvalidateRect(window, nullptr, FALSE);
        }
        return 0;
      case WM_LBUTTONUP:
        if (self->dragging_) {
          self->current_ = self->CursorInSnapshot();
          self->dragging_ = false;
          if (GetCapture() == window) ReleaseCapture();
          self->CaptureSelection();
        }
        return 0;
      case WM_CAPTURECHANGED:
        if (self->dragging_) self->Complete(nullptr, true);
        return 0;
      case WM_RBUTTONDOWN:
      case WM_CLOSE:
        self->Complete(nullptr, true);
        return 0;
      case WM_KEYDOWN:
      case WM_SYSKEYDOWN:
        if (wparam == VK_ESCAPE) {
          self->Complete(nullptr, true);
          return 0;
        }
        break;
      case WM_ACTIVATE:
        if (LOWORD(wparam) == WA_INACTIVE && self->ready_) {
          self->Complete(nullptr, true);
        }
        return 0;
      case WM_DISPLAYCHANGE:
        self->Fail("display_changed", "The display layout changed. Try selecting the QR code again.");
        return 0;
      case WM_DPICHANGED:
        // Keep the frozen virtual-desktop rectangle in physical pixels instead
        // of adopting a suggested single-monitor window rectangle.
        return 0;
      case WM_DESTROY:
        if (self->pending_ != nullptr) {
          self->overlay_ = nullptr;
          self->Complete(nullptr, true);
        }
        return 0;
      default:
        break;
    }
    return DefWindowProcW(window, message, wparam, lparam);
  }

  HWND owner_ = nullptr;
  HWND overlay_ = nullptr;
  HWND saved_foreground_ = nullptr;
  HWND saved_focus_ = nullptr;
  WINDOWPLACEMENT saved_placement_{};
  bool registered_class_ = false;
  bool owner_was_visible_ = false;
  bool owner_hidden_ = false;
  bool finishing_ = false;
  bool ready_ = false;
  bool dragging_ = false;
  int virtual_left_ = 0;
  int virtual_top_ = 0;
  int width_ = 0;
  int height_ = 0;
  UINT scale_dpi_ = 96;
  COLORREF accent_ = AccentColor(kDefaultAccent);
  POINT initial_cursor_{};
  POINT anchor_{};
  POINT current_{};
  RECT instruction_rect_{};
  HFONT font_ = nullptr;
  std::wstring instruction_;
  MemoryBitmap snapshot_;
  MemoryBitmap shade_;
  std::unique_ptr<flutter::MethodChannel<Value>> channel_;
  std::unique_ptr<Result> pending_;
};

ScreenQrCapture::ScreenQrCapture(flutter::BinaryMessenger* messenger, HWND owner)
    : impl_(std::make_unique<Impl>(messenger, owner)) {}

ScreenQrCapture::~ScreenQrCapture() = default;
