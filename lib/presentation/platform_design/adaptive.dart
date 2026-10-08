 import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'design_language.dart';

bool _isIos(BuildContext c) => DesignScope.of(c) == DesignLanguage.ios;

class AdaptivePage extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget> actions;
  const AdaptivePage(
      {super.key,
      required this.title,
      required this.body,
      this.actions = const []});

  @override
  Widget build(BuildContext context) {
    if (_isIos(context)) {
      return Scaffold(
        appBar: CupertinoNavigationBar(
          middle: Text(title),
          trailing: actions.isEmpty
              ? null
              : Row(mainAxisSize: MainAxisSize.min, children: actions),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          border: null,
        ),
        body: SafeArea(child: body),
      );
    }
    return Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        body: SafeArea(child: body));
  }
}

class AdaptivePrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  const AdaptivePrimaryButton(
      {super.key, required this.label, this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) {
    final child = Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
      Text(label),
    ]);
    if (_isIos(context)) {
      return CupertinoButton.filled(
          onPressed: onPressed,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: child);
    }
    return FilledButton(onPressed: onPressed, child: child);
  }
}

class AdaptiveSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  const AdaptiveSecondaryButton(
      {super.key, required this.label, this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) {
    final child = Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
      Text(label),
    ]);
    if (_isIos(context)) {
      return CupertinoButton(onPressed: onPressed, child: child);
    }
    return OutlinedButton(onPressed: onPressed, child: child);
  }
}

class AdaptiveSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const AdaptiveSwitch({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    if (!_isIos(context)) {
      return Switch(value: value, onChanged: onChanged);
    }
    final colors = Theme.of(context).colorScheme;
    return CupertinoSwitch(
      value: value,
      onChanged: onChanged,
      activeTrackColor: colors.primary,
      inactiveTrackColor: colors.onSurface.withValues(alpha: 0.16),
      thumbColor: colors.surface,
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    );
  }
}

class AdaptiveTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String placeholder;
  final bool obscure;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  const AdaptiveTextField({
    super.key,
    this.controller,
    required this.placeholder,
    this.obscure = false,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (_isIos(context)) {
      return CupertinoTextField(
        controller: controller,
        placeholder: placeholder,
        obscureText: obscure,
        maxLines: maxLines,
        onChanged: onChanged,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        cursorColor: Theme.of(context).colorScheme.primary,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 16,
        ),
        placeholderStyle: TextStyle(
          color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.42),
          fontSize: 16,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
      );
    }
    return TextField(
      controller: controller,
      obscureText: obscure,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(hintText: placeholder),
    );
  }
}

Future<void> showAdaptiveMessage(
    BuildContext context, String title, String message) {
  if (_isIos(context)) {
    return showCupertinoDialog(
      context: context,
      builder: (c) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
              onPressed: () => Navigator.pop(c), child: const Text('OK'))
        ],
      ),
    );
  }
  return showDialog(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))
      ],
    ),
  );
}

Future<bool> showAdaptiveConfirm(
    BuildContext context, String title, String message,
    {String confirmLabel = 'Continue'}) async {
  final r = _isIos(context)
      ? await showCupertinoDialog<bool>(
          context: context,
          builder: (c) => CupertinoAlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              CupertinoDialogAction(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('Cancel')),
              CupertinoDialogAction(
                  isDestructiveAction: true,
                  onPressed: () => Navigator.pop(c, true),
                  child: Text(confirmLabel)),
            ],
          ),
        )
      : await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: Text(confirmLabel)),
            ],
          ),
        );
  return r ?? false;
}
