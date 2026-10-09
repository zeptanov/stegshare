import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stegshare/app.dart';
import 'package:stegshare/core/storage/key_store.dart';
import 'package:stegshare/core/storage/app_lock_store.dart';
import 'package:stegshare/features/settings/settings_controller.dart';
import 'package:stegshare/presentation/design_system/app_theme.dart';
import 'package:stegshare/presentation/platform_design/adaptive.dart';
import 'package:stegshare/presentation/platform_design/design_language.dart';

void main() {
  test('all design themes use rounded, borderless fields and selectors', () {
    for (final language in DesignLanguage.values) {
      for (final brightness in Brightness.values) {
        final theme = AppTheme.build(language, brightness);
        final fieldBorder = theme.inputDecorationTheme.enabledBorder!;
        final selectorStyle = theme.segmentedButtonTheme.style!;

        expect(fieldBorder, isA<OutlineInputBorder>(),
            reason: '$language $brightness');
        expect(
          (fieldBorder as OutlineInputBorder).borderRadius,
          BorderRadius.circular(18),
          reason: '$language $brightness',
        );
        expect(fieldBorder.borderSide.style, BorderStyle.none,
            reason: '$language $brightness');
        expect(selectorStyle.side?.resolve({}), BorderSide.none,
            reason: '$language $brightness');
      }
    }
  });

  testWidgets('app boots and switches design language without restart',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      keyStoreProvider.overrideWithValue(InMemoryKeyStore()),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const StegShareApp()));
    await tester.pumpAndSettle();
    expect(find.text('Hide data'), findsOneWidget);

    container
        .read(settingsProvider.notifier)
        .setDesignLanguage(DesignLanguage.ios);
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(container.read(settingsProvider).designLanguage, DesignLanguage.ios);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byIcon(Icons.lock_open_outlined), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_2), findsOneWidget);
    expect(find.byIcon(Icons.tune), findsOneWidget);

    container
        .read(settingsProvider.notifier)
        .setDesignLanguage(DesignLanguage.liquidGlass);
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).designLanguage,
        DesignLanguage.liquidGlass);
    expect(find.byType(GlassTabBar), findsOneWidget);
    expect(find.byType(GlassScaffold), findsOneWidget);

    container.read(settingsProvider.notifier).setThemeMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).themeMode, ThemeMode.dark);
  });

  testWidgets('app lock keeps the app covered until the password is verified',
      (tester) async {
    SharedPreferences.setMockInitialValues({'security.appLockEnabled': true});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      keyStoreProvider.overrideWithValue(InMemoryKeyStore()),
      appLockStoreProvider.overrideWithValue(_TestAppLockStore()),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const StegShareApp()));
    await tester.pumpAndSettle();

    expect(find.text('Unlock STEGSHARE'), findsOneWidget);
    expect(find.text('Hide data'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'incorrect');
    await tester.tap(find.text('Unlock with password'));
    await tester.pumpAndSettle();
    expect(find.text('Incorrect password.'), findsOneWidget);
    expect(find.text('Hide data'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'correct123');
    await tester.tap(find.text('Unlock with password'));
    await tester.pumpAndSettle();
    expect(find.text('Unlock STEGSHARE'), findsNothing);
    expect(find.text('Hide data'), findsOneWidget);
  });

  testWidgets('iOS input and switch controls have soft, borderless styling',
      (tester) async {
    await tester.pumpWidget(
      DesignScope(
        language: DesignLanguage.ios,
        child: MaterialApp(
          theme: AppTheme.build(DesignLanguage.ios, Brightness.light),
          home: const Scaffold(
            body: Column(
              children: [
                AdaptiveTextField(placeholder: 'Password'),
                AdaptiveSwitch(value: true),
              ],
            ),
          ),
        ),
      ),
    );

    final input = tester.widget<CupertinoTextField>(
      find.byType(CupertinoTextField),
    );
    expect(input.decoration, isA<BoxDecoration>());
    expect((input.decoration as BoxDecoration).border, isNull);

    final toggle = tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch));
    expect(toggle.trackOutlineColor?.resolve({}), Colors.transparent);
  });
}

class _TestAppLockStore implements AppLockStore {
  @override
  Future<void> clear() async {}

  @override
  Future<void> setPassword(String password) async {}

  @override
  Future<bool> verifyPassword(String password) async =>
      password == 'correct123';
}
