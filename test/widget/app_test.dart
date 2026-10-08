import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stegshare/app.dart';
import 'package:stegshare/core/storage/key_store.dart';
import 'package:stegshare/features/settings/settings_controller.dart';
import 'package:stegshare/presentation/platform_design/design_language.dart';

void main() {
  testWidgets('app boots and switches design language without restart', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      keyStoreProvider.overrideWithValue(InMemoryKeyStore()),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const StegShareApp()));
    await tester.pumpAndSettle();
    expect(find.text('Hide data'), findsOneWidget);

    container.read(settingsProvider.notifier).setDesignLanguage(DesignLanguage.ios);
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(container.read(settingsProvider).designLanguage, DesignLanguage.ios);

    container.read(settingsProvider.notifier).setThemeMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).themeMode, ThemeMode.dark);
  });
}