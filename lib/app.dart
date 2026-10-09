import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/settings/settings_controller.dart';
import 'presentation/app_lock_gate.dart';
import 'presentation/design_system/app_theme.dart';
import 'presentation/home_shell.dart';
import 'presentation/platform_design/design_language.dart';

class StegShareApp extends ConsumerWidget {
  const StegShareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final resolved = settings.designLanguage.resolve(defaultTargetPlatform);
    return DesignScope(
      language: resolved,
      child: MaterialApp(
        title: 'STEGSHARE',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(resolved, Brightness.light),
        darkTheme: AppTheme.build(resolved, Brightness.dark),
        themeMode: settings.themeMode,
        home: const AppLockGate(child: HomeShell()),
      ),
    );
  }
}