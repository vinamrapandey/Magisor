import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/magisor_response.dart';
import '../../core/providers/gemini_provider.dart';
import '../../core/services/capture_service.dart';
import '../../core/services/shake_detector_service.dart';
import '../widgets/radial_menu.dart';
import '../widgets/ai_result_overlay.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Offset? _menuPosition;
  bool _isLoading = false;
  MagisorResponse? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final shakeService = context.read<ShakeDetectorService>();
      shakeService.onShakeDetected = (x, y) {
        setState(() {
          _menuPosition = Offset(x, y);
          _result = null;
        });
      };
    });
  }

  Future<void> _handleAction(String action) async {
    // If the user selects a follow-up action from the result overlay,
    // we use the last known menu position, or center of screen if none.
    final center = _menuPosition ?? Offset(
      MediaQuery.of(context).size.width / 2,
      MediaQuery.of(context).size.height / 2,
    );
    
    setState(() {
      _menuPosition = null;
      _isLoading = true;
      _result = null;
    });

    try {
      final captureService = context.read<CaptureService>();
      // We read GeminiProvider for now. A full implementation would read a unified AIProvider.
      final aiProvider = context.read<GeminiProvider>(); 
      
      final screenSize = MediaQuery.of(context).size;
      final region = captureService.regionAroundPoint(center, screenSize);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Completely transparent to show desktop underneath
      body: Stack(
        children: [
          if (_menuPosition != null)
            RadialMenu(
              centerPosition: _menuPosition!,
              onClose: () => setState(() => _menuPosition = null),
              onActionSelected: _handleAction,
            ),
          if (_isLoading || _result != null)
            AIResultOverlay(
              isLoading: _isLoading,
              result: _result,
              onClose: () => setState(() => _result = null),
              onFollowUp: _handleAction,
            ),
        ],
      ),
    );
  }
}