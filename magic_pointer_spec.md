# Magisor → "Magic Pointer for Windows" — Implementation Spec

A single source of truth for re-architecting Magisor into a system-level,
Magic-Pointer-style overlay. Feed this whole document to Claude Code as the
`/goal`, run at **effort: xhigh**, and implement **one phase at a time** —
verify (build + run) before starting the next phase. Do not restructure across
phases; each phase is additive on top of the previous.

---

## 1. Vision

Magisor is an invisible companion in the system tray. On a **mouse shake**, it
**freezes the current screen** as a fullscreen overlay and lets the user act on
that frozen content — **circle to search**, **select text** (from anywhere,
including images/video/PDFs), or **ask** about a region — then hands the visual
+ textual context to an AI. Inspired by Android Circle to Search and Google's
"Magic Pointer" (capture the visual + semantic context around the pointer).

Windows first; the architecture is OS-swappable behind method channels so macOS
/ Android / iOS can follow.

**Non-negotiable UX:** it must feel like a **system layer over the live
desktop**, never like a separate app window.

---

## 2. The core model: freeze-the-screenshot

On shake (Magisor has no visible window — it's in the tray — so the capture is
clean):

```
Shake ─▶ capture FULL virtual screen (physical px, DPI-correct, all monitors)
      ─▶ show that bitmap fullscreen in a frameless/transparent/always-on-top
         maximized overlay  ──  the screen now appears "frozen"
      ─▶ user interacts over the frozen image:
            • Radial menu (existing)         • Circle to Search (existing)
            • Text selection (NEW, via OCR)  • Ask (existing)
      ─▶ selection/region + extracted text  ─▶ AI  ─▶ result overlay
```

Why freeze (not live-transparent, which is what's built today):
- Selections map 1:1 to pixels; nothing moves underneath.
- **Text selection is only possible on a static image** (you must OCR to know
  where text is).
- Matches Circle to Search / Magic Pointer ("a paused frame becomes a link").

---

## 3. Architecture

| Layer | Tech | Channel |
|---|---|---|
| Shake hook | C++ `WH_MOUSE_LL` (exists) | `magisor/mouse_hook` |
| Screen capture | C++ BitBlt (exists, DPI/multi-monitor-correct) | `magisor/capture` |
| **OCR (NEW)** | C++/WinRT **`Windows.Media.Ocr`** | `magisor/ocr` |
| **UI Automation (NEW, phase 4)** | C++ UIAutomation COM | `magisor/uia` |
| Startup/registry | C++ (exists) | `magisor/system` |
| UI / state | Flutter + provider | — |
| AI | Gemini / Claude / Groq HTTP (exists) | — |

Replace `google_mlkit_text_recognition` (mobile-only; non-functional on Windows)
with the native `magisor/ocr` channel.

---

## 4. Phases (implement in order; each ends green: `flutter analyze` 0 errors +
`flutter build windows` + launch)

### Phase 1 — Freeze-screenshot overlay (no new deps)  ✅ DONE
Convert the overlay from transparent-live to showing the captured bitmap.
- On shake: capture the full virtual screen FIRST, decode to a Flutter `Image`,
  store as `_frozenShot` (Uint8List / ui.Image).
- Overlay renders `_frozenShot` fullscreen as the background; the radial menu,
  ask bar, region selector, and result overlay sit on top of it.
- Circle-to-Search: crop from the **already-captured** bitmap (no re-capture).
- Files: `home_screen.dart` (capture-on-invoke + hold the bitmap),
  new `frozen_canvas.dart` widget (renders the shot + hosts interaction layers).
- Risk: memory (hold one full-screen bitmap); free it on close.

### Phase 2 — Native Windows OCR (`Windows.Media.Ocr`)  ✅ DONE
- New C++ method channel `magisor/ocr` with `recognize(bytes,width,height)` →
  returns `[{text, x, y, w, h}]` word boxes (physical px).
- Implement with WinRT `OcrEngine.TryCreateFromUserProfileLanguages()` →
  `RecognizeAsync` on a `SoftwareBitmap` built from the BGRA capture.
- Dart `OcrService` wraps the channel (replaces ML Kit usage).
- Run OCR on the frozen shot in the background right after capture; cache boxes.

### Phase 3 — Text-selection mode  ✅ DONE
- New "Select Text" radial node → enters text-select mode over the frozen shot.
- Render OCR word boxes as an invisible selectable layer; drag to select a run
  of words (Google-Lens style highlight); show a small toolbar:
  **Copy / Translate / Search / Ask**.
- Copy → clipboard; Translate/Ask → feed selected text (+ optional crop) to AI;
  Search → `url_launcher` to a search URL.
- Files: new `text_select_layer.dart`; wire actions in `home_screen.dart`.

### Phase 4 — UI Automation hybrid  ⚠️ REVISED — does not fit the freeze model
**Finding (2026-06-21):** UI Automation reads the **live** accessibility tree by
screen coordinate, but our overlay is **topmost and interactive** over a
**frozen** screenshot. So `ElementFromPoint` at the drag location returns our
own overlay, not the app beneath — and UIA has no concept of the frozen image's
pixels. UIA is a *live-pointing* technology; this flow is *capture-then-select*.
They don't compose for spatial text selection, and **OCR (Phases 2–3) already
covers it well** (verified: 270+ words recognized on a real screen).

So UIA-hybrid-*for-selection* is **dropped**. UIA's real home is Phase 5 (live
point mode), or an optional invoke-time grab of the focused window's exact text
to sharpen AI answers (heavy native COM, performance traps) — deferred.

### Phase 5 — Magic-Pointer "point" mode (north star, future)
A separate **live** (non-freeze) interaction: point at live content and the AI
understands what's under the pointer (UIA element + a live crop + OCR). This is
where UI Automation belongs. A bigger, new interaction model — revisit after the
freeze-based desktop Magic Pointer is finalized.

### Polish / finalize (current)
- ✅ "Select all" in text mode (one-tap whole-screen Copy / Translate / Search / Ask).
- ✅ GlassCard wrapped in a transparent Material (fixes ListTile ink ripples).
- Optional: pixel-exact fullscreen overlay (remove the slight taskbar stretch).

---

## 5. Cross-platform mapping (later)

Same channels, OS-specific native impls:
- **macOS**: ScreenCaptureKit (capture) + **Vision** OCR + Accessibility (AX).
- **Android**: MediaProjection + ML Kit OCR + Accessibility Service.
- **iOS**: screenshot/ReplayKit + Vision OCR; overlay via Action Extension.

---

## 6. Guardrails for the implementing agent (Opus 4.8 @ xhigh)

- Implement **one phase per turn**; build + launch to verify before the next.
- **Do not** re-architect prior phases — each phase is strictly additive.
- Keep platform-specific code behind the existing method channels; never call
  Win32/WinRT from Dart directly.
- Preserve current working features (multi-provider, history, multi-turn,
  settings) — they are not part of this re-architecture.
- After each phase: `flutter analyze` (0 errors), `flutter build windows
  --debug`, launch smoke test, then commit.
```
