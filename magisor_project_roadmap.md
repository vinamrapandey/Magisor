# Magisor Platform: Master Vision & Architecture Document

This master document serves as the single source of truth for the Magisor platform. It outlines the original concept, details what has been built so far, highlights ongoing technical challenges, and defines the ambitious roadmap for both Desktop and Mobile ecosystems.

---

## 1. The Original Idea & Platform Vision

**The Concept:** Magisor is envisioned as an omnipresent, invisible AI companion that resides continuously on your devices (Desktop and Mobile). It acts as an intelligent layer between you and your operating system.

**The "Magic" Interaction:** Instead of opening a standalone application or typing into a designated chat window, users invoke Magisor via natural, intuitive, and frictionless physical gestures—specifically, shaking the mouse cursor on Desktop or physically shaking the device on Mobile. 

**The Experience:** Upon invocation, a sleek, glassmorphic "Pie Menu" instantly wraps around the cursor or finger. From this menu, users can execute powerful AI actions (summarization, translation, contextual analysis) instantly at the point of need. The goal is to make AI assistance feel like a seamless extension of the operating system.

---

## 2. Current Implementation (What it's already doing)

Magisor currently utilizes a hybrid architecture, combining a robust Python backend with a fluid Flutter frontend.

- **Hybrid Architecture:** 
  - **Python Backend:** Handles low-level OS interactions, global input hooking, and AI API routing.
  - **Flutter Frontend:** Renders the dynamic, cross-platform UI.
- **Global Gesture Detection:** Implemented a custom C++ global mouse hook (`WH_MOUSE_LL`), wrapped via `ctypes` in Python. It uses an anchor-based directional sweep algorithm to detect rapid "shake" motions, mathematically filtering out normal mouse movements.
- **Glassmorphism Pie Menu:** A beautiful, dynamic UI built in Flutter using `ClipPath` and `BackdropFilter`. The circular pie menu is icon-driven (no text by default). Icons expand and display text labels smoothly upon hover.
- **Dynamic Positioning:** The Pie Menu intelligently calculates its position. By default, it spawns on the right of the cursor, but if there isn't enough screen space, it dynamically wraps to the left, top, or bottom.
- **System Tray Integration:** Magisor operates silently in the background. Using `window_manager` and `tray_manager`, it bypasses the standard taskbar, running as a true system-level overlay accessible via the System Tray.
- **API Configuration & Settings:** A `ProviderSetupScreen` allows users to configure their own API keys for various models, adjust shake sensitivity, and manage platform preferences.

---

## 3. Known Issues & Unresolved Challenges

- **Shake Detection Consistency:** While the algorithm has been drastically improved from standard tick-checks, the C++ `WH_MOUSE_LL` hook can still occasionally miss events or trigger false positives due to varying hardware polling rates (e.g., 1000Hz gaming mice) or conflicts with other system-level software.
- **End-to-End API Execution:** The UI and the backend exist, but the seamless pipeline of capturing the screen context -> passing it to Python -> routing to the LLM -> returning formatted results to the Flutter UI requires further polishing to ensure zero latency and silent failures.
- **Multi-Monitor Edge Cases:** Occasionally, pie menu icon positioning may behave unexpectedly when the cursor is at the extreme boundaries of multi-monitor setups with differing DPI scaling.

---

## 4. Planned Desktop Features

This outlines the immediate development targets for the Desktop application to realize the full vision:

- **"What's going on my screen?":** The app will continuously operate as a transparent overlay. When asked, Magisor will use Vision-capable AI models to analyze the current visual state of the desktop and answer contextual questions about the user's active workflow.
- **"Circle to Search" Functionality:** Inspired by modern smartphone features, users will be able to draw a circle or drag a bounding box anywhere on their screen. Magisor will instantly identify, search, or explain the highlighted region.
- **Universal Text Selection (OCR):** The ability to select, copy, translate, or summarize text from *anywhere*—including images, protected PDFs, videos, and unselectable UI elements.
- **Action History & Persistent Logs:** 
  - A built-in database will store every action taken (translations, summaries, OCR grabs).
  - Users will have access to a continuous "Chat History," allowing them to revisit previous AI conversations and context seamlessly.
- **Dynamic Multi-Model Support:** Users will be able to connect and hot-swap between multiple AI providers (OpenAI, Gemini, Claude) via their APIs, or even route specific tasks to local, privacy-focused models (like Ollama).

---

## 5. Planned Mobile Features (iOS & Android)

The Mobile application will translate the omnipresent desktop experience to smartphones.

- **Mobile Omnipresence:** Utilizing Android Accessibility Services and iOS Screen Broadcast/Action Extensions to allow the AI to "see" the mobile screen content securely.
- **Physical Shake Invocation:** Triggering the Magisor overlay by physically shaking the smartphone, replacing the mouse-shake gesture.
- **On-the-Go Context & OCR:** Bringing the "Circle to Search" and universal text selection features to touch interfaces.
- **Cross-Device Synchronization:** Cloud-syncing Action History, Chat Logs, and API configurations so a task started on the Desktop can be seamlessly continued on Mobile.

---

## 6. Strategic Open Questions & Suggestions (For User Review)

To refine the roadmap, consider the following design and strategy questions:

> [!NOTE]
> **Design & Interactions**
> 1. Should the "Circle to Search" feature pause/freeze the screen while you draw, or should the screen remain live (e.g., if drawing over a playing video)?
> 2. Where should the Action History live? Should it be a slide-out side panel, a dedicated full-screen "Hub", or integrated into the Pie Menu as a specific node?

> [!TIP]
> **AI Models & Privacy**
> 3. How heavily should we prioritize Local LLM support (running models entirely on your hardware) versus relying strictly on cloud APIs like Gemini/OpenAI?
> 4. For the "What's going on my screen" feature, should Magisor maintain a rolling buffer (like a dashcam saving the last 30 seconds), or only take a static screenshot at the exact moment of invocation?

> [!IMPORTANT]
> **Mobile Considerations & Constraints**
> 5. iOS has very strict limitations on drawing permanent overlays over other apps. Would you accept using an "Action Extension" (sharing screenshots to the app via the share sheet) as a workaround on Apple devices?
> 6. On Android, should Magisor be configured to start automatically in the background every time the phone boots up?
