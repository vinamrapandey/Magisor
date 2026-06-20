#include "flutter_window.h"

#include <optional>
#include <flutter/generated_plugin_registrant.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <iostream>
#include <vector>
#include <chrono>
#include <cmath>
#include <string>

static HHOOK g_mouseHook = NULL;
static FlutterWindow* g_flutterWindow = nullptr;
static int g_sensitivity = 1; // 0=low, 1=medium, 2=high

static int g_anchorX = -1;
static int g_lastDirection = 0;
static int g_reversals = 0;
static long long g_lastTriggerTime = 0;
static long long g_lastEventTime = 0;

static long long GetTimeMs() {
    return std::chrono::duration_cast<std::chrono::milliseconds>(
               std::chrono::steady_clock::now().time_since_epoch())
        .count();
}

static LRESULT CALLBACK MouseHookCallback(int nCode, WPARAM wParam, LPARAM lParam) {
    if (nCode >= 0 && wParam == WM_MOUSEMOVE) {
        MSLLHOOKSTRUCT* hookStruct = (MSLLHOOKSTRUCT*)lParam;
        int x = hookStruct->pt.x;
        long long now = GetTimeMs();

        if (g_lastTriggerTime != 0 && (now - g_lastTriggerTime) < 1500) {
            // Cooldown period
            g_anchorX = -1;
            g_reversals = 0;
        } else {
            // Reset if no significant movement for 300ms
            if (now - g_lastEventTime > 300) {
                g_anchorX = x;
                g_reversals = 0;
                g_lastDirection = 0;
            }
            g_lastEventTime = now;

            if (g_anchorX == -1) {
                g_anchorX = x;
            } else {
                int dx = x - g_anchorX;
                
                int minDistance = 50; 
                if (g_sensitivity == 0) minDistance = 100;
                else if (g_sensitivity == 2) minDistance = 25;

                if (std::abs(dx) > minDistance) {
                    int newDirection = dx > 0 ? 1 : -1;
                    
                    if (g_lastDirection != 0 && newDirection != g_lastDirection) {
                        g_reversals++;
                    } else if (g_lastDirection == 0) {
                        g_reversals = 1;
                    }
                    
                    g_lastDirection = newDirection;
                    g_anchorX = x; // Reset anchor

                    int requiredReversals = 4;
                    if (g_sensitivity == 0) requiredReversals = 5;
                    else if (g_sensitivity == 2) requiredReversals = 3;

                    if (g_reversals >= requiredReversals) {
                        g_lastTriggerTime = now;
                        g_reversals = 0;
                        g_lastDirection = 0;
                        g_anchorX = -1;

                        if (g_flutterWindow) {
                            g_flutterWindow->OnShakeDetected((double)x, (double)hookStruct->pt.y);
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
            } else if (call.method_name() == "getVirtualScreenRect") {
                // Physical-pixel bounds of the whole virtual desktop (all
                // monitors). Per-Monitor-V2 DPI aware, so these are real pixels.
                int vx = GetSystemMetrics(SM_XVIRTUALSCREEN);
                int vy = GetSystemMetrics(SM_YVIRTUALSCREEN);
                int vw = GetSystemMetrics(SM_CXVIRTUALSCREEN);
                int vh = GetSystemMetrics(SM_CYVIRTUALSCREEN);
                flutter::EncodableMap rect = {
                    {flutter::EncodableValue("x"), flutter::EncodableValue(vx)},
                    {flutter::EncodableValue("y"), flutter::EncodableValue(vy)},
                    {flutter::EncodableValue("width"), flutter::EncodableValue(vw)},
                    {flutter::EncodableValue("height"), flutter::EncodableValue(vh)},
                };
                result->Success(flutter::EncodableValue(rect));
            } else if (call.method_name() == "getPrimaryScreenRect") {
                int pw = GetSystemMetrics(SM_CXSCREEN);
                int ph = GetSystemMetrics(SM_CYSCREEN);
                flutter::EncodableMap rect = {
                    {flutter::EncodableValue("x"), flutter::EncodableValue(0)},
                    {flutter::EncodableValue("y"), flutter::EncodableValue(0)},
                    {flutter::EncodableValue("width"), flutter::EncodableValue(pw)},
                    {flutter::EncodableValue("height"), flutter::EncodableValue(ph)},
                };
                result->Success(flutter::EncodableValue(rect));
            } else {
                result->NotImplemented();
            }
        });

    system_channel_ =
        std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            messenger, "magisor/system",
            &flutter::StandardMethodCodec::GetInstance());

    system_channel_->SetMethodCallHandler(
        [](const flutter::MethodCall<flutter::EncodableValue>& call,
           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
            const wchar_t* runKey = L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
            const wchar_t* valueName = L"Magisor";

            if (call.method_name() == "setLaunchAtStartup") {
                bool enabled = false;
                const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
                if (args) {
                    auto it = args->find(flutter::EncodableValue("enabled"));
                    if (it != args->end() && std::holds_alternative<bool>(it->second)) {
                        enabled = std::get<bool>(it->second);
                    }
                }
                HKEY hKey;
                if (RegOpenKeyExW(HKEY_CURRENT_USER, runKey, 0, KEY_SET_VALUE, &hKey) == ERROR_SUCCESS) {
                    if (enabled) {
                        wchar_t exePath[MAX_PATH];
                        DWORD len = GetModuleFileNameW(NULL, exePath, MAX_PATH);
                        std::wstring quoted = L"\"" + std::wstring(exePath, len) + L"\"";
                        RegSetValueExW(hKey, valueName, 0, REG_SZ,
                                       reinterpret_cast<const BYTE*>(quoted.c_str()),
                                       (DWORD)((quoted.size() + 1) * sizeof(wchar_t)));
                    } else {
                        RegDeleteValueW(hKey, valueName);
                    }
                    RegCloseKey(hKey);
                    result->Success(flutter::EncodableValue(enabled));
                } else {
                    result->Error("registry_error", "Could not open Run registry key");
                }
            } else if (call.method_name() == "isLaunchAtStartup") {
                HKEY hKey;
                bool exists = false;
                if (RegOpenKeyExW(HKEY_CURRENT_USER, runKey, 0, KEY_QUERY_VALUE, &hKey) == ERROR_SUCCESS) {
                    if (RegQueryValueExW(hKey, valueName, NULL, NULL, NULL, NULL) == ERROR_SUCCESS) {
                        exists = true;
                    }
                    RegCloseKey(hKey);
                }
                result->Success(flutter::EncodableValue(exists));
            } else {
                result->NotImplemented();
            }
        });
}
