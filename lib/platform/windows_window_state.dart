import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

class WindowsWindowState extends WindowListener {
  static const _sizePreferenceKey = 'windows_window_size';
  static const _defaultSize = Size(1280, 720);
  static const _minimumSize = Size(640, 480);

  final SharedPreferences _preferences;

  WindowsWindowState._(this._preferences);

  static Future<void> initialize(SharedPreferences preferences) async {
    await windowManager.ensureInitialized();
    final state = WindowsWindowState._(preferences);
    final size = state._readSavedSize();

    await windowManager.setMinimumSize(_minimumSize);
    await windowManager.setSize(size);
    windowManager.addListener(state);
  }

  Size _readSavedSize() {
    final saved = _preferences.getString(_sizePreferenceKey);
    if (saved == null) return _defaultSize;

    final dimensions = saved.split(',');
    if (dimensions.length == 2) {
      final width = double.tryParse(dimensions[0]);
      final height = double.tryParse(dimensions[1]);
      if (width != null &&
          height != null &&
          width.isFinite &&
          height.isFinite &&
          width >= _minimumSize.width &&
          height >= _minimumSize.height) {
        return Size(width, height);
      }
    }

    debugPrint('Ignoring invalid saved Windows window size.');
    return _defaultSize;
  }

  @override
  void onWindowResized() {
    unawaited(_saveCurrentSize());
  }

  Future<void> _saveCurrentSize() async {
    final size = await windowManager.getSize();
    if (!size.width.isFinite ||
        !size.height.isFinite ||
        size.width < _minimumSize.width ||
        size.height < _minimumSize.height) {
      return;
    }

    final saved = await _preferences.setString(
      _sizePreferenceKey,
      '${size.width},${size.height}',
    );
    if (!saved) {
      throw StateError('Could not save the Windows window size.');
    }
  }
}
