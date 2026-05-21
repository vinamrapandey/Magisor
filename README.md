# Magisor 🪄

Magisor is an AI-powered cursor overlay tool for Windows. It runs silently in the system tray, monitors mouse gestures, and displays a beautiful, transparent, glassmorphic context overlay near your cursor when you "shake" your mouse or activate it via voice/hotkeys. 

Behind the scenes, it captures a screen region centered around your cursor, queries a Windows UI Automation reader to understand the active text/context under the pointer, and passes this multimodal context to Google's Gemini Vision API. The overlay allows you to ask follow-up questions, run smart actions (like copying text or opening links), and interact seamlessly with any app on your system.

---

## 🚀 Key Features
1. **Global Shake Gesture Detection:** Rapidly shake the cursor to summon the overlay.
2. **Multimodal AI Context:** Combines dynamic screen capture with text extracted via Windows UI Automation.
3. **Gemini Vision Engine:** Custom, rich-structured analysis powered by Gemini 1.5/2.0 models.
4. **Premium Overlay UI:** Fluid, beautiful PyQt5 borderless UI with typing/voice follow-up.
5. **Smart Desktop Actions:** Instantly copy parsed text, open parsed web links, and trigger system actions.
6. **Privacy First:** User-supplied API keys stored strictly locally in `settings.json` (never hardcoded, never committed).

---

## 🛠️ Tech Stack
- **Language:** Python 3.10+
- **Mouse hooking:** `pynput` / `pywin32`
- **Visual Capture:** `mss` (multi-monitor fast screen grabs)
- **UI Framework:** `PyQt5`
- **A11y Text Extraction:** `pywinauto` (UI Automation framework)
- **Settings & Config:** `python-dotenv` & JSON config manager
- **AI Integration:** `google-generativeai`

---

## ⚙️ How to Get a Gemini Vision API Key

To run Magisor, you need your own Google Gemini API Key. The app is designed to run entirely locally, meaning your key is stored strictly on your local machine and queries are sent directly to Google's API servers.

### Steps to get your API Key:
1. Go to the [Google AI Studio Console](https://aistudio.google.com/).
2. Log in using your Google Account.
3. Click **"Get API key"** in the top-left sidebar.
4. Click **"Create API key"**. You can choose to associate it with a Google Cloud project (free tier is available).
5. Copy the generated API key (it begins with `AIzaSy...`).
6. Paste this key into Magisor's onboarding wizard upon first launch, or update it later via the **Settings** menu in the system tray.

---

## 📦 Project Structure
```text
/magisor
  ├── main.py              # Application entry point
  ├── mouse_hook.py        # Shake detection and hook engine
  ├── capture.py           # Bounding-box screen grab manager
  ├── ai_client.py         # Google Gemini Vision client wrapper
  ├── overlay.py           # Frameless PyQt5 context overlay window
  ├── onboarding.py        # First-launch configuration wizard
  ├── tray.py              # System tray wrapper
  ├── voice.py             # Voice triggers / speech recognition stub
  ├── context_reader.py    # UI Automation text reader
  ├── actions.py           # System copy/open action executor
  ├── config.py            # Local JSON settings serializer
  ├── env_manager.py       # .env validator and parser
  ├── requirements.txt     # Python requirements file
  ├── .gitignore           # Version control ignores
  ├── .env.example         # Template for optional system env parameters
  └── assets/              # Interface graphics, icons, and spinner GIFs
```

---

## 🔧 Installation & Local Setup

1. **Clone the repository & enter workspace:**
   ```bash
   cd magisor
   ```

2. **Create and activate a virtual environment:**
   ```bash
   python -m venv venv
   venv\Scripts\activate
   ```

3. **Install the dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

4. **Run the App:**
   ```bash
   python main.py
   ```
