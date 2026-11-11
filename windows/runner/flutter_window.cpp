#include "flutter_window.h"

#include <optional>
#include <sstream>
#include <string>

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

// Tag on the WM_COPYDATA a second instance sends: "ORDR".
static constexpr ULONG_PTR kForwardedFilesTag = 0x4F524452;

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_COPYDATA: {
      // A second OpenReader process forwarded the files it was started with (see main.cpp):
      // hand them to Dart, which opens each as a tab, and bring this window forward.
      const auto* data = reinterpret_cast<const COPYDATASTRUCT*>(lparam);
      if (data && data->dwData == kForwardedFilesTag && flutter_controller_ && flutter_controller_->engine()) {
        const std::string joined(static_cast<const char*>(data->lpData),
                                 data->cbData > 0 ? data->cbData - 1 : 0);
        flutter::EncodableList paths;
        std::istringstream lines(joined);
        for (std::string line; std::getline(lines, line);) {
          if (!line.empty()) paths.push_back(flutter::EncodableValue(line));
        }
        if (!paths.empty()) {
          flutter::MethodChannel<flutter::EncodableValue> channel(
              flutter_controller_->engine()->messenger(), "openreader/open_files",
              &flutter::StandardMethodCodec::GetInstance());
          channel.InvokeMethod("openFiles", std::make_unique<flutter::EncodableValue>(std::move(paths)));
        }
        if (::IsIconic(hwnd)) ::ShowWindow(hwnd, SW_RESTORE);
        ::SetForegroundWindow(hwnd);
        return TRUE;
      }
      break;
    }
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
