# Magisor 🪄

<div align="center">

![Magisor Banner](screenshots/00_hero_pie_menu.png)

**An invisible, AI-powered desktop overlay for Windows powered by Gemini, Claude, and Groq.**

[![Version](https://img.shields.io/badge/version-1.6.5-blue.svg)](pubspec.yaml)
[![Platform](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-blue.svg)](https://www.microsoft.com/windows)
[![UI](https://img.shields.io/badge/UI-Flutter%203-02569B.svg)](https://flutter.dev/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

</div>

---

## 📖 Overview

**Magisor** is a next-generation desktop AI assistant for Windows. It runs silently in your system tray and is summoned instantly with a natural mouse gesture — **shake your cursor**, and a sleek glassmorphic radial menu wraps around your pointer, ready to analyze, summarize, translate, extract text, or answer *"What's on my screen?"*.

Magisor features a **low-power Local RAG (Retrieval-Augmented Generation)** engine that indexes your past screen interactions and OCR text into an on-device SQLite database. You can search your history offline with **0 AI credit usage** and `< 1ms` speed.

---

## ✨ Features

- 🪄 **Shake to Summon**: Native Win32 mouse hook detects deliberate mouse shakes anywhere on Windows. Sensitivity is fully customizable and persisted.
- ⭕ **Circle to Search**: Draw a bounding region over any application, video, or document to extract context and ask AI follow-ups.
- 📝 **Universal Text Selector & OCR**: Select and copy text from any image, PDF, or video stream using Windows OCR / MLKit.
- ⚡ **Low-Power Local RAG**: Automatically indexes screen captures, user prompts, and summaries into a local C-native SQLite FTS5 database (`magisor.db`).
- 🔍 **Zero-Cost Offline Search**: Search your past interactions in `< 1ms` using BM25 ranking — consuming **0 API credits**.
- 🤖 **Multi-Provider AI Engine**: Switch seamlessly between Google **Gemini** (`gemini-2.0-flash`), Anthropic **Claude** (`claude-3.7-sonnet`), and **Groq** (`llama-3.3-70b`).
- ⌨️ **Keyboard Accessibility**: Press `Esc` at any time to immediately dismiss the screen overlay and return to your desktop.
- 📌 **System Tray & Windows Startup**: Hidden system tray menu with options for `Settings`, `Pause/Resume`, and `Quit`, plus single-click Windows auto-startup toggle.

---

## 🚀 Getting Started

### Installation (Pre-built Binary)

1. Download **`Magisor-Setup-1.6.5.exe`** from the [Releases](https://github.com/vinamrapandey/Magisor/releases) page.
2. Run the installer and follow the setup wizard.
3. Magisor will launch silently in your system tray. Right-click the tray icon 🪄 and choose **Settings** to add an API key for your preferred provider:
   - **Google Gemini**: Get a free API key at [Google AI Studio](https://aistudio.google.com/)
   - **Anthropic Claude**: [Anthropic Console](https://console.anthropic.com/)
   - **Groq**: [Groq Console](https://console.groq.com/)
4. Shake your mouse back and forth to open the radial pie menu!

---

## 🏗️ Architecture

Magisor combines a high-performance **Flutter 3** desktop UI with a C++ native runner layer on Windows:

| Layer | Technologies & Frameworks |
| :--- | :--- |
| **UI & State** | Flutter 3.12, Dart 3, `provider`, Glassmorphism CSS design system |
| **Native Runner** | Win32 C++ runner (`windows/runner/`), GDI BitBlt screen capture, global WH_MOUSE_LL hook |
| **Local RAG & DB** | SQLite FTS5, `sqflite_common_ffi`, BM25 relevance ranking |
| **AI Providers** | Google Gemini API (`v1beta`), Anthropic Messages API, Groq OpenAI-compatible API |
| **Security** | Windows Credential Store via `flutter_secure_storage` |

---

### Building from Source

**Prerequisites:**
- Flutter SDK 3.x
- Visual Studio 2022 with **Desktop development with C++** workload
- NSIS (optional, for installer creation)

```bash
# Clone the repository
git clone https://github.com/vinamrapandey/Magisor.git
cd Magisor/magisor_flutter

# Install dependencies
flutter pub get

# Run on Windows Desktop
flutter run -d windows

# Build standalone production executable
flutter build windows
```

To package into an installer:
```powershell
& 'C:\Program Files (x86)\NSIS\makensis.exe' flutter_installer.nsi
```


## 🔧 Environment Variables

Magisor supports optional `.env` configuration to override default AI model selections. Copy `.env.example` to `.env` in the project root:

| Variable | Default | Description |
| :--- | :--- | :--- |
| `GEMINI_MODEL` | `gemini-2.0-flash` | Google Gemini model used for screen analysis |
| `CLAUDE_MODEL` | `claude-sonnet-4-6` | Anthropic Claude model used for screen analysis |
| `GROQ_MODEL` | `llama-3.2-11b-vision-preview` | Groq model used for screen analysis |
| `MAGISOR_ENV` | `development` | Runtime environment (`development` / `production`) |
| `LOG_LEVEL` | `INFO` | Logging verbosity (`DEBUG`, `INFO`, `WARNING`, `ERROR`) |

> **Note**: API keys are stored securely in the Windows Credential Store via the in-app Settings UI — they are **not** set via `.env`.

---

## 📄 License

This project is open-source under the [MIT License](LICENSE).
