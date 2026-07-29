import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
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
import '../../core/services/system_service.dart';
import '../theme/app_colors.dart';
import '../widgets/pie_menu.dart';
import '../widgets/ai_result_overlay.dart';
import '../widgets/ask_bar.dart';
import '../widgets/region_selector.dart';
import '../widgets/text_select_layer.dart';
import '../widgets/sidebar_nav.dart';
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
  Uint8List? _frozenJpeg; // for AI / cropping
  ui.Image? _frozenImage; // for display (RawImage)
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

  Future<String> _getTrayIconPath() async {
    try {
      final exeDir = path.dirname(Platform.resolvedExecutable);
      final releaseIconPath = path.join(exeDir, 'data', 'flutter_assets', 'assets', 'tray_icon.ico');
      if (File(releaseIconPath).existsSync()) {
        return releaseIconPath;
      }
    } catch (_) {}

    try {
      final debugIconPath = path.join(Directory.current.path, 'assets', 'tray_icon.ico');
      if (File(debugIconPath).existsSync()) {
        return debugIconPath;
      }
    } catch (_) {}

    try {
      final nestedDebugIconPath = path.join(Directory.current.path, 'magisor_flutter', 'assets', 'tray_icon.ico');
      if (File(nestedDebugIconPath).existsSync()) {
        return nestedDebugIconPath;
      }
    } catch (_) {}

    // Extract asset directly from Flutter rootBundle to disk
    try {
      final byteData = await rootBundle.load('assets/tray_icon.ico');
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(path.join(tempDir.path, 'magisor_tray_icon.ico'));
      await tempFile.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
      return tempFile.path;
    } catch (e) {
      debugPrint('TRAY: Failed to extract icon asset: $e');
    }

    return 'assets/tray_icon.ico';
  }

  Future<void> _initSystem() async {
    await windowManager.setPreventClose(true);

    try {
      final iconPath = await _getTrayIconPath();
      debugPrint('TRAY: Using icon path: $iconPath');
      await trayManager.setIcon(iconPath);
    } catch (e) {
      debugPrint('TRAY: setIcon failed: $e');
    }

    try {
      await trayManager.setToolTip('Magisor AI — Right click for menu');
    } catch (e) {
      debugPrint('TRAY: setToolTip failed: $e');
    }

    await _updateTrayMenu();

    // Show the Settings Dashboard window on startup for local testing & access
    await _switchToDashboard(tabIndex: 3);
  }

  Future<void> _updateTrayMenu() async {
    final isPaused = context.read<ShakeDetectorService>().isPaused;
    final menu = Menu(
      items: [
        MenuItem(key: 'settings', label: 'Settings'),
        MenuItem.separator(),
        MenuItem(key: 'pause', label: isPaused ? 'Resume' : 'Pause'),
        MenuItem(key: 'quit', label: 'Quit'),
      ],
    );

    try {
      await trayManager.setContextMenu(menu);
    } catch (e) {
      debugPrint('TRAY: setContextMenu failed: $e');
    }
  }

  @override
  void onTrayIconMouseDown() {
    // Intentionally no action on left click as requested
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'settings':
        _switchToDashboard(tabIndex: 3);
        break;
      case 'pause':
        _togglePause();
        break;
      case 'quit':
        windowManager.destroy();
        break;
    }
  }

  Future<void> _togglePause() async {
    final shakeService = context.read<ShakeDetectorService>();
    await shakeService.togglePause();
    await _updateTrayMenu();
    setState(() {});
  }

  @override
  void onWindowClose() async {
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      await windowManager.hide();
    }
  }

  Future<void> _switchToDashboard({int tabIndex = 3}) async {
    await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    await windowManager.setHasShadow(true);
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setSize(const Size(1000, 720));
    await windowManager.show();
    await windowManager.focus();
    try {
      await windowManager.center();
    } catch (_) {}

    setState(() {
      _selectedTab = tabIndex;
      _currentMode = AppMode.dashboard;
      _menuPosition = null;
      _result = null;
    });
  }

  /// Brings the window forward as a frameless, always-on-top overlay covering
  /// the whole monitor. Uses setBounds (deterministic) rather than maximize(),
  /// which silently fails for a frameless/hidden window.
  Future<void> _showOverlayWindow(Size logicalSize) async {
    await windowManager.setAsFrameless();
    await windowManager.setHasShadow(false);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setBounds(
        Rect.fromLTWH(0, 0, logicalSize.width, logicalSize.height));
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
    ui.Image? frozenImage;
    if (rect != null) {
      bgra = await captureService.captureRegion(rect);
      jpeg = captureService.jpegBytes(bgra, rect.width.toInt(), rect.height.toInt());
      if (jpeg.isEmpty) jpeg = null;
      if (bgra.isNotEmpty) {
        frozenImage = await captureService.decodeBgra(
            bgra, rect.width.toInt(), rect.height.toInt());
      }
    }
    // Full-monitor bounds in logical pixels (physical / device pixel ratio).
    final logicalSize =
        rect != null ? Size(rect.width / dpr, rect.height / dpr) : const Size(1280, 720);

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
      _frozenImage = frozenImage;
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

    await _showOverlayWindow(logicalSize);

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
      _frozenImage = null;
      _frozenRect = null;
      _wordBoxes = const [];
    });
    await windowManager.hide();
  }

  /// Dev/testing helper: open the overlay at the current cursor (debug only).
  Future<void> _testOverlay() async {
    final pos = await context.read<SystemService>().getCursorPos();
    await _invokeOverlay(physicalPoint: pos);
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

      // Local RAG Context Retrieval (0 AI Credits / Instant local disk search)
      final ragContext = await storage.retrieveRAGContext(question);
      final finalPrompt = ragContext != null
          ? "Relevant Local History Context:\n$ragContext\n\nUser Question: $question"
          : question;

      final response = await aiProvider.analyzeScreen(base64Img, finalPrompt);

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
      backgroundColor: AppColors.backgroundPrimary,
      body: Row(
        children: [
          SidebarNav(
            selectedIndex: _selectedTab,
            onItemSelected: (index) => setState(() => _selectedTab = index),
          ),
          Expanded(
            child: switch (_selectedTab) {
              0 => _buildOverviewTab(),
              1 => const HistoryScreen(),
              2 => const SavedScreen(),
              3 => const SettingsScreen(),
              _ => _buildHelpCenterTab(),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final registry = context.watch<ProviderRegistry>();
    final shakeService = context.watch<ShakeDetectorService>();
    final isPaused = shakeService.isPaused;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overview',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'System status and quick controls for Magisor AI assistant.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.glassSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Active Provider',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        registry.active.providerName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        registry.active.modelId,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.glassSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mouse Shake Detector',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: isPaused ? AppColors.errorRed : AppColors.successGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isPaused ? 'Paused' : 'Active',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Sensitivity: ${shakeService.sensitivity.name.toUpperCase()}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.glassSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'How to invoke Magisor',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '1. Shake your mouse back and forth anywhere on your screen.\n'
                  '2. The glassmorphism Pie Menu will appear attached to your cursor.\n'
                  '3. Select an option: Ask, Circle to Search, Summarize, Explain, Translate, or Select Text.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpCenterTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Help Center',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Learn how to use Magisor features and keyboard/gesture shortcuts.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.glassSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Feature Guide',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 12),
                Text('• Circle to Search: Select "Select" from the pie menu and drag over any screen region.'),
                SizedBox(height: 6),
                Text('• Universal OCR: Select "Select Text" to drag and highlight text from images or video.'),
                SizedBox(height: 6),
                Text('• System Tray: Right click the hidden tray icon to access Settings, Pause, or Quit.'),
              ],
            ),
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
          if (_frozenImage != null)
            Positioned.fill(
              child: RawImage(image: _frozenImage, fit: BoxFit.fill),
            ),
          if (_menuPosition != null)
            PieMenu(
              centerPosition: _menuPosition!,
              onClose: _closeOverlay,
              items: [
                PieMenuItem(icon: Icons.chat_bubble_outline, label: "Ask", color: AppColors.accentViolet, onTap: _startAsk),
                PieMenuItem(icon: Icons.crop_free, label: "Select", color: AppColors.accentCyan, onTap: _startRegionSelect),
                PieMenuItem(icon: Icons.auto_awesome, label: "Summarize", color: AppColors.accentCoral, onTap: () => _handleAction("Summarize")),
                PieMenuItem(icon: Icons.lightbulb_outline, label: "Explain", color: AppColors.accentPink, onTap: () => _handleAction("Explain")),
                PieMenuItem(icon: Icons.translate, label: "Translate", color: AppColors.accentViolet, onTap: () => _handleAction("Translate")),
                PieMenuItem(icon: Icons.text_fields, label: "Select Text", color: AppColors.accentAmber, onTap: _startTextSelect),
                PieMenuItem(icon: Icons.close, label: "Close", color: AppColors.textMuted, onTap: () => _handleAction("Close")),
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