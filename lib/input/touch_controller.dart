import 'dart:ui' show Offset, Size;
import 'package:flutter/gestures.dart';
import 'package:logger/logger.dart';

import '../webrtc/data_channel.dart';

/// Touch input controller
class TouchController {
  TouchController({
    required this.dataChannelManager,
  }) : _logger = Logger();

  final DataChannelManager dataChannelManager;
  final Logger _logger;

  final Map<int, Offset> _activeTouches = {};

  /// Handle pointer down event
  void onPointerDown(PointerDownEvent event, Size viewSize) {
    _activeTouches[event.pointer] = event.localPosition;
    _sendTouchEvent(viewSize);
    _logger.d('Touch down: ${event.pointer} at ${event.localPosition}');
  }

  /// Handle pointer up event
  void onPointerUp(PointerUpEvent event, Size viewSize) {
    _activeTouches.remove(event.pointer);
    _sendTouchEvent(viewSize);
    _logger.d('Touch up: ${event.pointer}');
  }

  /// Handle pointer move event
  void onPointerMove(PointerMoveEvent event, Size viewSize) {
    _activeTouches[event.pointer] = event.localPosition;
    _sendTouchEvent(viewSize);
  }

  /// Handle pointer cancel event
  void onPointerCancel(PointerCancelEvent event, Size viewSize) {
    _activeTouches.remove(event.pointer);
    _sendTouchEvent(viewSize);
    _logger.d('Touch cancel: ${event.pointer}');
  }

  /// Send touch event with all active touches
  void _sendTouchEvent(Size viewSize) {
    final touches = _activeTouches.entries.map((entry) {
      final normalized = _normalizePosition(entry.value, viewSize);
      return {
        'id': entry.key,
        'x': normalized.dx,
        'y': normalized.dy,
        'pressure': 1.0,
      };
    }).toList();

    dataChannelManager.sendTouchEvent(touches: touches);
  }

  /// Normalize position to 0.0-1.0 range
  Offset _normalizePosition(Offset position, Size viewSize) {
    return Offset(
      (position.dx / viewSize.width).clamp(0.0, 1.0),
      (position.dy / viewSize.height).clamp(0.0, 1.0),
    );
  }

  /// Reset all touches
  void reset() {
    _activeTouches.clear();
  }
}
