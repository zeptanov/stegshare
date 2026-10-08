import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stegshare/app.dart';
import 'package:stegshare/core/storage/key_store.dart';
import 'package:stegshare/features/settings/settings_controller.dart';
import 'package:stegshare/presentation/design_system/app_theme.dart';
import 'package:stegshare/presentation/platform_design/adaptive.dart';
import 'package:stegshare/presentation/platform_design/design_language.dart';

void main() {
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

    container.read(settingsProvider.notifier).setThemeMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).themeMode, ThemeMode.dark);
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
    expect(
      (input.decoration as BoxDecoration).borderRadius,
      BorderRadius.circular(20),
    );

    final materialInputBorder = AppTheme.build(
      DesignLanguage.ios,
      Brightness.light,
    ).inputDecorationTheme.border;
    expect(materialInputBorder, isA<OutlineInputBorder>());
    expect(
      (materialInputBorder as OutlineInputBorder).borderRadius,
      BorderRadius.circular(20),
    );

    final toggle = tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch));
    expect(toggle.trackOutlineColor?.resolve({}), Colors.transparent);
  });
}
