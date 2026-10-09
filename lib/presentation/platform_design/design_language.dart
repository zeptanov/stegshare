import 'package:flutter/widgets.dart';

/// Design language is a pure UI concern, decoupled from the runtime platform.
enum DesignLanguage {
  automatic('Automatic'),
  ios('iOS'),
  android('Android'),
  windows('Windows'),
  custom('STEGSHARE'),
  liquidGlass('Liquid Glass');

  final String label;
  const DesignLanguage(this.label);

  DesignLanguage resolve(TargetPlatform platform) {
    if (this != automatic) return this;
    switch (platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return ios;
      case TargetPlatform.android:
        return android;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return custom;
    }
  }
}

class DesignScope extends InheritedWidget {
  final DesignLanguage language;
  const DesignScope({super.key, required this.language, required super.child});

  static DesignLanguage of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DesignScope>()?.language ??
      DesignLanguage.custom;

  @override
  bool updateShouldNotify(DesignScope old) => old.language != language;
}
