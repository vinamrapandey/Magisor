import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'core/services/auth_service.dart';
import 'core/services/shake_detector_service.dart';
import 'core/services/capture_service.dart';
import 'core/services/ocr_service.dart';
import 'core/services/storage_service.dart';
import 'core/services/system_service.dart';
import 'core/providers/provider_registry.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Required before any windowManager.* call works (maximize/setBounds/center
  // silently no-op without it).
  await windowManager.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    print('Firebase init warning (needs google-services.json for production): $e');
  }

  final storage = StorageService();
  try {
    await storage.init();
  } catch (e) {
    print('Storage init warning (history will be unavailable): $e');
  }

  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ShakeDetectorService()..start()),
        Provider(create: (_) => CaptureService()),
        Provider(create: (_) => OcrService()),
        ChangeNotifierProvider(create: (_) => ProviderRegistry()..load()),
        ChangeNotifierProvider.value(value: storage),
        ChangeNotifierProvider(create: (_) => SystemService()..load()),
      ],
      child: const MagisorApp(),
    ),
  );
}
