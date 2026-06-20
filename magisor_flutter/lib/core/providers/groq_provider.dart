import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_provider.dart';
import '../models/magisor_response.dart';

/// Groq AI implementation.
///
/// Groq exposes an OpenAI-compatible Chat Completions API. The default model is
/// a Llama 4 vision model so screen analysis works; swap [modelId] if Groq
/// rotates its hosted model catalog.
class GroqProvider extends AIProvider {
  @override
  String get providerName => 'Groq';

  @override
  String get modelId => 'meta-llama/llama-4-scout-17b-16e-instruct';

  @override
  bool get supportsVision => true;

  static const String _baseUrl = 'https://api.groq.com/openai/v1';

  Future<String> _getApiKey() async {
    final key = await loadKey();
    if (key == null || key.isEmpty) {
      throw Exception('No API key set for $providerName');
    }
    return key;
  }

  Map<String, String> _headers(String key) => {
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
      };

  @override
  Future<bool> verifyKey(String apiKey) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/models'),
        headers: _headers(apiKey),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  MagisorResponse _parse(String responseBody) {
    final data = jsonDecode(responseBody);
    final textResponse =
        (data['choices']?[0]?['message']?['content'] as String?) ?? '';

    try {
      final cleanJson =
          textResponse.replaceAll('```json', '').replaceAll('```', '').trim();
      return MagisorResponse.fromJson(jsonDecode(cleanJson), providerName);
    } catch (_) {
      return MagisorResponse(
        summary: textResponse,
        actions: [],
        extractedText: '',
        providerUsed: providerName,
      );
    }
  }

  Future<MagisorResponse> _send(List<dynamic> userContent) async {
    final key = await _getApiKey();
    final body = {
      'model': modelId,
      'max_tokens': 4096,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userContent},
      ]
    };

    final res = await http.post(
      Uri.parse('$_baseUrl/chat/completions'),
      headers: _headers(key),
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) {
      throw Exception('API Error: ${res.statusCode} ${res.body}');
    }
    return _parse(res.body);
  }

  @override
  Future<MagisorResponse> analyzeScreen(String base64Image, String prompt) {
    return _send([
      {'type': 'text', 'text': prompt},
      {
        'type': 'image_url',
        'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
      }
    ]);
  }

  @override
  Future<MagisorResponse> analyzeText(String text, String prompt) {
    return _send([
      {'type': 'text', 'text': '$prompt\n\nContext:\n$text'},
    ]);
  }
}
