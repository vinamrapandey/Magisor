#include "flutter_window.h"

#include <optional>
#include <flutter/generated_plugin_registrant.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <iostream>
#include <vector>
#include <chrono>
#include <cmath>

static HHOOK g_mouseHook = NULL;
static FlutterWindow* g_flutterWindow = nullptr;
static int g_sensitivity = 1; // 0=low, 1=medium, 2=high

struct MousePoint {
    int x;
    int y;
    long long timestamp_ms;
};
static std::vector<MousePoint> g_points;
static int g_lastDirection = 0;
static int g_reversals = 0;
static long long g_lastTriggerTime = 0;

static long long GetTimeMs() {
    return std::chrono::duration_cast<std::chrono::milliseconds>(
               std::chrono::steady_clock::now().time_since_epoch())
        .count();
}

static LRESULT CALLBACK MouseHookCallback(int nCode, WPARAM wParam, LPARAM lParam) {
    if (nCode >= 0 && wParam == WM_MOUSEMOVE) {
        MSLLHOOKSTRUCT* hookStruct = (MSLLHOOKSTRUCT*)lParam;
        int x = hookStruct->pt.x;
        int y = hookStruct->pt.y;
        long long now = GetTimeMs();

        if (g_lastTriggerTime != 0 && (now - g_lastTriggerTime) < 1500) {
            g_points.clear();
            g_reversals = 0;
        } else {
            g_points.push_back({x, y, now});
            
            while (!g_points.empty() && (now - g_points.front().timestamp_ms) > 400) {
                g_points.erase(g_points.begin());
            }

            if (g_points.size() >= 2) {
                int requiredReversals = 3;
                int minDistance = 20;
                if (g_sensitivity == 0) { requiredReversals = 5; minDistance = 30; }
                else if (g_sensitivity == 2) { requiredReversals = 2; minDistance = 15; }

                auto& current = g_points.back();
                auto& previous = g_points[g_points.size() - 2];
                int dx = current.x - previous.x;

                if (std::abs(dx) > minDistance) {
                    int newDirection = dx > 0 ? 1 : -1;
                    if (g_lastDirection != 0 && newDirection != g_lastDirection) {
                        g_reversals++;
                    }
                    g_lastDirection = newDirection;

                    if (g_reversals >= requiredReversals) {
                        g_lastTriggerTime = now;
                        g_points.clear();
                        g_reversals = 0;
                        g_lastDirection = 0;

                        if (g_flutterWindow) {
                            g_flutterWindow->OnShakeDetected((double)x, (double)y);
                        }
                    }
                }
            }
        }
    }
    return CallNextHookEx(g_mouseHook, nCode, wParam, lParam);
}

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {
    g_flutterWindow = this;
}

FlutterWindow::~FlutterWindow() {
    StopMouseHook();
    g_flutterWindow = nullptr;
}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  SetupChannels();

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  flutter_controller_->ForceRedraw();
  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }
  Win32Window::OnDestroy();
}

LRESULT FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::StartMouseHook(int sensitivity) {
    g_sensitivity = sensitivity;
    if (g_mouseHook == NULL) {
        g_mouseHook = SetWindowsHookEx(WH_MOUSE_LL, MouseHookCallback, GetModuleHandle(NULL), 0);
    }
}

void FlutterWindow::StopMouseHook() {
    if (g_mouseHook != NULL) {
        UnhookWindowsHookEx(g_mouseHook);
        g_mouseHook = NULL;
    }
}

void FlutterWindow::OnShakeDetected(double x, double y) {
    if (mouse_hook_channel_) {
        flutter::EncodableMap args = {
            {flutter::EncodableValue("x"), flutter::EncodableValue(x)},
            {flutter::EncodableValue("y"), flutter::EncodableValue(y)}
        };
        mouse_hook_channel_->InvokeMethod("onShakeDetected",
                                          std::make_unique<flutter::EncodableValue>(args));
    }
}

void FlutterWindow::SetupChannels() {
    flutter::BinaryMessenger* messenger = flutter_controller_->engine()->messenger();

    mouse_hook_channel_ =
        std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            messenger, "magisor/mouse_hook",
            &flutter::StandardMethodCodec::GetInstance());

    mouse_hook_channel_->SetMethodCallHandler(
        [this](const flutter::MethodCall<flutter::EncodableValue>& call,
               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
            if (call.method_name() == "startListening") {
                int sensitivity = 1;
                const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
                if (args) {
                    auto it = args->find(flutter::EncodableValue("sensitivity"));
                    if (it != args->end() && std::holds_alternative<int>(it->second)) {
                        sensitivity = std::get<int>(it->second);
                    }
                }
                this->StartMouseHook(sensitivity);
                result->Success();
            } else if (call.method_name() == "stopListening") {
                this->StopMouseHook();
                result->Success();
            } else if (call.method_name() == "updateSensitivity") {
                const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
                if (args) {
                    auto it = args->find(flutter::EncodableValue("sensitivity"));
                    if (it != args->end() && std::holds_alternative<int>(it->second)) {
                        g_sensitivity = std::get<int>(it->second);
                    }
                }
                result->Success();
            } else {
                result->NotImplemented();
            }
        });

    capture_channel_ =
        std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            messenger, "magisor/capture",
            &flutter::StandardMethodCodec::GetInstance());

    capture_channel_->SetMethodCallHandler(
        [](const flutter::MethodCall<flutter::EncodableValue>& call,
           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
            if (call.method_name() == "captureRegion") {
                int x = 0, y = 0, width = 0, height = 0;
                const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
                if (args) {
                    auto parse_arg = [&](const char* key, int& val) {
                        auto it = args->find(flutter::EncodableValue(key));
                        if (it != args->end()) {
                            if (std::holds_alternative<int>(it->second)) {
                                val = std::get<int>(it->second);
                            } else if (std::holds_alternative<double>(it->second)) {
                                val = (int)std::get<double>(it->second);
                            }
                        }
                    };
                    parse_arg("x", x);
                    parse_arg("y", y);
                    parse_arg("width", width);
                    parse_arg("height", height);
                }

                HDC hScreenDC = GetDC(NULL);
                HDC hMemoryDC = CreateCompatibleDC(hScreenDC);
                HBITMAP hBitmap = CreateCompatibleBitmap(hScreenDC, width, height);
                HBITMAP hOldBitmap = (HBITMAP)SelectObject(hMemoryDC, hBitmap);
                
                BitBlt(hMemoryDC, 0, 0, width, height, hScreenDC, x, y, SRCCOPY);
                
                BITMAPINFO bmpInfo = {0};
                bmpInfo.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
                bmpInfo.bmiHeader.biWidth = width;
                bmpInfo.bmiHeader.biHeight = -height; 
                bmpInfo.bmiHeader.biPlanes = 1;
                bmpInfo.bmiHeader.biBitCount = 32;
                bmpInfo.bmiHeader.biCompression = BI_RGB;

                int dataSize = width * height * 4;
                std::vector<uint8_t> buffer(dataSize);
                GetDIBits(hScreenDC, hBitmap, 0, height, buffer.data(), &bmpInfo, DIB_RGB_COLORS);

                SelectObject(hMemoryDC, hOldBitmap);
                DeleteObject(hBitmap);
                DeleteDC(hMemoryDC);
                ReleaseDC(NULL, hScreenDC);

                result->Success(flutter::EncodableValue(buffer));
            } else if (call.method_name() == "captureFullScreen") {
                result->Success();
            } else {
                result->NotImplemented();
            }
        });
}
