import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';

import '../../core/models/magisor_response.dart';
import '../../core/providers/provider_registry.dart';
import '../../core/services/capture_service.dart';
import '../../core/services/shake_detector_service.dart';
import '../widgets/pie_menu.dart';
import '../widgets/ai_result_overlay.dart';
import '../widgets/ask_bar.dart';
import 'settings/settings_screen.dart';
import 'history_screen.dart';

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
        await _switchToOverlay(Offset(x, y));
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
        MenuItem.separator(),
        MenuItem(key: 'exit', label: 'Exit Magisor'),
      ],
    );
    await trayManager.setContextMenu(menu);
  }

  @override
  void onTrayIconMouseDown() {
    _switchToDashboard();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'dashboard') {
      _switchToDashboard();
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

  Future<void> _switchToOverlay(Offset position) async {
    // Hide briefly so capture doesn't capture the app window if it was visible
    bool isVisible = await windowManager.isVisible();
    if (isVisible) {
      await windowManager.hide();
      await Future.delayed(const Duration(milliseconds: 60));
    }
    
    await windowManager.setAsFrameless();
    await windowManager.setHasShadow(false);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.maximize();
    
    setState(() {
      _currentMode = AppMode.overlay;
      _menuPosition = position;
      _result = null;
    });
    
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _closeOverlay() async {
    setState(() {
      _menuPosition = null;
      _isAsking = false;
      _result = null;
    });
    await windowManager.hide();
  }

  /// Open the free-form "What's on my screen?" input bar.
  void _startAsk() {
    setState(() {
      _menuPosition = null;
      _isAsking = true;
      _result = null;
    });
  }

  /// Capture the whole screen and answer a free-form question about it.
  Future<void> _submitQuestion(String question) async {
    setState(() {
      _isAsking = false;
      _menuPosition = null;
      _isLoading = true;
      _result = null;
    });

    // Let the input bar clear before grabbing the screen.
    await Future.delayed(const Duration(milliseconds: 50));

    try {
      final captureService = context.read<CaptureService>();
      final aiProvider = context.read<ProviderRegistry>().active;

      final screenSize = MediaQuery.of(context).size;
      // Capture the full screen as a single region (known dimensions).
      final region = Rect.fromLTWH(0, 0, screenSize.width, screenSize.height);

      final imageBytes = await captureService.captureRegion(region);
      final base64Img = captureService.toBase64Jpeg(
          imageBytes, region.width.toInt(), region.height.toInt());

      final response = await aiProvider.analyzeScreen(base64Img, question);

      setState(() => _result = response);
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
    });

    // Wait a tiny bit for UI to clear the menu
    await Future.delayed(const Duration(milliseconds: 50));

    try {
      final captureService = context.read<CaptureService>();
      final aiProvider = context.read<ProviderRegistry>().active;
      
      final screenSize = MediaQuery.of(context).size;
      final region = captureService.regionAroundPoint(center, screenSize);
      
      // Capture from native C++ Hook
      final imageBytes = await captureService.captureRegion(region);
      final base64Img = captureService.toBase64Jpeg(imageBytes, region.width.toInt(), region.height.toInt());
      
      final prompt = "Action requested: $action. Analyze the provided screen capture and provide a JSON response following the system prompt.";
      final response = await aiProvider.analyzeScreen(base64Img, prompt);
      
      setState(() {
        _result = response;
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
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: _selectedTab == 0 ? const SettingsScreen() : const HistoryScreen(),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlay() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          if (_menuPosition != null)
            PieMenu(
              centerPosition: _menuPosition!,
              onClose: _closeOverlay,
              items: [
                PieMenuItem(icon: Icons.chat_bubble_outline, label: "Ask", onTap: _startAsk),
                PieMenuItem(icon: Icons.auto_awesome, label: "Summarize", onTap: () => _handleAction("Summarize")),
                PieMenuItem(icon: Icons.lightbulb_outline, label: "Explain", onTap: () => _handleAction("Explain")),
                PieMenuItem(icon: Icons.translate, label: "Translate", onTap: () => _handleAction("Translate")),
                PieMenuItem(icon: Icons.copy_all, label: "Copy Text", onTap: () => _handleAction("Copy Text")),
                PieMenuItem(icon: Icons.close, label: "Close", onTap: () => _handleAction("Close")),
              ],
            ),
          if (_isAsking)
            AskBar(
              onSubmit: _submitQuestion,
              onCancel: _closeOverlay,
            ),
          if (_isLoading || _result != null)
            AIResultOverlay(
              isLoading: _isLoading,
              result: _result,
              onClose: _closeOverlay,
              onFollowUp: _handleAction,
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