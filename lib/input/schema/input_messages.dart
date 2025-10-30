/// Mouse mode
enum MouseMode { absolute, relative }

/// Mouse button
enum MouseButton {
  left('left'),
  middle('middle'),
  right('right'),
  back('back'),
  forward('forward');

  const MouseButton(this.value);
  final String value;
}

/// Keyboard modifiers
class KeyboardModifiers {
  KeyboardModifiers({
    this.ctrl = false,
    this.alt = false,
    this.shift = false,
    this.meta = false,
  });

  final bool ctrl;
  final bool alt;
  final bool shift;
  final bool meta;

  int toBitmask() {
    int mods = 0;
    if (ctrl) mods |= 1;
    if (alt) mods |= 2;
    if (shift) mods |= 4;
    if (meta) mods |= 8;
    return mods;
  }
}

/// Gamepad state
class GamepadState {
  GamepadState({
    this.index = 0,
    this.axes = const [],
    this.buttons = const [],
    this.timestamp = 0,
  });

  final int index;
  final List<double> axes;
  final List<bool> buttons;
  final int timestamp;
}
