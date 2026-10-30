#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  // One OpenReader window: a second launch (double-click a file, "Open with") hands its
  // files to the running window, which opens them as tabs, and exits. The mutex is held
  // for the life of this process.
  HANDLE instance_mutex =
      ::CreateMutexW(nullptr, TRUE, L"Local\\OpenReader.SingleInstance");
  if (instance_mutex != nullptr && ::GetLastError() == ERROR_ALREADY_EXISTS) {
    // The first instance may still be starting: give its window a moment to appear.
    HWND existing = nullptr;
    for (int attempt = 0; attempt < 50 && existing == nullptr; ++attempt) {
      existing = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"OpenReader");
      if (existing == nullptr) ::Sleep(100);
    }
    if (existing != nullptr) {
      std::string joined;
      for (const std::string& argument : command_line_arguments) {
        if (!argument.empty() && argument[0] != '-') joined += argument + "\n";
      }
      if (!joined.empty()) {
        COPYDATASTRUCT copy;
        copy.dwData = 0x4F524452;  // "ORDR", see flutter_window.cpp
        copy.cbData = static_cast<DWORD>(joined.size() + 1);
        copy.lpData = const_cast<char*>(joined.c_str());
        ::SendMessageW(existing, WM_COPYDATA, 0, reinterpret_cast<LPARAM>(&copy));
      }
      if (::IsIconic(existing)) ::ShowWindow(existing, SW_RESTORE);
      ::SetForegroundWindow(existing);
      return EXIT_SUCCESS;
    }
    // No window to hand over to (the other instance is gone): carry on as the only one.
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"OpenReader", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
