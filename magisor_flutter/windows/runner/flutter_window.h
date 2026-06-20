#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <memory>
#include <windows.h>

#include "win32_window.h"

class FlutterWindow : public Win32Window {
 public:
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

  void OnShakeDetected(double x, double y);

 protected:
  // Win32Window OS-level window proc callback.
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  flutter::DartProject project_;
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> mouse_hook_channel_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> capture_channel_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> system_channel_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> ocr_channel_;

  void StartMouseHook(int sensitivity);
  void StopMouseHook();
  void SetupChannels();
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
