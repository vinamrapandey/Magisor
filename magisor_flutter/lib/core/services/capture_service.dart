import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:image/image.dart' as img;

class CaptureService {
  static const MethodChannel _channel = MethodChannel('magisor/capture');

  /// Physical-pixel bounds of the whole virtual desktop (spans every monitor).
  /// Returns null if the native side is unavailable.
  Future<Rect?> getVirtualScreenRect() async {
    try {
      final r = await _channel.invokeMethod('getVirtualScreenRect');
      if (r is Map) {
        return Rect.fromLTWH(
          (r['x'] as num).toDouble(),
          (r['y'] as num).toDouble(),
          (r['width'] as num).toDouble(),
          (r['height'] as num).toDouble(),
        );
      }
    } catch (e) {
      debugPrint('Warning: getVirtualScreenRect failed: $e');
    }
    return null;
  }

  /// Captures a region given in **physical** screen pixels (matching the
  /// native low-level mouse hook coordinates and DPI-aware screen metrics).
  Future<Uint8List> captureRegion(Rect region) async {
    try {
      final result = await _channel.invokeMethod('captureRegion', {
        'x': region.left.toInt(),
        'y': region.top.toInt(),
        'width': region.width.toInt(),
        'height': region.height.toInt(),
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

  String toBase64Jpeg(Uint8List bgraBytes, int width, int height) {
    if (bgraBytes.isEmpty) return '';
    // Native C++ code returns raw BGRA bytes using BitBlt and GetDIBits
    final image = img.Image.fromBytes(
      width: width, 
      height: height, 
      bytes: bgraBytes.buffer, 
      order: img.ChannelOrder.bgra
    );
    final jpegBytes = img.encodeJpg(image, quality: 80);
    return base64Encode(jpegBytes);
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