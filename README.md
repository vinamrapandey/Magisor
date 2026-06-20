# Magisor 🪄

[![Platform](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-blue.svg)](https://www.microsoft.com/windows)
[![UI](https://img.shields.io/badge/UI-Flutter-02569B.svg)](https://flutter.dev/)
[![AI](https://img.shields.io/badge/AI-Gemini%20%7C%20Claude%20%7C%20Groq-orange.svg)](#-api-keys)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

Magisor is an invisible, AI‑powered companion for your desktop. It lives in the system tray and is summoned with a flick of the mouse — **shake the cursor** and a glassmorphic radial menu wraps around it, ready to summarize, explain, translate, or answer *"What's on my screen?"* using the AI provider of your choice.

> **Note:** Magisor is mid‑migration from an original Python/PyQt5 prototype (still present in the repo root, now **legacy**) to a Flutter + native C++ desktop app under [`magisor_flutter/`](magisor_flutter). **The Flutter app is the live product** — build and run from that folder.

---

## ✨ Features

- **Shake to summon** — a native low‑level Win32 mouse hook detects a deliberate shake while filtering out normal movement. Sensitivity is adjustable and persisted.
- **Glassmorphic radial menu** at the cursor — Summarize, Explain, Translate, Copy Text, and a free‑form **Ask**.
- **"What's on my screen?"** — type any question; Magisor captures the screen and answers with a vision model.
- **Multi‑provider AI** — Google **Gemini**, Anthropic **Claude**, and **Groq**. Switch providers, pick the **model per provider**, and verify keys in‑app.
- **Local history & saved items** — every result is stored locally (SQLite). Browse, star, copy, open links, and view full details; clear history while keeping starred items.
- **DPI‑ and multi‑monitor‑aware** screen capture.
- **System tray** integration and a **launch‑at‑Windows‑startup** toggle.
- **Local‑first & private** — API keys live in the OS secure store; history is a local SQLite file. Firebase (accounts / cloud sync) is **optional and off by default**.

---

## 🏗️ Architecture

Flutter renders the entire UI in Dart. A thin native C++ layer in the Windows runner handles the two things Flutter can't do alone — a **global mouse hook** and **fast screen capture** — exposed to Dart over MethodChannels.

```
Mouse shake ──(C++ WH_MOUSE_LL hook)──▶ magisor/mouse_hook ──▶ ShakeDetectorService
                                                                      │
                                                          Radial menu / Ask bar
                                                                      │
Screen capture ◀──(C++ BitBlt)── magisor/capture ◀──────── CaptureService
                                                                      │
                                                  AI provider (Gemini / Claude / Groq)
                                                                      │
                                            Result overlay  +  local SQLite history
```

| Layer | Tech |
| :--- | :--- |
| UI / state | Flutter, `provider` |
| Native bridge | C++ in `windows/runner/` — mouse hook, screen capture, startup registry — via channels `magisor/mouse_hook`, `magisor/capture`, `magisor/system` |
| AI | Direct HTTP to Gemini, Claude (Anthropic Messages API), Groq (OpenAI‑compatible) |
| Storage | `sqflite_common_ffi` (history), `flutter_secure_storage` (keys/prefs), `path_provider` |
| Shell | `window_manager`, `tray_manager` |
| Optional | Firebase (auth + Firestore sync) — requires your own config |

---

## 🚀 Getting started (development)

**Prerequisites**

- Flutter SDK (3.x) and Dart 3.x
- Visual Studio 2022 with the **Desktop development with C++** workload (needed to build the Windows runner)

**Run**

```bash
git clone https://github.com/vinamrapandey/Magisor.git
cd Magisor/magisor_flutter
flutter pub get
flutter run -d windows
```

On first run: open **Settings → Manage API Keys**, paste a key for at least one provider, and click **Save Key & Verify**. Choose the **active provider** and its **model**. Then **shake your mouse** to summon the menu — or, in debug builds, click **Test Overlay** in the dashboard to open it without shaking.

While `flutter run` is attached: press `r` to hot‑reload (Dart/UI), `R` to hot‑restart, `q` to quit. Native C++ changes require a full `flutter run` (they aren't hot‑reloaded).

---

## 📦 Build & package

```bash
cd magisor_flutter
flutter build windows          # -> build/windows/x64/runner/Release/
```

A standalone installer can be produced from the NSIS script (`magisor_flutter/flutter_installer.nsi`).

---

## 🔑 API keys

Bring your own key for whichever provider(s) you want:

- **Gemini** — Google AI Studio
- **Claude** — Anthropic Console
- **Groq** — Groq Console

Keys are stored locally via `flutter_secure_storage` (Windows Credential store). No telemetry.

---

## 📂 Project layout

```
Magisor/
├── magisor_flutter/            # The live Flutter + native C++ app
│   ├── lib/
│   │   ├── core/               # models, services, AI providers
│   │   └── ui/                 # screens, widgets, theme
│   └── windows/runner/         # native C++ (mouse hook, capture, startup)
├── magisor_project_roadmap.md  # full product vision & roadmap
└── (legacy Python prototype)   # superseded by magisor_flutter/
```

---

## 🗺️ Roadmap

See [magisor_project_roadmap.md](magisor_project_roadmap.md) for the full vision. Near‑term highlights: Circle‑to‑Search, universal OCR, cloud sync, and **macOS + mobile** apps.

---

## 📄 License

Licensed under the MIT License — see [LICENSE](LICENSE).
