import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Known Flutter/Windows issue when the OS sends a Meta (Windows) key event
/// without matching modifier flags. Harmless but noisy in debug builds.
bool isKnownWindowsKeyboardAssertion(Object? error) {
  if (!Platform.isWindows) return false;
  final message = error.toString();
  return message.contains('keysPressed.isNotEmpty') &&
      message.contains('RawKeyDownEvent');
}

void handleFlutterFrameworkError(FlutterErrorDetails details) {
  if (isKnownWindowsKeyboardAssertion(details.exception)) {
    HardwareKeyboard.instance.syncKeyboardState();
    return;
  }
  FlutterError.presentError(details);
  debugPrint('Flutter error: ${details.exception}');
}
