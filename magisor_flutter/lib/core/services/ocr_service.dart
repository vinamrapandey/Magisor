import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io' show Platform;

class OcrService {
  static const MethodChannel _channel = MethodChannel('magisor/ocr');
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<String> extractText(Uint8List imageBytes) async {
    if (imageBytes.isEmpty) return '';
    
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // Mobile ML Kit Implementation
        // In a full implementation, bytes are written to a temp file and fed to InputImage.
        return 'Mobile ML Kit OCR Pending';
      } else {
        // Desktop Native Channels (Windows Media OCR / Apple Vision)
        final String result = await _channel.invokeMethod('extractText', {'bytes': imageBytes});
        return result;
      }
    } catch (e) {
      print("OCR Error: $e");
      return '';
    }
  }

  void dispose() {
    _textRecognizer.close();
  }
}