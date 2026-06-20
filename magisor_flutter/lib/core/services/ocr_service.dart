import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One recognized word and its bounding box, in the captured image's physical
/// pixels.
class WordBox {
  final String text;
  final Rect rect;
  const WordBox(this.text, this.rect);
}

/// On-device OCR. On Windows this is backed by the native `Windows.Media.Ocr`
/// engine over the `magisor/ocr` method channel (see flutter_window.cpp).
class OcrService {
  static const MethodChannel _channel = MethodChannel('magisor/ocr');

  /// Recognizes words in raw BGRA [bgra] bytes of the given size. Returns the
  /// word boxes, or an empty list if OCR is unavailable / failed.
  Future<List<WordBox>> recognize(Uint8List bgra, int width, int height) async {
    if (bgra.isEmpty || width <= 0 || height <= 0) return const [];
    try {
      final res = await _channel.invokeMethod('recognize', {
        'bytes': bgra,
        'width': width,
        'height': height,
      });
      if (res is List) {
        return res.map((e) {
          final m = e as Map;
          return WordBox(
            (m['text'] ?? '') as String,
            Rect.fromLTWH(
              (m['x'] as num).toDouble(),
              (m['y'] as num).toDouble(),
              (m['w'] as num).toDouble(),
              (m['h'] as num).toDouble(),
            ),
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('OCR failed: $e');
    }
    return const [];
  }
}
