import 'dart:async';
import 'package:flutter/services.dart';

enum ShakeSensitivity { low, medium, high }

class ShakeDetectorService {
  static const MethodChannel _channel = MethodChannel('magisor/mouse_hook');
  
  bool _isListening = false;
  Function(double x, double y)? onShakeDetected;
  
  ShakeSensitivity sensitivity = ShakeSensitivity.medium;
  
  List<_MousePoint> _points = [];
  int _lastDirection = 0;
  int _reversals = 0;
  DateTime? _lastTriggerTime;

  Future<void> start() async {
    if (_isListening) return;
    _isListening = true;
    _channel.setMethodCallHandler(_handleNativeCall);
    try {
      await _channel.invokeMethod('startListening');
    } catch (e) {
      // Native side might not be implemented yet on all platforms
      print("Warning: Failed to start native mouse hook: $e");
    }
  }

  Future<void> stop() async {
    if (!_isListening) return;
    _isListening = false;
    _channel.setMethodCallHandler(null);
    try {
      await _channel.invokeMethod('stopListening');
    } catch (e) {
      print("Warning: Failed to stop native mouse hook: $e");
    }
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onMouseMoved') {
      final args = call.arguments as Map<dynamic, dynamic>;
      _processPoint(args['x'] as double, args['y'] as double);
    }
  }

  void _processPoint(double x, double y) {
    final now = DateTime.now();

    // 1500ms cooldown
    if (_lastTriggerTime != null && now.difference(_lastTriggerTime!).inMilliseconds < 1500) {
      _points.clear();
      _reversals = 0;
      return;
    }

    _points.add(_MousePoint(x, y, now));

    // Rolling 400ms window
    _points.removeWhere((p) => now.difference(p.time).inMilliseconds > 400);

    if (_points.length < 2) return;

    int requiredReversals = 3;
    double minDistance = 20.0;
    
    switch (sensitivity) {
      case ShakeSensitivity.low:
        requiredReversals = 5;
        minDistance = 30.0;
        break;
      case ShakeSensitivity.medium:
        requiredReversals = 3;
        minDistance = 20.0;
        break;
      case ShakeSensitivity.high:
        requiredReversals = 2;
        minDistance = 15.0;
        break;
    }

    final current = _points.last;
    final previous = _points[_points.length - 2];
    
    final dx = current.x - previous.x;
    
    if (dx.abs() > minDistance) {
      int newDirection = dx > 0 ? 1 : -1;
      
      if (_lastDirection != 0 && newDirection != _lastDirection) {
        _reversals++;
      }
      
      _lastDirection = newDirection;
      
      if (_reversals >= requiredReversals) {
        _lastTriggerTime = now;
        _points.clear();
        _reversals = 0;
        _lastDirection = 0;
        
        if (onShakeDetected != null) {
          onShakeDetected!(current.x, current.y);
        }
      }
    }
  }
}

class _MousePoint {
  final double x;
  final double y;
  final DateTime time;
  _MousePoint(this.x, this.y, this.time);
}