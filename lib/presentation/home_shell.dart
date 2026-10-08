import 'dart:ui';

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

  static const _pages = [
    HideScreen(),
    ExtractScreen(),
    QrScreen(),
    SettingsScreen()
  ];
  static const _items = [
    (Icons.lock_outline, 'Hide'),
    (Icons.lock_open_outlined, 'Extract'),
    (Icons.qr_code_2, 'QR'),
    (Icons.tune, 'Settings'),
  ];
  static const _iosItems = [
    (CupertinoIcons.lock, 'Hide'),
    (CupertinoIcons.lock_open, 'Extract'),
    (CupertinoIcons.qrcode, 'QR'),
    (CupertinoIcons.settings, 'Settings'),
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
              child: Text('STEG\nSHARE',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontWeight: FontWeight.w700, letterSpacing: 2)),
            ),
            destinations: [
              for (final it in _items)
                NavigationRailDestination(
                    icon: Icon(it.$1), label: Text(it.$2)),
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
        bottomNavigationBar: _IosTabBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          items: _iosItems,
        ),
      );
    }
    return Scaffold(
      body: page,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final it in _items)
            NavigationDestination(icon: Icon(it.$1), label: it.$2)
        ],
      ),
    );
  }
}

class _IosTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<(IconData, String)> items;

  const _IosTabBar(
      {required this.currentIndex, required this.onTap, required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface
                  .withValues(alpha: dark ? 0.84 : 0.76),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.24 : 0.1),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _IosTabButton(
                      icon: items[i].$1,
                      label: items[i].$2,
                      selected: i == currentIndex,
                      onTap: () => onTap(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IosTabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _IosTabButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.62);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 21, color: color),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : null)),
        ],
      ),
    );
  }
}
