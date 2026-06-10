# Magisor — Full Revamp Plan + Antigravity Prompts

---

## Current Codebase Assessment

### What is Complete and Working
- `mouse_hook.py` — shake detection algorithm is solid. 3+ reversals in 400ms window, configurable sensitivity, 1.5s cooldown. This logic gets ported to Dart.
- `capture.py` — screen capture with mss, boundary clamping, base64 output. Replace with Flutter platform channels.
- `ai_client.py` — Gemini integration works. Model name bug fixed (now reads from env). Prompt engineering is good. Needs multi-provider expansion.
- `onboarding.py` — 3-step wizard, key verification, works. Needs auth layer added.
- `tray.py` — system tray + settings dialog, complete. Desktop only, stays.
- `config.py` + `env_manager.py` — clean, secure, no hardcoded keys. Port to flutter_secure_storage + flutter_dotenv.
- `Magisor.spec` + `magisor_installer.nsi` — packaging ready. Replace with flutter build commands.

### What is Stubbed and Not Built
- `context_reader.py` — empty, pywinauto never implemented
- `voice.py` — empty start/stop, no audio logic
- `actions.py` — copy, open URL, all pass statements

### What Needs Redesign
- `overlay.py` — works but shows direct AI result. No radial menu, no feature selection, no auth awareness, no multi-provider.
- `onboarding.py` — no login/signup/Google auth, only API key setup.
- `ai_client.py` — Gemini only. Needs abstract provider pattern.

---

## Revamp Decision

**Full Flutter rewrite.** The Python/PyQt5 version is the validated prototype. The Flutter version is the production app.

### What gets ported (logic only, rewritten in Dart)
- Shake detection algorithm from `mouse_hook.py`
- Gemini prompt engineering from `ai_client.py`
- Config schema from `config.py`
- .env pattern from `env_manager.py`
- Onboarding flow concept from `onboarding.py`

### What gets discarded
- PyQt5 UI code
- mss screen capture
- pynput mouse listener
- python-dotenv
- PyInstaller + NSIS

### What gets added
- Flutter framework (all 4 platforms)
- Radial glassmorphic pie menu
- Firebase Authentication (email, Google, guest)
- Multi-AI provider system (Gemini, Claude, OpenAI, Groq)
- Platform-native OCR (ML Kit, Apple Vision, Windows OCR)
- Firestore + SQLite for saved items and history
- flutter_secure_storage for encrypted API key storage
- Proper platform channels for mouse hook, screen capture, OCR

---

## New Architecture

```
Flutter App (Dart)
├── Platform Layer (platform channels)
│   ├── Windows: Win32 mouse hook + Graphics.Capture + Windows.Media.Ocr
│   ├── macOS: CGEvent tap + ScreenCaptureKit + Vision Framework
│   ├── Android: Accessibility Service + MediaProjection + ML Kit
│   └── iOS: Floating button + UIScreen snapshot + Vision Framework
│
├── Core Services
│   ├── ShakeDetectorService     (ported from mouse_hook.py)
│   ├── CaptureService           (platform channels)
│   ├── OcrService               (ML Kit + platform channels)
│   ├── AIProviderService        (abstract, swappable)
│   ├── AuthService              (Firebase)
│   ├── StorageService           (Firestore + SQLite)
│   └── EnvService               (flutter_dotenv)
│
├── AI Providers
│   ├── GeminiProvider
│   ├── ClaudeProvider
│   ├── OpenAIProvider
│   └── GroqProvider
│
└── UI Layer
    ├── RadialMenu               (pie menu, 8 action bubbles)
    ├── GlassOverlay             (result display, frosted glass)
    ├── Onboarding               (welcome + auth + provider setup)
    ├── HomeScreen               (tray/floating bubble entry)
    ├── SavedScreen              (saved captures)
    ├── HistoryScreen            (past AI sessions)
    └── SettingsScreen           (provider management, preferences)
```

---

## Radial Menu Actions

| Bubble | Feature | Powered By |
|---|---|---|
| Analyze | Full AI screen analysis | Active AI provider |
| Select Text | OCR extract to clipboard | Platform-native OCR |
| Screenshot | Capture + save to gallery | Platform native |
| Save | Save screen to collection | Firestore / SQLite |
| Translate | OCR + translate | AI provider |
| Explain | Plain language explanation | AI provider |
| Summarize | 3-bullet summary | AI provider |
| Ask | Free-text follow-up prompt | AI provider |

---

## Antigravity Prompts — Step by Step

---

### MASTER CONTEXT (Run first, every session)

```
/goal

I am building Magisor — a cross-platform AI-powered screen assistant for 
Windows, macOS, Android, and iOS.

I have an existing Python/PyQt5 Windows prototype. I am doing a full 
rewrite in Flutter. The prototype validated the concept. Flutter is the 
production version.

PRODUCT:
When the user shakes their mouse (desktop) or taps a floating bubble 
(mobile), a radial pie menu appears around the cursor with 8 circular 
glassmorphic action buttons. The user taps one to trigger that feature.

ACTIVATION:
- Desktop (Windows/macOS): global mouse hook detects shake gesture,
  radial menu appears at cursor position, always-on-top overlay
- Mobile (Android/iOS): persistent floating bubble button, tap to open,
  bottom sheet style overlay

RADIAL MENU ACTIONS (8 circular bubbles):
1. Analyze — screenshot sent to active AI provider for full analysis
2. Select Text — OCR extracts text from screen region to clipboard
3. Screenshot — capture and save using native platform API
4. Save — save current screen capture to user's collection
5. Translate — OCR + detect language + translate via AI
6. Explain — plain language "what is this?" explanation via AI
7. Summarize — 3-bullet summary of visible content via AI
8. Ask — opens text input to ask anything about the screen

UI DESIGN:
- Glassmorphic throughout: BackdropFilter blur, semi-transparent frosted panels
- Dark base (#0A0A0F), glass surfaces at 8-12% white opacity
- Blur sigma 20px, border-radius 20px cards, 50% for bubbles
- Primary accent: violet (#8B5CF6), secondary: cyan (#22D3EE)
- Radial menu fans out from cursor in 150ms with staggered animation
- Minimal — nothing visible until activated

AUTH:
- Firebase Authentication
- Email + password login/signup
- Google Sign-In (one tap)
- Continue as guest (Firebase anonymous auth)
- Guests get: Analyze, Select Text, Screenshot
- Logged-in users get: all 8 + Save history + cross-device sync

AI PROVIDERS (user supplies their own key, no key ever hardcoded):
- Gemini (gemini-2.0-flash) — default recommendation
- Claude (claude-sonnet-4-20250514)
- OpenAI (gpt-4o)
- Groq (llama-3.1-8b-instant)
All follow abstract AIProvider interface. Key stored in flutter_secure_storage.

OCR: Platform-native only (no API cost, offline)
- Android/iOS: google_mlkit_text_recognition
- Windows: Windows.Media.Ocr via platform channel
- macOS/iOS: Apple Vision Framework via platform channel

SECURITY:
- Zero API keys hardcoded anywhere
- All provider keys in flutter_secure_storage (encrypted on-device)
- .env for non-sensitive runtime config via flutter_dotenv
- .env never bundled in release builds

TECH STACK:
- Flutter (Dart)
- Firebase Auth + Firestore
- flutter_secure_storage, flutter_dotenv
- google_mlkit_text_recognition
- firebase_core, google_sign_in
- flutter_animate, http, sqflite

Do not build anything yet. Acknowledge and wait for step instructions.
```

---

### STEP 1 — Project Scaffold

```
/goal

Set up the complete Flutter project structure for Magisor.

Create this exact folder and file structure:

lib/
├── main.dart
├── app.dart                       (MaterialApp, theme, router)
├── core/
│   ├── providers/
│   │   ├── ai_provider.dart            (abstract class AIProvider)
│   │   ├── gemini_provider.dart
│   │   ├── claude_provider.dart
│   │   ├── openai_provider.dart
│   │   └── groq_provider.dart
│   ├── services/
│   │   ├── auth_service.dart           (Firebase auth wrapper)
│   │   ├── capture_service.dart        (platform screen capture)
│   │   ├── ocr_service.dart            (ML Kit + platform channels)
│   │   ├── shake_detector_service.dart (ported shake algorithm)
│   │   ├── storage_service.dart        (Firestore + SQLite)
│   │   └── env_service.dart            (flutter_dotenv wrapper)
│   └── models/
│       ├── magisor_response.dart       (summary, actions, text)
│       ├── saved_item.dart
│       └── user_settings.dart
├── ui/
│   ├── theme/
│   │   ├── glass_theme.dart
│   │   └── app_colors.dart
│   ├── widgets/
│   │   ├── radial_menu.dart            (the pie menu)
│   │   ├── action_bubble.dart          (one circle button)
│   │   ├── glass_card.dart             (reusable frosted card)
│   │   └── ai_result_overlay.dart      (result display panel)
│   └── screens/
│       ├── onboarding/
│       │   ├── welcome_screen.dart
│       │   ├── auth_screen.dart
│       │   └── provider_setup_screen.dart
│       ├── home_screen.dart
│       ├── saved_screen.dart
│       ├── history_screen.dart
│       └── settings/
│           ├── settings_screen.dart
│           └── provider_settings_screen.dart
android/
ios/
windows/
macos/
assets/
├── icons/
└── .env.example
pubspec.yaml
.env                                (gitignored)
.gitignore                          (must include .env)
README.md

RULES:
- Create stub files with class signatures and dartdoc comments
- No API keys anywhere, not even as empty strings in code
- pubspec.yaml must include all dependencies:
  firebase_core, firebase_auth, cloud_firestore, google_sign_in,
  flutter_secure_storage, google_mlkit_text_recognition,
  flutter_dotenv, http, sqflite, flutter_animate, provider or riverpod
- .env.example lists all env vars with placeholder values:
  GEMINI_MODEL=gemini-2.0-flash
  APP_ENV=development
```

---

### STEP 2 — Glass Design System

```
/goal

Build the glassmorphic design system for Magisor.

1. app_colors.dart — define all color constants:
   backgroundPrimary: Color(0xFF0A0A0F)
   glassSurface: Color(0x1AFFFFFF)       (white 10% opacity)
   glassBorder: Color(0x26FFFFFF)        (white 15% opacity)
   accentViolet: Color(0xFF8B5CF6)
   accentCyan: Color(0xFF22D3EE)
   textPrimary: Color(0xF2FFFFFF)
   textMuted: Color(0x80FFFFFF)
   errorRed: Color(0xFFF87171)
   successGreen: Color(0xFF4ADE80)

2. glass_theme.dart — ThemeData configured for dark glassmorphic look.
   Apply globally via app.dart.

3. glass_card.dart — reusable widget:
   - BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20))
   - Container with glassSurface fill and glassBorder border
   - borderRadius: BorderRadius.circular(20)
   - Accepts: child, width, height, padding, borderRadius (override)
   - Subtle white glow via BoxShadow

4. glass_button.dart — circular frosted glass button:
   - 64x64px circle (size configurable)
   - Same blur + glass treatment as glass_card
   - Icon (IconData) centered, label below in 10px text
   - On press: scale down to 0.95 via GestureDetector
   - Used for each bubble in the radial menu

Test by creating a simple scaffold in home_screen.dart showing 
a GlassCard with a GlassButton inside.
```

---

### STEP 3 — Auth System

```
/goal

Implement the complete auth system for Magisor.

auth_service.dart:
- signUpWithEmail(email, password) → Future<UserCredential>
- signInWithEmail(email, password) → Future<UserCredential>
- signInWithGoogle() → Future<UserCredential>
- signInAsGuest() → Future<UserCredential> (Firebase anonymous)
- signOut() → Future<void>
- Stream<User?> get authStateChanges
- bool get isGuest (true if currentUser.isAnonymous)
- bool get isLoggedIn
- Never log or expose credentials anywhere

welcome_screen.dart:
- Magisor logo (text, violet + cyan gradient on letters)
- Three GlassCard buttons stacked:
  "Continue with Google" (Google logo icon)
  "Email and Password"
  "Continue without account" (muted, smaller)
- Slow animated gradient blob background (flutter_animate)

auth_screen.dart:
- Toggling Login / Sign Up tabs
- Email + password fields inside a GlassCard
- Inline validation errors in errorRed
- "Back" returns to welcome_screen

provider_setup_screen.dart (shown once after first login):
- Heading: "Choose your AI"
- Horizontal scroll of 4 GlassCards (Gemini, Claude, OpenAI, Groq)
  Each shows: provider name, model name, "Free tier" badge if applicable
- On select: expand to show password field for API key
- "Get your free key" opens correct URL in browser
- "Verify Key" button — makes live lightweight API test call
- Green success / red error inline
- Save to flutter_secure_storage with key "magisor_{provider}_key"
- Guests see this screen with note: "Key saved locally only. Sign in to sync."
```

---

### STEP 4 — AI Provider System

```
/goal

Implement the complete AI provider system for Magisor.

1. MagisorResponse model (core/models/magisor_response.dart):
   - String summary
   - List<String> actions (max 3)
   - String extractedText
   - String providerUsed
   - factory MagisorResponse.fromJson(Map<String, dynamic> json)

2. Abstract AIProvider (core/providers/ai_provider.dart):
   abstract class AIProvider {
     String get providerName;
     String get modelId;
     bool get supportsVision;
     Future<MagisorResponse> analyzeScreen(String base64Image, String prompt);
     Future<MagisorResponse> analyzeText(String text, String prompt);
     Future<bool> verifyKey(String apiKey);
     Future<String?> loadKey();  // from flutter_secure_storage
   }
   
   System prompt (use in all providers):
   "You are Magisor, an AI screen assistant. The user activated you on 
   their screen. Be concise and actionable. Respond ONLY in JSON:
   { summary: string, actions: [string], extractedText: string }"

3. Implement all 4 providers:

GeminiProvider:
  endpoint: https://generativelanguage.googleapis.com/v1beta/models/{model}
  model: from env_service.get("GEMINI_MODEL") ?? "gemini-2.0-flash"
  auth: ?key={apiKey} query param
  
ClaudeProvider:
  endpoint: https://api.anthropic.com/v1/messages
  model: claude-sonnet-4-20250514
  headers: x-api-key, anthropic-version: 2023-06-01
  
OpenAIProvider:
  endpoint: https://api.openai.com/v1/chat/completions
  model: gpt-4o
  headers: Authorization: Bearer {apiKey}
  
GroqProvider:
  endpoint: https://api.groq.com/openai/v1/chat/completions
  model: llama-3.1-8b-instant (text) / llava-v1.5-7b-4096-preview (vision)
  headers: Authorization: Bearer {apiKey}

RULES:
- Load API key from flutter_secure_storage inside each provider
- Never accept key as constructor param or store in memory longer than needed
- Handle errors: 401 = bad key message, 429 = rate limit message, 
  503 = provider unavailable message
- No hardcoded keys anywhere
```

---

### STEP 5 — Shake Detection Service

```
/goal

Implement shake_detector_service.dart for Magisor desktop platforms.

PORT THIS ALGORITHM from the existing Python mouse_hook.py (translate to Dart):

The shake is: N or more horizontal direction reversals within 400ms,
where each segment covers at least minDist pixels.

Sensitivity levels (read from user settings):
- low:    5 reversals, 30px minimum distance
- medium: 3 reversals, 20px minimum distance  
- high:   2 reversals, 15px minimum distance

Cooldown: 1500ms after each trigger to prevent double-firing.

Implementation:
- Use a platform channel "magisor/mouse_hook" to receive raw (x,y) 
  mouse coordinates from native code on Windows and macOS
- Dart side implements the direction reversal detection and timing logic
- When shake detected: call onShakeDetected(Offset cursorPosition) callback
- ShakeDetectorService.start() begins listening
- ShakeDetectorService.stop() removes listener

Also create the native side stubs:
- Windows (C++/Win32): SetWindowsHookEx WH_MOUSE_LL, send x,y through channel
- macOS (Swift): CGEvent.tapCreate for mouseMoved events, send x,y through channel

Mobile: ShakeDetectorService.start() does nothing on Android/iOS 
(mobile uses the floating bubble tap instead — no shake needed)
```

---

### STEP 6 — Screen Capture + OCR Services

```
/goal

Implement capture_service.dart and ocr_service.dart for Magisor.

capture_service.dart:
Platform channel "magisor/capture"
- Future<Uint8List> captureRegion(Rect region)
- Future<Uint8List> captureFullScreen()

Native implementations:
- Windows: Windows.Graphics.Capture API
- macOS: ScreenCaptureKit (SCScreenshotManager)
- Android: MediaProjection API (requires foreground service)
- iOS: UIScreen.snapshotView(afterScreenUpdates: false)

Return: raw PNG bytes as Uint8List
Handle permission denied on each platform with a descriptive error message.
Helper: Uint8List toBase64Jpeg(Uint8List pngBytes) — converts to JPEG 
at 85% quality, returns base64 string for AI API.
Also: Rect regionAroundPoint(Offset center, Size screenSize) — 
returns a 600x400 Rect centered on the point, clamped to screen bounds.
(This is the same boundary clamping logic from capture.py — port it.)

ocr_service.dart:
- Future<String> extractText(Uint8List imageBytes)
- Android + iOS: google_mlkit_text_recognition
  TextRecognizer(script: TextRecognitionScript.latin)
  Process InputImage.fromBytes(imageBytes, ...)
  Return all recognized text blocks joined by newline
- Windows: platform channel "magisor/ocr"
  Dart: send bytes through channel
  C# native: Windows.Media.Ocr.OcrEngine.TryCreateFromUserProfileLanguages()
  Return recognized text string
- macOS: platform channel "magisor/ocr_apple"
  Swift native: VNRecognizeTextRequest with revision 2
  Return recognized text string
- Return empty string on failure, never throw
```

---

### STEP 7 — Radial Menu Widget

```
/goal

Build the radial pie menu in lib/ui/widgets/radial_menu.dart.
This is the most important UI component in Magisor.

DEFINITION:
enum RadialAction { analyze, selectText, screenshot, save, 
                    translate, explain, summarize, ask }

RadialMenuConfig per action:
- label: String
- icon: IconData
- availableForGuest: bool (analyze, selectText, screenshot = true; rest = false)

BEHAVIOR:
- Accepts: Offset position (cursor location), bool isGuest, 
  Function(RadialAction) onSelected, VoidCallback onDismiss
- 8 GlassButton bubbles arranged in a full circle, radius 110px from center
- Center dot: 12px glowing violet circle at cursor position
- Tapping a bubble: calls onSelected(action), menu closes
- Tapping outside: calls onDismiss, menu closes
- Guest + locked action: show lock icon overlay on bubble, 
  tapping shows "Sign in to unlock" snackbar

ANIMATION (use flutter_animate):
- Open: each bubble scales 0→1 and translates from center outward
  Staggered 15ms per bubble, 150ms total duration, ease-out curve
- Close: reverse, 100ms
- Each bubble has a subtle continuous pulse glow while menu is open

OVERLAY:
- Render using OverlayEntry so it sits above all app content
- Tap barrier (full screen transparent GestureDetector) handles outside taps

POSITIONING:
- Clamp the 110px radius so no bubble goes off-screen
- If cursor is within 110px of screen edge, shift center inward

LOCKED BUBBLES (guest users):
- Available actions: full opacity, tappable
- Locked actions: 40% opacity, lock icon in top-right corner of bubble
```

---

### STEP 8 — AI Result Overlay

```
/goal

Build ai_result_overlay.dart for Magisor.

This overlay appears after the user selects a radial menu action 
and the AI has responded (or is loading).

STATES:
1. Loading: spinner (CircularProgressIndicator in accentViolet) + "Asking Magisor..."
2. Success: show MagisorResponse content
3. Error: red message + optional "Open Settings" button

LAYOUT (inside a GlassCard, width 380px, auto-height):
- Top row: "MAGISOR" label (muted, 10px, letter-spaced) + X close button
- Summary text (white, 15px, word-wrapped)
- Action pills row (up to 3): each a small GlassButton with action label
  Tapping a pill copies the action text to clipboard and shows a toast
- Divider
- Follow-up row: TextField (glass-styled) + "Ask" send button
  On send: re-queries active AI provider with screenshot + follow-up prompt
  Updates overlay content with new response

BEHAVIOR:
- Positioned 20px down-right from cursor, clamped to screen
- Fade in 150ms on appear
- Dismiss on: X button click, Esc key, tap outside (changeEvent focus loss)
- If MissingAPIKeyError: show "No API key set" message + 
  "Open Settings" button that opens provider_settings_screen

For mobile: present as a DraggableScrollableSheet from bottom 
instead of a positioned overlay
```

---

### STEP 9 — Wire Everything in main.dart

```
/goal

Wire all Magisor services and screens together in main.dart and app.dart.

main.dart:
1. WidgetsFlutterBinding.ensureInitialized()
2. await Firebase.initializeApp()
3. await dotenv.load()
4. runApp(MagisorApp())

app.dart (MagisorApp):
- MultiProvider with: AuthService, AIProviderService, StorageService
- Router:
  / → check auth state:
    if no user → WelcomeScreen
    if user + no provider key → ProviderSetupScreen
    else → HomeScreen
  /auth → AuthScreen
  /settings → SettingsScreen
  /saved → SavedScreen
  /history → HistoryScreen

home_screen.dart:
Desktop:
  - Invisible window (system tray app)
  - ShakeDetectorService starts on init
  - On shake detected:
    1. captureService.captureRegion(regionAroundPoint(cursor, screen))
    2. Show RadialMenu at cursor position via OverlayEntry
    3. On action selected → execute action (see Step 10)

Mobile:
  - Floating action button (always visible, draggable)
  - Tap → Show RadialMenu
  - Bottom navigation: Saved | Home | History

System tray (desktop only):
  - "Magisor is running" (grey, disabled)
  - Settings → SettingsScreen
  - Quit → dispose all services, exit
  - First launch toast: "Magisor active — shake to activate"

Thread safety: all platform channel calls await on main isolate.
All AI calls run in a compute() isolate or Future.
```

---

### STEP 10 — Action Execution

```
/goal

Implement the action execution logic that runs when a RadialMenu 
bubble is tapped in Magisor.

Create lib/core/services/action_service.dart with executeAction(
  RadialAction action, 
  Offset cursorPosition,
  BuildContext context
)

ANALYZE:
  bytes = await captureService.captureRegion(regionAroundPoint(cursor))
  show AIResultOverlay with loading state
  result = await activeProvider.analyzeScreen(toBase64Jpeg(bytes), "Analyze what you see")
  update overlay with result

SELECT TEXT:
  bytes = await captureService.captureRegion(regionAroundPoint(cursor))
  text = await ocrService.extractText(bytes)
  Clipboard.setData(ClipboardData(text: text))
  show brief snackbar: "Text copied (${text.length} chars)"
  show AIResultOverlay with text content if non-empty

SCREENSHOT:
  bytes = await captureService.captureFullScreen()
  save to device gallery via image_gallery_saver package
  show snackbar: "Screenshot saved"

SAVE:
  bytes = await captureService.captureFullScreen()
  windowName = await platform.invokeMethod("getActiveWindowTitle")
  item = SavedItem(screenshot: bytes, appName: windowName, timestamp: now())
  await storageService.saveItem(item)  
  (Firestore if logged in, SQLite if guest)
  show snackbar: "Saved to your collection"

TRANSLATE:
  bytes = await captureService.captureRegion(regionAroundPoint(cursor))
  extractedText = await ocrService.extractText(bytes)
  lang = await userSettings.preferredLanguage
  result = await activeProvider.analyzeText(extractedText, 
    "Detect the language of this text and translate it to $lang")
  show AIResultOverlay with result

EXPLAIN:
  bytes = await captureService.captureRegion(regionAroundPoint(cursor))
  result = await activeProvider.analyzeScreen(toBase64Jpeg(bytes),
    "Explain what this is in plain, simple language. One paragraph.")
  show AIResultOverlay with result

SUMMARIZE:
  bytes = await captureService.captureRegion(regionAroundPoint(cursor))
  text = await ocrService.extractText(bytes)
  result = await activeProvider.analyzeText(text,
    "Summarize this in exactly 3 bullet points. Be concise.")
  show AIResultOverlay with result

ASK:
  bytes = await captureService.captureRegion(regionAroundPoint(cursor))
  show AIResultOverlay immediately with text input focused
  on user submit: 
    result = await activeProvider.analyzeScreen(toBase64Jpeg(bytes), userPrompt)
    update overlay
```

---

### STEP 11 — Saved, History, Settings Screens

```
/goal

Build the three supporting screens for Magisor.

saved_screen.dart:
- Masonry or 2-column grid of saved captures
- Each card: thumbnail, app name, timestamp, tap to view full
- Long press → delete with confirmation
- Pull to refresh
- Firestore source for logged-in users, SQLite for guests
- Guest banner: "Sign in to sync across all your devices"
- Empty state: ghost icon + "Nothing saved yet"

history_screen.dart:
- Chronological list of past AI analyses
- Each row: small thumbnail, summary (truncated 1 line), provider badge, time
- Tap to expand: full summary, actions, extracted text
- Search bar filtering by summary text
- Logged-in only: guests see locked empty state with sign-in prompt
- Cleared automatically after 30 days

settings_screen.dart:
Account section:
  - Avatar (initials if no photo), name, email
  - Guests: "Browsing as guest" + "Sign In" button
  - Logged in: "Sign Out" with confirmation dialog

AI Provider section:
  - Currently active provider (name + model)
  - "Change Provider" → provider_settings_screen.dart

provider_settings_screen.dart:
  - 4 GlassCards for each provider
  - Shows: name, model string, recommended badge (Gemini)
  - Tap to expand: masked key field (show first 4 + last 4)
  - "Verify" button per provider
  - "Set as Active" button
  - Keys shown masked, never logged

Preferences section:
  - Shake sensitivity: Low / Medium / High (SegmentedButton)
  - Preferred translation language (DropdownButton, 20 languages)
  - Voice activation toggle (reserved for future)
  - Desktop: Show/hide system tray toggle
```

---

### STEP 12 — Packaging

```
/goal

Set up build commands and packaging for all 4 Magisor platforms.

ANDROID:
flutter build apk --release
flutter build appbundle --release (for Play Store)
AndroidManifest.xml permissions:
  INTERNET, FOREGROUND_SERVICE, SYSTEM_ALERT_WINDOW,
  RECORD_AUDIO (future voice), BIND_ACCESSIBILITY_SERVICE (screen reading)
minSdkVersion: 24

iOS:
flutter build ipa
Info.plist entries:
  NSMicrophoneUsageDescription: "For voice activation"
  NSScreenCaptureDescription: "To analyze your screen"

WINDOWS:
flutter build windows --release
Create NSIS script Magisor_Setup_2.0.nsi:
  - Installs to C:/Program Files/Magisor
  - Start Menu shortcut
  - Optional Windows startup registry entry
  - Uninstaller
  - Post-install message: "Launch Magisor and sign in or set up your AI key"

MACOS:
flutter build macos --release
Entitlements:
  com.apple.security.screen-recording: true
  com.apple.security.network.client: true
Code sign with Apple Developer certificate

CRITICAL — what must NOT be in any build output:
- .env file (use flutter_dotenv with assets exclusion in release)
- Any API key anywhere in compiled code
- flutter_secure_storage contents are encrypted on-device, fine to ship
```

---

## Migration Checklist

Before starting Flutter build, preserve from Python prototype:

- [ ] Copy shake detection thresholds (reversals, min dist, cooldown values)
- [ ] Copy Gemini system prompt wording from ai_client.py
- [ ] Copy onboarding step flow concept from onboarding.py
- [ ] Copy config schema keys from config.py DEFAULT_SETTINGS
- [ ] Copy .env.example variable names from current .env.example
- [ ] Document the NSIS installer settings for reference in new script

## Suggested Build Order

1. Scaffold + design system (Steps 1-2) → verify glass UI renders
2. Auth (Step 3) → verify login/signup/guest flows
3. AI providers (Step 4) → verify each provider call works
4. Shake detection (Step 5) → verify on Windows first
5. Capture + OCR (Step 6) → verify screenshot + text extraction
6. Radial menu (Step 7) → verify animation and layout
7. Result overlay (Step 8) → verify AI response display
8. Wire together (Step 9) → full end-to-end flow
9. Actions (Step 10) → all 8 radial actions working
10. Supporting screens (Step 11) → saved, history, settings
11. Packaging (Step 12) → all 4 platform builds
