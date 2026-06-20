import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';

import '../../core/models/magisor_response.dart';
import '../../core/models/saved_item.dart';
import '../../core/providers/provider_registry.dart';
import '../../core/services/capture_service.dart';
import '../../core/services/ocr_service.dart';
import '../../core/services/shake_detector_service.dart';
import '../../core/services/storage_service.dart';
import '../widgets/pie_menu.dart';
import '../widgets/ai_result_overlay.dart';
import '../widgets/ask_bar.dart';
import '../widgets/region_selector.dart';
import '../widgets/text_select_layer.dart';
import 'settings/settings_screen.dart';
import 'history_screen.dart';
import 'saved_screen.dart';

enum AppMode { dashboard, overlay }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WindowListener, TrayListener {
  AppMode _currentMode = AppMode.dashboard;
  Offset? _menuPosition;
  bool _isLoading = false;
  bool _isAsking = false;
  MagisorResponse? _result;
  SavedItem? _currentEntry;
  String? _lastCaptureBase64;
  final List<String> _conversation = [];
  bool _isSelecting = false;
  bool _isTextSelecting = false;

  // The frozen screenshot shown under the overlay, and its physical bounds.
  Uint8List? _frozenJpeg;
  Rect? _frozenRect;
  // OCR word boxes for the frozen screenshot (used by Phase 3 text selection).
  List<WordBox> _wordBoxes = const [];

  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    trayManager.addListener(this);
    
    _initSystem();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final shakeService = context.read<ShakeDetectorService>();
      shakeService.onShakeDetected = (x, y) async {
        // Shake coords are physical pixels.
        await _invokeOverlay(physicalPoint: Offset(x, y));
      };
    });
  }
  
  @override
  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    super.dispose();
  }

  Future<void> _initSystem() async {
    await windowManager.setPreventClose(true);
    await trayManager.setIcon('assets/tray_icon.ico');
    Menu menu = Menu(
      items: [
        MenuItem(key: 'dashboard', label: 'Settings & History'),
        if (kDebugMode) MenuItem(key: 'test_overlay', label: 'Open Overlay (Test)'),
        MenuItem.separator(),
        MenuItem(key: 'exit', label: 'Exit Magisor'),
      ],
    );
    await trayManager.setContextMenu(menu);
    // Start silently in the system tray; the app lives in the background and
    // is summoned by shaking. Open Settings/History from the tray icon.
    await windowManager.hide();
  }

  @override
  void onTrayIconMouseDown() {
    _switchToDashboard();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'dashboard') {
      _switchToDashboard();
    } else if (menuItem.key == 'test_overlay') {
      _testOverlay();
    } else if (menuItem.key == 'exit') {
      windowManager.destroy();
    }
  }

  @override
  void onWindowClose() async {
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      await windowManager.hide();
    }
  }

  Future<void> _switchToDashboard() async {
    await windowManager.unmaximize();
    await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    await windowManager.setHasShadow(true);
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setSize(const Size(900, 700));
    await windowManager.center();
    
    setState(() {
      _currentMode = AppMode.dashboard;
      _menuPosition = null;
      _result = null;
    });
    
    await windowManager.show();
    await windowManager.focus();
  }

  /// Brings the window forward as a frameless, always-on-top fullscreen overlay.
  Future<void> _showOverlayWindow() async {
    await windowManager.setAsFrameless();
    await windowManager.setHasShadow(false);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.maximize();
    await windowManager.show();
    await windowManager.focus();
  }

  /// Freezes the screen, then opens the overlay over that frozen screenshot.
  /// [physicalPoint] is the invocation location in physical pixels (the shake
  /// position); null centers the menu (test trigger).
  Future<void> _invokeOverlay({Offset? physicalPoint}) async {
    final captureService = context.read<CaptureService>();
    final ocrService = context.read<OcrService>();
    final dpr = MediaQuery.of(context).devicePixelRatio;

    // Make sure no Magisor window is in the screenshot.
    if (await windowManager.isVisible()) {
      await windowManager.hide();
      await Future.delayed(const Duration(milliseconds: 80));
    }

    // Freeze the primary monitor.
    final rect = await captureService.getPrimaryScreenRect();
    Uint8List? jpeg;
    Uint8List? bgra;
    if (rect != null) {
      bgra = await captureService.captureRegion(rect);
      jpeg = captureService.jpegBytes(bgra, rect.width.toInt(), rect.height.toInt());
      if (jpeg.isEmpty) jpeg = null;
    }

    // Logical menu position.
    final Offset menuPos;
    if (physicalPoint != null) {
      menuPos = Offset(physicalPoint.dx / dpr, physicalPoint.dy / dpr);
    } else if (rect != null) {
      menuPos = Offset(rect.width / dpr / 2, rect.height / dpr / 2);
    } else {
      menuPos = const Offset(400, 300);
    }

    setState(() {
      _currentMode = AppMode.overlay;
      _frozenJpeg = jpeg;
      _frozenRect = rect;
      _menuPosition = menuPos;
      _isAsking = false;
      _isSelecting = false;
      _result = null;
      _currentEntry = null;
      _lastCaptureBase64 = null;
      _conversation.clear();
      _isTextSelecting = false;
      _wordBoxes = const [];
    });

    await _showOverlayWindow();

    // Phase 2: OCR the frozen screenshot in the background; Phase 3 will use the
    // word boxes for text selection. Fire-and-forget — it doesn't block the UI.
    if (rect != null && bgra != null && bgra.isNotEmpty) {
      ocrService
          .recognize(bgra, rect.width.toInt(), rect.height.toInt())
          .then((boxes) {
        if (!mounted) return;
        debugPrint('OCR: ${boxes.length} words recognized');
        setState(() => _wordBoxes = boxes);
      });
    }
  }

  Future<void> _closeOverlay() async {
    setState(() {
      _menuPosition = null;
      _isAsking = false;
      _isSelecting = false;
      _result = null;
      _currentEntry = null;
      _lastCaptureBase64 = null;
      _conversation.clear();
      _isTextSelecting = false;
      _frozenJpeg = null;
      _frozenRect = null;
      _wordBoxes = const [];
    });
    await windowManager.hide();
  }

  /// Dev/testing helper: open the overlay without a mouse shake (debug only).
  Future<void> _testOverlay() async {
    await _invokeOverlay();
  }

  /// Maps a rect in overlay-logical coordinates to the frozen image's physical
  /// pixels (robust to the overlay not being exactly full-screen).
  Rect _logicalToImageRect(Rect logical, Size overlaySize, Rect imageRect) {
    final sx = imageRect.width / overlaySize.width;
    final sy = imageRect.height / overlaySize.height;
    return Rect.fromLTWH(
      logical.left * sx,
      logical.top * sy,
      logical.width * sx,
      logical.height * sy,
    );
  }

  /// Open the free-form "What's on my screen?" input bar.
  void _startAsk() {
    setState(() {
      _menuPosition = null;
      _isAsking = true;
      _result = null;
      _currentEntry = null;
      _lastCaptureBase64 = null;
      _conversation.clear();
    });
  }

  /// Enter region-selection ("Circle to Search") mode.
  void _startRegionSelect() {
    setState(() {
      _menuPosition = null;
      _isSelecting = true;
      _result = null;
      _currentEntry = null;
      _lastCaptureBase64 = null;
      _conversation.clear();
    });
  }

  /// Enter "Select Text" mode (drag-select OCR'd words on the frozen shot).
  void _startTextSelect() {
    setState(() {
      _menuPosition = null;
      _isTextSelecting = true;
      _result = null;
      _currentEntry = null;
    });
  }

  /// Maps OCR word boxes (frozen-image physical px) to overlay-logical coords.
  List<PositionedWord> _wordBoxesLogical(Size overlaySize) {
    final frozen = _frozenRect;
    if (frozen == null || frozen.width <= 0 || frozen.height <= 0) return const [];
    final sx = overlaySize.width / frozen.width;
    final sy = overlaySize.height / frozen.height;
    return _wordBoxes
        .map((wb) => (
              rect: Rect.fromLTWH(
                wb.rect.left * sx,
                wb.rect.top * sy,
                wb.rect.width * sx,
                wb.rect.height * sy,
              ),
              text: wb.text,
            ))
        .toList();
  }

  /// Handle a toolbar action on selected text.
  Future<void> _onTextAction(String action, String text) async {
    if (text.trim().isEmpty) return;
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: text));
      await _closeOverlay();
      return;
    }
    if (action == 'search') {
      final uri = Uri.parse(
          'https://www.google.com/search?q=${Uri.encodeQueryComponent(text)}');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      await _closeOverlay();
      return;
    }
    // translate / ask -> AI on the selected text (no image needed).
    setState(() {
      _isTextSelecting = false;
      _isLoading = true;
      _result = null;
      _currentEntry = null;
      _lastCaptureBase64 = null;
      _conversation.clear();
    });
    final isTranslate = action == 'translate';
    final prompt = isTranslate
        ? "Translate this text to English (or detect and state its language if it is already English):\n\n$text"
        : "Explain this text concisely:\n\n$text";
    await _analyzeText(
      query: isTranslate ? 'Translate' : 'Ask',
      text: text,
      prompt: prompt,
    );
  }

  /// Run a text-only AI analysis, show the result, and persist it.
  Future<void> _analyzeText({
    required String query,
    required String text,
    required String prompt,
  }) async {
    final aiProvider = context.read<ProviderRegistry>().active;
    final storage = context.read<StorageService>();
    try {
      final response = await aiProvider.analyzeText(text, prompt);
      final entry = await storage.addEntry(
        query: query,
        summary: response.summary,
        extractedText: text,
        providerUsed: response.providerUsed,
      );
      if (!mounted) return;
      setState(() {
        _result = response;
        _currentEntry = entry;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _result = MagisorResponse(
          summary: "An error occurred: $e",
          actions: const ["Retry"],
          extractedText: "",
          providerUsed: "Error",
        );
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Star/unstar the result currently shown in the overlay.
  Future<void> _toggleCurrentSaved() async {
    final entry = _currentEntry;
    if (entry == null) return;
    final storage = context.read<StorageService>();
    await storage.toggleSaved(entry);
    final updated = storage.history.where((e) => e.id == entry.id);
    if (mounted) {
      setState(() => _currentEntry = updated.isNotEmpty ? updated.first : entry);
    }
  }

  /// Continue the conversation about the same captured screen (multi-turn).
  Future<void> _followUp(String question) async {
    final image = _lastCaptureBase64;
    if (image == null) return;

    setState(() => _isLoading = true);

    try {
      final aiProvider = context.read<ProviderRegistry>().active;
      final storage = context.read<StorageService>();

      _conversation.add('User: $question');
      final prompt =
          "Continue this conversation about the user's screen, answering the "
          "final question.\n\n${_conversation.join('\n')}";
      final response = await aiProvider.analyzeScreen(image, prompt);
      _conversation.add('Magisor: ${response.summary}');

      final entry = await storage.addEntry(
        query: question,
        summary: response.summary,
        extractedText: response.extractedText,
        providerUsed: response.providerUsed,
      );
      setState(() {
        _result = response;
        _currentEntry = entry;
      });
    } catch (e) {
      setState(() {
        _result = MagisorResponse(
          summary: "An error occurred: $e",
          actions: ["Retry"],
          extractedText: "",
          providerUsed: "Error",
        );
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Handle a region drawn in "Circle to Search" mode.
  Future<void> _onRegionSelected(Rect logicalRect) async {
    if (logicalRect.width < 8 || logicalRect.height < 8) {
      setState(() => _isSelecting = false);
      return;
    }
    final overlaySize = MediaQuery.of(context).size;
    final frozen = _frozenRect;
    setState(() {
      _isSelecting = false;
      _isLoading = true;
      _result = null;
      _currentEntry = null;
      _lastCaptureBase64 = null;
      _conversation.clear();
    });
    if (frozen == null) {
      setState(() {
        _result = MagisorResponse(
          summary: "No screen capture available.",
          actions: const ["Retry"],
          extractedText: "",
          providerUsed: "Error",
        );
        _isLoading = false;
      });
      return;
    }
    // Map the drawn rect onto the frozen screenshot's pixels.
    final imageRect = _logicalToImageRect(logicalRect, overlaySize, frozen);
    await _analyzeRegion(
      imageRect,
      query: 'Circle to Search',
      prompt: "The user selected a specific region of their screen. Identify, "
          "explain, or search what it contains, and respond following the "
          "system prompt JSON format.",
    );
  }

  /// Crop a region out of the frozen screenshot, analyze it, and show the result.
  Future<void> _analyzeRegion(Rect imageRect,
      {required String query, required String prompt}) async {
    final captureService = context.read<CaptureService>();
    final aiProvider = context.read<ProviderRegistry>().active;
    final storage = context.read<StorageService>();
    final jpeg = _frozenJpeg;
    try {
      final b64 = jpeg != null ? captureService.cropToBase64Jpeg(jpeg, imageRect) : '';
      final response = await aiProvider.analyzeScreen(b64, prompt);
      final entry = await storage.addEntry(
        query: query,
        summary: response.summary,
        extractedText: response.extractedText,
        providerUsed: response.providerUsed,
      );
      if (!mounted) return;
      setState(() {
        _result = response;
        _currentEntry = entry;
        _lastCaptureBase64 = b64;
        _conversation
          ..clear()
          ..add('User: $query')
          ..add('Magisor: ${response.summary}');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _result = MagisorResponse(
          summary: "An error occurred: $e",
          actions: ["Retry"],
          extractedText: "",
          providerUsed: "Error",
        );
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Capture the whole screen and answer a free-form question about it.
  Future<void> _submitQuestion(String question) async {
    setState(() {
      _isAsking = false;
      _menuPosition = null;
      _isLoading = true;
      _result = null;
      _currentEntry = null;
      _lastCaptureBase64 = null;
      _conversation.clear();
    });

    try {
      final aiProvider = context.read<ProviderRegistry>().active;
      final storage = context.read<StorageService>();

      // Use the full frozen screenshot taken when the overlay opened.
      final jpeg = _frozenJpeg;
      final base64Img =
          (jpeg != null && jpeg.isNotEmpty) ? base64Encode(jpeg) : '';

      final response = await aiProvider.analyzeScreen(base64Img, question);

      final entry = await storage.addEntry(
        query: question,
        summary: response.summary,
        extractedText: response.extractedText,
        providerUsed: response.providerUsed,
      );
      setState(() {
        _result = response;
        _currentEntry = entry;
        _lastCaptureBase64 = base64Img;
        _conversation
          ..clear()
          ..add('User: $question')
          ..add('Magisor: ${response.summary}');
      });
    } catch (e) {
      setState(() {
        _result = MagisorResponse(
          summary: "An error occurred while analyzing your screen: $e",
          actions: ["Retry", "Check Settings"],
          extractedText: "",
          providerUsed: "Error",
        );
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAction(String action) async {
    if (action == 'Close') {
      await _closeOverlay();
      return;
    }

    final center = _menuPosition ?? Offset(
      MediaQuery.of(context).size.width / 2,
      MediaQuery.of(context).size.height / 2,
    );
    
    // Hide overlay so we can capture the screen again safely if needed
    setState(() {
      _menuPosition = null;
      _isLoading = true;
      _result = null;
      _currentEntry = null;
      _lastCaptureBase64 = null;
      _conversation.clear();
    });

    // Wait a tiny bit for UI to clear the menu
    await Future.delayed(const Duration(milliseconds: 50));

    try {
      final captureService = context.read<CaptureService>();
      final aiProvider = context.read<ProviderRegistry>().active;
      final storage = context.read<StorageService>();

      // Crop a region around the cursor out of the frozen screenshot.
      final jpeg = _frozenJpeg;
      final frozen = _frozenRect;
      String base64Img = '';
      if (jpeg != null && frozen != null) {
        final overlaySize = MediaQuery.of(context).size;
        final logicalRegion = captureService.regionAroundPoint(center, overlaySize);
        final crop = _logicalToImageRect(logicalRegion, overlaySize, frozen);
        base64Img = captureService.cropToBase64Jpeg(jpeg, crop);
      }

      final prompt = "Action requested: $action. Analyze the provided screen capture and provide a JSON response following the system prompt.";
      final response = await aiProvider.analyzeScreen(base64Img, prompt);

      final entry = await storage.addEntry(
        query: action,
        summary: response.summary,
        extractedText: response.extractedText,
        providerUsed: response.providerUsed,
      );
      setState(() {
        _result = response;
        _currentEntry = entry;
        _lastCaptureBase64 = base64Img;
        _conversation
          ..clear()
          ..add('User: $action')
          ..add('Magisor: ${response.summary}');
      });
    } catch (e) {
      setState(() {
        _result = MagisorResponse(
          summary: "An error occurred while processing your request: $e",
          actions: ["Retry", "Check Settings"],
          extractedText: "",
          providerUsed: "Error",
        );
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildDashboard() {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Magisor Dashboard'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          if (kDebugMode)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _testOverlay,
                icon: const Icon(Icons.bolt, size: 18),
                label: const Text('Test Overlay'),
              ),
            ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedTab,
            onDestinationSelected: (index) => setState(() => _selectedTab = index),
            labelType: NavigationRailLabelType.all,
            backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.settings),
                label: Text('Settings'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.history),
                label: Text('History'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.bookmark_border),
                label: Text('Saved'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: switch (_selectedTab) {
              0 => const SettingsScreen(),
              1 => const HistoryScreen(),
              _ => const SavedScreen(),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOverlay() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_frozenJpeg != null)
            Positioned.fill(
              child: Image.memory(
                _frozenJpeg!,
                fit: BoxFit.fill,
                gaplessPlayback: true,
              ),
            ),
          if (_menuPosition != null)
            PieMenu(
              centerPosition: _menuPosition!,
              onClose: _closeOverlay,
              items: [
                PieMenuItem(icon: Icons.chat_bubble_outline, label: "Ask", onTap: _startAsk),
                PieMenuItem(icon: Icons.crop_free, label: "Select", onTap: _startRegionSelect),
                PieMenuItem(icon: Icons.auto_awesome, label: "Summarize", onTap: () => _handleAction("Summarize")),
                PieMenuItem(icon: Icons.lightbulb_outline, label: "Explain", onTap: () => _handleAction("Explain")),
                PieMenuItem(icon: Icons.translate, label: "Translate", onTap: () => _handleAction("Translate")),
                PieMenuItem(icon: Icons.text_fields, label: "Select Text", onTap: _startTextSelect),
                PieMenuItem(icon: Icons.close, label: "Close", onTap: () => _handleAction("Close")),
              ],
            ),
          if (_isAsking)
            AskBar(
              onSubmit: _submitQuestion,
              onCancel: _closeOverlay,
            ),
          if (_isSelecting)
            Positioned.fill(
              child: RegionSelector(
                onSelected: _onRegionSelected,
                onCancel: _closeOverlay,
              ),
            ),
          if (_isTextSelecting)
            Positioned.fill(
              child: TextSelectLayer(
                words: _wordBoxesLogical(MediaQuery.of(context).size),
                onAction: _onTextAction,
                onCancel: _closeOverlay,
              ),
            ),
          if (_isLoading || _result != null)
            AIResultOverlay(
              isLoading: _isLoading,
              result: _result,
              onClose: _closeOverlay,
              onFollowUp: _handleAction,
              isSaved: _currentEntry?.saved ?? false,
              onToggleSaved: _currentEntry != null ? _toggleCurrentSaved : null,
              onAskFollowUp: _lastCaptureBase64 != null ? _followUp : null,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentMode == AppMode.dashboard) {
      return _buildDashboard();
    } else {
      return _buildOverlay();
    }
  }
}