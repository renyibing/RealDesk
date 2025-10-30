import 'package:flutter/services.dart' as services;
import 'package:logger/logger.dart';

import '../webrtc/data_channel.dart';
import 'schema/input_messages.dart';

/// Keyboard input controller
class KeyboardController {
  KeyboardController({required this.dataChannelManager}) : _logger = Logger();

  final DataChannelManager dataChannelManager;
  final Logger _logger;

  final Set<services.LogicalKeyboardKey> _pressedKeys = {};

  /// Handle key event
  bool handleKeyEvent(services.KeyEvent event) {
    if (event is services.KeyDownEvent) {
      return _handleKeyDown(event);
    } else if (event is services.KeyUpEvent) {
      return _handleKeyUp(event);
    } else if (event is services.KeyRepeatEvent) {
      return _handleKeyRepeat(event);
    }
    return false;
  }

  bool _handleKeyDown(services.KeyDownEvent event) {
    _pressedKeys.add(event.logicalKey);

    final modifiers = _getModifiers();
    final keyName = _deriveKeyName(event.logicalKey, event.character);
    final code = _deriveKeyCode(event.logicalKey, keyName);

    dataChannelManager.sendKeyboard(
      key: keyName,
      down: true,
      code: code,
      meta: {
        'ctrl': modifiers.ctrl,
        'alt': modifiers.alt,
        'shift': modifiers.shift,
        'meta': modifiers.meta,
      },
    );

    _logger.d('Key down: ${event.logicalKey.keyLabel}');
    return true;
  }

  bool _handleKeyUp(services.KeyUpEvent event) {
    _pressedKeys.remove(event.logicalKey);

    final modifiers = _getModifiers();
    final keyName = _deriveKeyName(event.logicalKey, event.character);
    final code = _deriveKeyCode(event.logicalKey, keyName);

    dataChannelManager.sendKeyboard(
      key: keyName,
      down: false,
      code: code,
      meta: {
        'ctrl': modifiers.ctrl,
        'alt': modifiers.alt,
        'shift': modifiers.shift,
        'meta': modifiers.meta,
      },
    );

    _logger.d('Key up: ${event.logicalKey.keyLabel}');
    return true;
  }

  bool _handleKeyRepeat(services.KeyRepeatEvent event) {
    // For repeat events, we can choose to ignore or send as down events
    return true;
  }

  /// Get current keyboard modifiers
  KeyboardModifiers _getModifiers() {
    return KeyboardModifiers(
      ctrl:
          _pressedKeys.contains(services.LogicalKeyboardKey.controlLeft) ||
          _pressedKeys.contains(services.LogicalKeyboardKey.controlRight),
      alt:
          _pressedKeys.contains(services.LogicalKeyboardKey.altLeft) ||
          _pressedKeys.contains(services.LogicalKeyboardKey.altRight),
      shift:
          _pressedKeys.contains(services.LogicalKeyboardKey.shiftLeft) ||
          _pressedKeys.contains(services.LogicalKeyboardKey.shiftRight),
      meta:
          _pressedKeys.contains(services.LogicalKeyboardKey.metaLeft) ||
          _pressedKeys.contains(services.LogicalKeyboardKey.metaRight),
    );
  }

  /// Reset all pressed keys
  void reset() {
    _pressedKeys.clear();
  }

  String _deriveKeyName(
    services.LogicalKeyboardKey logicalKey,
    String? character,
  ) {
    if (character != null && character.isNotEmpty) {
      return character;
    }

    final label = logicalKey.keyLabel;
    if (label.isNotEmpty) {
      return label;
    }

    final debugName = logicalKey.debugName ?? '';
    if (debugName.isEmpty) {
      return 'Unknown';
    }

    // Normalize common debug names ("Key A", "Digit 1", "Arrow Left")
    if (debugName.startsWith('Key ')) {
      return debugName.substring(4);
    }
    if (debugName.startsWith('Digit ')) {
      return debugName.substring(6);
    }
    if (debugName.startsWith('Numpad ')) {
      return debugName.substring(7);
    }
    if (debugName.startsWith('Arrow ')) {
      return debugName.replaceAll(' ', '');
    }
    return debugName;
  }

  int _deriveKeyCode(services.LogicalKeyboardKey logicalKey, String keyName) {
    // Map printable ASCII from normalized key name
    if (keyName.length == 1) {
      final intCode = keyName.toUpperCase().codeUnitAt(0);
      if (intCode >= 32 && intCode <= 126) {
        return intCode;
      }
    }

    final mapping = <services.LogicalKeyboardKey, int>{
      services.LogicalKeyboardKey.enter: 13, // SDLK_RETURN
      services.LogicalKeyboardKey.tab: 9, // SDLK_TAB
      services.LogicalKeyboardKey.space: 32, // SDLK_SPACE
      services.LogicalKeyboardKey.backspace: 8, // SDLK_BACKSPACE
      services.LogicalKeyboardKey.escape: 27, // SDLK_ESCAPE
      services.LogicalKeyboardKey.arrowUp: 1073741906, // SDLK_UP
      services.LogicalKeyboardKey.arrowDown: 1073741905, // SDLK_DOWN
      services.LogicalKeyboardKey.arrowLeft: 1073741904, // SDLK_LEFT
      services.LogicalKeyboardKey.arrowRight: 1073741903, // SDLK_RIGHT
      services.LogicalKeyboardKey.home: 1073741898,
      services.LogicalKeyboardKey.end: 1073741901,
      services.LogicalKeyboardKey.pageUp: 1073741899,
      services.LogicalKeyboardKey.pageDown: 1073741900,
      services.LogicalKeyboardKey.delete: 127,
      services.LogicalKeyboardKey.insert: 1073741897,
      services.LogicalKeyboardKey.shiftLeft: 1073742049,
      services.LogicalKeyboardKey.shiftRight: 1073742053,
      services.LogicalKeyboardKey.controlLeft: 1073742048,
      services.LogicalKeyboardKey.controlRight: 1073742052,
      services.LogicalKeyboardKey.altLeft: 1073742050,
      services.LogicalKeyboardKey.altRight: 1073742054,
      services.LogicalKeyboardKey.metaLeft: 1073742051,
      services.LogicalKeyboardKey.metaRight: 1073742055,
    };

    final mapped = mapping[logicalKey];
    if (mapped != null) {
      return mapped;
    }

    return 0;
  }
}
