import 'dart:async';

import 'package:logger/logger.dart';

import '../webrtc/data_channel.dart';
import 'schema/input_messages.dart';

/// Gamepad input controller
/// Note: Flutter doesn't have built-in gamepad support yet.
/// This is a placeholder for future platform channel implementation.
class GamepadController {
  GamepadController({
    required this.dataChannelManager,
    this.pollInterval = const Duration(milliseconds: 16), // ~60Hz
  }) : _logger = Logger();

  final DataChannelManager dataChannelManager;
  final Duration pollInterval;
  final Logger _logger;

  Timer? _pollTimer;
  final List<GamepadState> _gamepadStates = [];

  /// Start gamepad polling
  void start() {
    if (_pollTimer != null) {
      _logger.w('Gamepad polling already started');
      return;
    }

    _logger.i('Starting gamepad polling');
    _pollTimer = Timer.periodic(pollInterval, (_) {
      _pollGamepads();
    });
  }

  /// Stop gamepad polling
  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _logger.i('Stopped gamepad polling');
  }

  /// Poll gamepad states
  void _pollGamepads() {
    // TODO: Implement platform channel to get gamepad state
    // This would require native code for each platform (Android, iOS, Windows, etc.)

    // Example of what the implementation would look like:
    for (var i = 0; i < _gamepadStates.length; i++) {
      final state = _gamepadStates[i];
      dataChannelManager.sendGamepadEvent(gamepadEvent: {
        'index': state.index,
        'axes': state.axes,
        'buttons': state.buttons,
      });
    }
  }

  /// Manually update gamepad state (for testing or custom input)
  void updateGamepadState({
    required int index,
    required List<double> axes,
    required List<bool> buttons,
  }) {
    final state = GamepadState(
      index: index,
      axes: axes,
      buttons: buttons,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    if (index < _gamepadStates.length) {
      _gamepadStates[index] = state;
    } else {
      _gamepadStates.add(state);
    }

    dataChannelManager.sendGamepadEvent(
      gamepadEvent: {'index': index, 'axes': axes, 'buttons': buttons},
    );
  }

  /// Dispose resources
  void dispose() {
    stop();
  }
}
