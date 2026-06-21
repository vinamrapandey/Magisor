import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
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

  /// Physical-pixel bounds of the primary monitor (origin 0,0). The overlay is
  /// maximized on the primary monitor, so this is what we freeze.
  Future<Rect?> getPrimaryScreenRect() async {
    try {
      final r = await _channel.invokeMethod('getPrimaryScreenRect');
      if (r is Map) {
        return Rect.fromLTWH(
          (r['x'] as num).toDouble(),
          (r['y'] as num).toDouble(),
          (r['width'] as num).toDouble(),
          (r['height'] as num).toDouble(),
        );
      }
    } catch (e) {
      debugPrint('Warning: getPrimaryScreenRect failed: $e');
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

  /// Encodes raw BGRA bytes (from the native capture) to JPEG bytes, for
  /// display via [Image.memory].
  Uint8List jpegBytes(Uint8List bgraBytes, int width, int height) {
    if (bgraBytes.isEmpty) return Uint8List(0);
    // Native C++ returns raw BGRA bytes (BitBlt + GetDIBits). Use a clean
    // 0-offset copy so the image package reads the right bytes.
    final image = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: Uint8List.fromList(bgraBytes).buffer,
      order: img.ChannelOrder.bgra,
    );
    return img.encodeJpg(image, quality: 85);
  }

  /// Decodes raw BGRA bytes straight to a [ui.Image] for display (no JPEG
  /// round-trip). Forces alpha opaque, since BitBlt leaves it at 0.
  Future<ui.Image> decodeBgra(Uint8List bgraBytes, int width, int height) {
    final bytes = Uint8List.fromList(bgraBytes);
    for (var i = 3; i < bytes.length; i += 4) {
      bytes[i] = 255;
    }
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      bytes, width, height, ui.PixelFormat.bgra8888, completer.complete);
    return completer.future;
  }

  String toBase64Jpeg(Uint8List bgraBytes, int width, int height) {
    final jpeg = jpegBytes(bgraBytes, width, height);
    return jpeg.isEmpty ? '' : base64Encode(jpeg);
  }

  /// Crops a [physicalCrop] region out of an already-captured JPEG and returns
  /// it as base64 JPEG. Used so analysis crops from the frozen screenshot
  /// instead of re-capturing (which would capture our own overlay).
  String cropToBase64Jpeg(Uint8List jpeg, Rect physicalCrop) {
    if (jpeg.isEmpty) return '';
    final image = img.decodeJpg(jpeg);
    if (image == null) return base64Encode(jpeg);
    final x = physicalCrop.left.toInt().clamp(0, image.width - 1);
    final y = physicalCrop.top.toInt().clamp(0, image.height - 1);
    final w = physicalCrop.width.toInt().clamp(1, image.width - x);
    final h = physicalCrop.height.toInt().clamp(1, image.height - y);
    final crop = img.copyCrop(image, x: x, y: y, width: w, height: h);
    return base64Encode(img.encodeJpg(crop, quality: 85));
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