import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../features/extract/extract_screen.dart';
import '../features/hide/hide_screen.dart';
import '../features/qr/qr_screen.dart';
import '../features/settings/settings_screen.dart';
import 'platform_design/design_language.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = [HideScreen(), ExtractScreen(), QrScreen(), SettingsScreen()];
  static const _items = [
    (Icons.lock_outline, 'Hide'),
    (Icons.lock_open_outlined, 'Extract'),
    (Icons.qr_code_2, 'QR'),
    (Icons.tune, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final lang = DesignScope.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final page = IndexedStack(index: _index, children: _pages);

    if (wide && lang != DesignLanguage.ios) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('STEG\nSHARE', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 2)),
            ),
            destinations: [
              for (final it in _items) NavigationRailDestination(icon: Icon(it.$1), label: Text(it.$2)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: page),
        ]),
      );
    }
    if (lang == DesignLanguage.ios) {
      return Scaffold(
        body: page,
        bottomNavigationBar: CupertinoTabBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          items: [for (final it in _items) BottomNavigationBarItem(icon: Icon(it.$1), label: it.$2)],
        ),
      );
    }
    return Scaffold(
      body: page,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [for (final it in _items) NavigationDestination(icon: Icon(it.$1), label: it.$2)],
      ),
    );
  }
}