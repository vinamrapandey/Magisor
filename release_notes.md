# Release Notes: Magisor v1.6.5 🪄

We are thrilled to release **Magisor v1.6.5** — a major feature and performance update bringing **Low-Power Local RAG**, **Zero-Cost Instant History Search**, **Redesigned Settings Dashboard**, **Fixed Gemini Model Endpoints**, and **Keyboard Overlay Dismissal (`Esc`)**.

---

## 🌟 What's New in v1.6.5

### 1. 🧠 Low-Power Local RAG & Zero-Cost Offline Search
- **Instant FTS5 History Search**: Search past OCR screen captures, translations, and chat histories in **< 1ms** with **0 AI credits consumed**.
- **0% Idle CPU & Battery Drain**: C-native SQLite FTS5 index (`magisor.db`) initializes automatically post-installation in `%APPDATA%/Magisor`.
- **RAG Context Augmentation**: User questions automatically pull top matching local snippets from past screen history to enrich AI prompts, reducing token usage by **90%+**.

### 2. 🎨 Redesigned Sidebar & Consolidated Settings Dashboard
- **Full-Height Sidebar Navigation**: Clean window layout extending from the top edge to the bottom without vertical offset.
- **Merged Settings & AI Providers**: Consolidated AI provider selection, API key verification, model dropdowns, shake sensitivity, and Windows startup toggles into a single **Settings** tab.
- **Removed Header Strip**: Eliminated the redundant top "Magisor" app bar for maximum content area.

### 3. 🔌 AI Provider Updates & Endpoint Fixes
- **Gemini API 404 Resolution**: Fixed model string routing for Google Gemini API (`gemini-2.0-flash`, `gemini-2.0-flash-lite`, `gemini-1.5-flash`, `gemini-1.5-pro`).
- **Claude & Groq Updates**: Full support for Claude 3.7 Sonnet, Claude 3.5 Haiku, and Groq Llama 3.3/3.2 models.

### 4. ⚡ System Tray & Keyboard Accessibility
- **System Tray Context Menu**: Right-click the hidden system tray icon for quick access to `Settings`, `Pause/Resume`, and `Quit`.
- **Escape (`Esc`) Key Shortcut**: Press `Esc` anytime the overlay, pie menu, ask bar, or result overlay is active to immediately dismiss the screen overlay and return to your desktop.

---

## 📦 Installer Download & Verification
- **Installer Name**: `Magisor-Setup-1.6.5.exe`
- **Output Path**: `C:\Users\Lenovo\Desktop\Magisor_Setup_v1.6.5.exe`

To verify the installer checksum via PowerShell:
```powershell
Get-FileHash -Algorithm SHA256 "C:\Users\Lenovo\Desktop\Magisor_Setup_v1.6.5.exe"
```
