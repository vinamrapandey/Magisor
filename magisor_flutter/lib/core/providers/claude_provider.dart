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

  @override
  String get modelId => 'claude-opus-4-8';

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
    final body = {
      'model': modelId,
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
    if (res.statusCode != 200) {
      throw Exception('API Error: ${res.statusCode} ${res.body}');
    }
    return _parse(res.body);
  }

  @override
  Future<MagisorResponse> analyzeText(String text, String prompt) async {
    final key = await _getApiKey();
    final body = {
      'model': modelId,
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
    if (res.statusCode != 200) {
      throw Exception('API Error: ${res.statusCode} ${res.body}');
    }
    return _parse(res.body);
  }
}
