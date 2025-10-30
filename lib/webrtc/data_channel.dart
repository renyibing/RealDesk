import 'dart:convert';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:logger/logger.dart';

/// Data channel manager for sending input events
class DataChannelManager {
  DataChannelManager({
    required RTCDataChannel? rtChannel,
    required RTCDataChannel? reliableChannel,
  })  : _rt = rtChannel,
        _reliable = reliableChannel,
        _logger = Logger();

  final RTCDataChannel? _rt;
  final RTCDataChannel? _reliable;
  final Logger _logger;

  static const int protoVersion = 1;

  RTCDataChannel? _choose(bool reliable) {
    if (reliable) {
      return _reliable ?? _rt;
    }
    return _rt ?? _reliable;
  }

  void _sendJson(Map<String, dynamic> msg, {bool reliable = false}) {
    final ch = _choose(reliable);
    if (ch == null) {
      _logger.w('DataChannel not available (reliable=$reliable)');
      return;
    }
    if (ch.state != RTCDataChannelState.RTCDataChannelOpen) {
      _logger.w('DataChannel not open (label=${ch.label}, state=${ch.state})');
      return;
    }
    try {
      final jsonString = jsonEncode(msg);
      ch.send(RTCDataChannelMessage(jsonString));
      _logger.d('DC(${ch.label}) <- ${msg['type']}');
    } catch (e) {
      _logger.e('Failed to send: $e');
    }
  }

  // --- Helpers (mask, timestamp) ---
  int _buttonsMaskFromList(List<String>? buttons) {
    if (buttons == null) return 0;
    int mask = 0;
    for (final b in buttons) {
      switch (b) {
        case 'left':
        case 'primary':
        case 'l':
          mask |= 1; // left
          break;
        case 'right':
        case 'secondary':
        case 'r':
          mask |= 4; // right (bit 2)
          break;
        case 'middle':
        case 'tertiary':
        case 'm':
          mask |= 2; // middle (bit 1)
          break;
        case 'back':
          mask |= 8;
          break;
        case 'forward':
          mask |= 16;
          break;
        default:
          break;
      }
    }
    return mask;
  }

  int _modsMask(Map<String, bool>? meta) {
    if (meta == null) return 0;
    int mask = 0;
    if (meta['ctrl'] == true) mask |= 1;
    if (meta['alt'] == true) mask |= 2;
    if (meta['shift'] == true) mask |= 4;
    if (meta['meta'] == true) mask |= 8;
    return mask;
  }

  // --- Event senders (flat JSON expected by receiver) ---

  void sendMouseAbs({
    required double x,
    required double y,
    required int displayW,
    required int displayH,
    List<String>? buttons,
  }) {
    _sendJson({
      'type': 'mouseAbs',
      'x': x,
      'y': y,
      'displayW': displayW,
      'displayH': displayH,
      'buttons': _buttonsMaskFromList(buttons),
      'ts': DateTime.now().millisecondsSinceEpoch,
      'protoVersion': protoVersion,
    });
  }

  void sendMouseRel({
    required double dx,
    required double dy,
    List<String>? buttons,
  }) {
    _sendJson({
      'type': 'mouseRel',
      'dx': dx,
      'dy': dy,
      'buttons': _buttonsMaskFromList(buttons),
      'ts': DateTime.now().millisecondsSinceEpoch,
      'protoVersion': protoVersion,
    });
  }

  void sendWheel({required double dx, required double dy}) {
    _sendJson({
      'type': 'mouseWheel',
      'dx': dx,
      'dy': dy,
      'ts': DateTime.now().millisecondsSinceEpoch,
      'protoVersion': protoVersion,
    });
  }

  void sendTouchEvent({required List<Map<String, dynamic>> touches}) {
    _sendJson({
      'type': 'touch',
      'touches': touches,
      'ts': DateTime.now().millisecondsSinceEpoch,
      'protoVersion': protoVersion,
    });
  }

  void sendGamepadEvent({required Map<String, dynamic> gamepadEvent}) {
    _sendJson({
      'type': 'gamepad',
      'event': gamepadEvent,
      'ts': DateTime.now().millisecondsSinceEpoch,
      'protoVersion': protoVersion,
    });
  }

  void sendKeyboard({
    required String key,
    required bool down,
    int code = 0,
    Map<String, bool>? meta,
  }) {
    _sendJson({
      'type': 'keyboard',
      'key': key,
      'code': code,
      'down': down,
      'mods': _modsMask(meta),
      'ts': DateTime.now().millisecondsSinceEpoch,
      'protoVersion': protoVersion,
    }, reliable: true);
  }

  // System commands use reliable channel
  void sendSystemCommand(String action) {
    _sendJson({
      'type': 'system',
      'action': action,
      'ts': DateTime.now().millisecondsSinceEpoch,
      'protoVersion': protoVersion,
    }, reliable: true);
  }

  void toggleMouseMode() => sendSystemCommand('toggle-abs-rel');
  void requestClipboardSync() => sendSystemCommand('clipboard-sync');
  void requestScreenshot() => sendSystemCommand('screenshot');
}
