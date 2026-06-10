import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

class CaptureService {
  static const MethodChannel _channel = MethodChannel('magisor/capture');

  Future<Uint8List> captureRegion(Rect region) async {
    try {
      final result = await _channel.invokeMethod('captureRegion', {
        'x': region.left,
        'y': region.top,
        'width': region.width,
        'height': region.height,
      });
      return result as Uint8List;
    } catch (e) {
      print("Warning: Capture failed or not implemented: $e");
      return Uint8List(0);
    }
  }

  Future<Uint8List> captureFullScreen() async {
    try {
      final result = await _channel.invokeMethod('captureFullScreen');
      return result as Uint8List;
    } catch (e) {
      print("Warning: Full capture failed: $e");
      return Uint8List(0);
    }
  }

  String toBase64Jpeg(Uint8List pngBytes) {
    if (pngBytes.isEmpty) return '';
    // Converting PNG raw bytes to Base64 to be sent to Gemini API
    return base64Encode(pngBytes);
  }

  Rect regionAroundPoint(Offset center, Size screenSize) {
    const width = 600.0;
    const height = 400.0;
    
    double left = center.dx - (width / 2);
    double top = center.dy - (height / 2);

    if (left < 0) left = 0;
    if (top < 0) top = 0;
    if (left + width > screenSize.width) left = screenSize.width - width;
    if (top + height > screenSize.height) top = screenSize.height - height;

    return Rect.fromLTWH(left, top, width, height);
  }
}