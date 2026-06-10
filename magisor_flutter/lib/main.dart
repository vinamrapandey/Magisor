import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';
import 'core/services/auth_service.dart';
import 'core/services/shake_detector_service.dart';
import 'core/services/capture_service.dart';
import 'core/services/ocr_service.dart';
import 'core/providers/gemini_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
  } catch (e) {
    print('Firebase init warning (needs google-services.json for production): $e');
  }

  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => AuthService()),
        Provider(create: (_) => ShakeDetectorService()..start()),
        Provider(create: (_) => CaptureService()),
        Provider(create: (_) => OcrService()),
        Provider(create: (_) => GeminiProvider()),
      ],
      child: const MagisorApp(),
    ),
  );
}
