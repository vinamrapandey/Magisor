import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_provider.dart';
import '../models/magisor_response.dart';

/// Claude (Anthropic) AI implementation.
///
/// Uses the Messages API directly over HTTP (Dart has no official Anthropic
/// SDK). Vision is sent as a base64 image content block.
class ClaudeProvider extends AIProvider {
  @override
  String get providerName => 'Claude';

  // Official Anthropic Claude models supporting vision.
  // First entry is the default. Fallbacks are tried automatically on 404.
  @override
  List<String> get availableModels => const [
        'claude-sonnet-4-6',
        'claude-3-5-sonnet-20240620',
        'claude-3-opus-20240229',
        'claude-3-haiku-20240307',
      ];

  @override
  bool get supportsVision => true;

  static const String _baseUrl = 'https://api.anthropic.com/v1';
  static const String _apiVersion = '2023-06-01';

  Future<String> _getApiKey() async {
    final key = await loadKey();
    if (key == null || key.isEmpty) {
      throw Exception('No API key set for $providerName');
    }
    return key;
  }

  Map<String, String> _headers(String key) => {
        'x-api-key': key,
        'anthropic-version': _apiVersion,
        'content-type': 'application/json',
      };

  @override
  Future<bool> verifyKey(String apiKey) async {
    try {
      // GET /models validates the key without consuming any tokens.
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
    final blocks = (data['content'] as List<dynamic>?) ?? const [];
    final textResponse = blocks
        .cast<Map<String, dynamic>>()
        .firstWhere(
          (b) => b['type'] == 'text',
          orElse: () => {'text': ''},
        )['text'] as String;

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

  @override
  Future<MagisorResponse> analyzeScreen(String base64Image, String prompt) async {
    final key = await _getApiKey();
    final modelsToTry = [modelId, ...availableModels.where((m) => m != modelId)];
    String lastErrorMsg = '';

    for (final currentModel in modelsToTry) {
      final body = {
        'model': currentModel,
        'max_tokens': 4096,
        'system': systemPrompt,
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': prompt},
              {
                'type': 'image',
                'source': {
                  'type': 'base64',
                  'media_type': 'image/jpeg',
                  'data': base64Image,
                }
              }
            ]
          }
        ]
      };

      final res = await http.post(
        Uri.parse('$_baseUrl/messages'),
        headers: _headers(key),
        body: jsonEncode(body),
      );

      if (res.statusCode == 200) {
        return _parse(res.body);
      }

      String msg = res.body;
      try {
        final errJson = jsonDecode(res.body);
        if (errJson['error']?['message'] != null) {
          msg = errJson['error']['message'];
        }
      } catch (_) {}

      if (res.statusCode == 404 || res.body.contains('not_found_error')) {
        lastErrorMsg = msg;
        continue;
      }

      throw Exception('Claude API Error (${res.statusCode}): $msg');
    }

    throw Exception('Claude API Error (404): No models accessible for this API key. Details: $lastErrorMsg');
  }

  @override
  Future<MagisorResponse> analyzeText(String text, String prompt) async {
    final key = await _getApiKey();
    final modelsToTry = [modelId, ...availableModels.where((m) => m != modelId)];
    String lastErrorMsg = '';

    for (final currentModel in modelsToTry) {
      final body = {
        'model': currentModel,
        'max_tokens': 4096,
        'system': systemPrompt,
        'messages': [
          {
            'role': 'user',
            'content': '$prompt\n\nContext:\n$text',
          }
        ]
      };

      final res = await http.post(
        Uri.parse('$_baseUrl/messages'),
        headers: _headers(key),
        body: jsonEncode(body),
      );

      if (res.statusCode == 200) {
        return _parse(res.body);
      }

      String msg = res.body;
      try {
        final errJson = jsonDecode(res.body);
        if (errJson['error']?['message'] != null) {
          msg = errJson['error']['message'];
        }
      } catch (_) {}

      if (res.statusCode == 404 || res.body.contains('not_found_error')) {
        lastErrorMsg = msg;
        continue;
      }

      throw Exception('Claude API Error (${res.statusCode}): $msg');
    }

    throw Exception('Claude API Error (404): No models accessible for this API key. Details: $lastErrorMsg');
  }
}
