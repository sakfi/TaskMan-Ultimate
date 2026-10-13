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

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  // Single-instance enforcement:
  // If an instance is already open, focus it and exit this new instance.
  HANDLE mutex = ::CreateMutexW(nullptr, TRUE, L"TaskManUltimate_SingleInstance_Mutex_9F8D2A");
  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    HWND existing_window = nullptr;
    for (int i = 0; i < 12; ++i) {
      existing_window = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"TaskMan Ultimate");
      if (!existing_window) {
        existing_window = ::FindWindowW(nullptr, L"TaskMan Ultimate");
      }
      if (existing_window) {
        break;
      }
      ::Sleep(50);
    }

    if (existing_window) {
      if (::IsIconic(existing_window)) {
        ::ShowWindow(existing_window, SW_RESTORE);
      } else {
        ::ShowWindow(existing_window, SW_SHOW);
      }
      DWORD current_thread_id = ::GetCurrentThreadId();
      DWORD window_thread_id = ::GetWindowThreadProcessId(existing_window, nullptr);
      ::AttachThreadInput(current_thread_id, window_thread_id, TRUE);
      ::SetForegroundWindow(existing_window);
      ::BringWindowToTop(existing_window);
      ::AttachThreadInput(current_thread_id, window_thread_id, FALSE);
    }

    if (mutex != nullptr) {
      ::CloseHandle(mutex);
    }
    ::CoUninitialize();
    return EXIT_SUCCESS;
  }

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"TaskMan Ultimate", origin, size)) {
    if (mutex != nullptr) {
      ::CloseHandle(mutex);
    }
    ::CoUninitialize();
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  if (mutex != nullptr) {
    ::CloseHandle(mutex);
  }
  return EXIT_SUCCESS;
}
