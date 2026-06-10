import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/magisor_response.dart';

abstract class AIProvider {
  final _storage = const FlutterSecureStorage();

  String get providerName;
  String get modelId;
  bool get supportsVision;

  String get _storageKey => 'magisor_${providerName.toLowerCase()}_key';

  Future<String?> loadKey() async {
    return await _storage.read(key: _storageKey);
  }

  Future<bool> verifyKey(String apiKey);
  Future<MagisorResponse> analyzeScreen(String base64Image, String prompt);
  Future<MagisorResponse> analyzeText(String text, String prompt);

  String get systemPrompt => 
    "You are Magisor, an AI screen assistant. The user activated you on "
    "their screen. Be concise and actionable. Respond ONLY in JSON: "
    "{ \"summary\": \"string\", \"actions\": [\"string\"], \"extractedText\": \"string\" }";
}