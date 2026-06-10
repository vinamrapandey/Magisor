import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_provider.dart';
import '../models/magisor_response.dart';

class GeminiProvider extends AIProvider {
  @override
  String get providerName => 'Gemini';

  @override
  String get modelId => 'gemini-2.0-flash';

  @override
  bool get supportsVision => true;

  Future<String> _getApiKey() async {
    final key = await loadKey();
    if (key == null || key.isEmpty) throw Exception('No API key set for $providerName');
    return key;
  }

  @override
  Future<bool> verifyKey(String apiKey) async {
    try {
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$modelId?key=$apiKey');
      final res = await http.get(url);
      return res.statusCode == 200 || res.statusCode == 400; // 400 means key works but request is empty
    } catch (_) {
      return false;
    }
  }

  @override
  Future<MagisorResponse> analyzeScreen(String base64Image, String prompt) async {
    final key = await _getApiKey();
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$modelId:generateContent?key=$key');
    
    final body = {
      "system_instruction": { "parts": [{"text": systemPrompt}] },
      "contents": [
        {
          "parts": [
            {"text": prompt},
            {
              "inline_data": {
                "mime_type": "image/jpeg",
                "data": base64Image
              }
            }
          ]
        }
      ]
    };

    final res = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
    if (res.statusCode != 200) throw Exception('API Error: ${res.statusCode}');

    final data = jsonDecode(res.body);
    final textResponse = data['candidates'][0]['content']['parts'][0]['text'] as String;
    
    try {
      final cleanJson = textResponse.replaceAll('```json', '').replaceAll('```', '').trim();
      return MagisorResponse.fromJson(jsonDecode(cleanJson), providerName);
    } catch (e) {
      return MagisorResponse(summary: textResponse, actions: [], extractedText: '', providerUsed: providerName);
    }
  }

  @override
  Future<MagisorResponse> analyzeText(String text, String prompt) async {
    final key = await _getApiKey();
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$modelId:generateContent?key=$key');
    
    final body = {
      "system_instruction": { "parts": [{"text": systemPrompt}] },
      "contents": [
        { "parts": [ {"text": "$prompt\n\nContext:\n$text"} ] }
      ]
    };

    final res = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
    if (res.statusCode != 200) throw Exception('API Error: ${res.statusCode}');

    final data = jsonDecode(res.body);
    final textResponse = data['candidates'][0]['content']['parts'][0]['text'] as String;
    
    try {
      final cleanJson = textResponse.replaceAll('```json', '').replaceAll('```', '').trim();
      return MagisorResponse.fromJson(jsonDecode(cleanJson), providerName);
    } catch (e) {
      return MagisorResponse(summary: textResponse, actions: [], extractedText: text, providerUsed: providerName);
    }
  }
}