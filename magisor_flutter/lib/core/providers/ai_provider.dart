import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/magisor_response.dart';

abstract class AIProvider {
  final _storage = const FlutterSecureStorage();

  String get providerName;
  bool get supportsVision;

  /// Models the user can choose for this provider (all vision-capable). The
  /// first entry is the default.
  List<String> get availableModels;

  String? _selectedModel;
  String get modelId => _selectedModel ?? availableModels.first;

  String get _storageKey => 'magisor_${providerName.toLowerCase()}_key';
  String get _modelKey => 'magisor_${providerName.toLowerCase()}_model';

  Future<String?> loadKey() async {
    return await _storage.read(key: _storageKey);
  }

  /// Load the persisted model choice. Call at startup.
  Future<void> loadModel() async {
    try {
      final m = await _storage.read(key: _modelKey);
      if (m != null && availableModels.contains(m)) _selectedModel = m;
    } catch (_) {
      // Keep the default model if storage is unavailable.
    }
  }

  Future<void> setModel(String model) async {
    if (!availableModels.contains(model)) return;
    _selectedModel = model;
    try {
      await _storage.write(key: _modelKey, value: model);
    } catch (_) {
      // Best-effort persistence.
    }
  }

  Future<bool> verifyKey(String apiKey);
  Future<MagisorResponse> analyzeScreen(String base64Image, String prompt);
  Future<MagisorResponse> analyzeText(String text, String prompt);

  String get systemPrompt => 
    "You are Magisor, an AI screen assistant. The user activated you on "
    "their screen. Be concise and actionable. Respond ONLY in JSON: "
    "{ \"summary\": \"string\", \"actions\": [\"string\"], \"extractedText\": \"string\" }";
}