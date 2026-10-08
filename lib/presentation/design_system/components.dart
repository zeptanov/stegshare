import 'package:flutter/material.dart';

import '../platform_design/design_language.dart';

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
}

class Section extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const Section(
      {super.key, required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final ios = DesignScope.of(context) == DesignLanguage.ios;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
              child: Text(ios ? title : title.toUpperCase(),
                  style:
                      (ios ? t.textTheme.titleSmall : t.textTheme.labelMedium)
                          ?.copyWith(
                              letterSpacing: ios ? 0.1 : 1.2,
                              color: t.colorScheme.onSurface
                                  .withValues(alpha: ios ? 0.72 : 0.6)))),
          if (trailing != null) trailing!,
        ]),
        const SizedBox(height: 8),
        child,
      ]),
    );
  }
}

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const Panel(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final radius =
        (t.cardTheme.shape as RoundedRectangleBorder?)?.borderRadius ??
            BorderRadius.circular(8);
    return Material(
      color: t.colorScheme.surface,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

class CapacityBar extends StatelessWidget {
  final int used;
  final int capacity;
  const CapacityBar({super.key, required this.used, required this.capacity});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final ratio = capacity == 0 ? 1.0 : (used / capacity).clamp(0.0, 1.0);
    final over = used > capacity;
    final color = over
        ? t.colorScheme.error
        : (ratio > 0.85 ? Colors.orange.shade700 : t.colorScheme.primary);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            color: color,
            backgroundColor: t.colorScheme.surfaceContainerHighest),
      ),
      const SizedBox(height: 6),
      Text(
        over
            ? 'Exceeds capacity by ${formatBytes(used - capacity)}'
            : '${formatBytes(used)} of ${formatBytes(capacity)} (${(ratio * 100).toStringAsFixed(0)}%)',
        style: t.textTheme.bodySmall
            ?.copyWith(color: over ? t.colorScheme.error : null),
      ),
    ]);
  }
}

class WarningNote extends StatelessWidget {
  final String text;
  final bool danger;
  const WarningNote(this.text, {super.key, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = danger ? t.colorScheme.error : Colors.orange.shade800;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: c.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(6),
        color: c.withValues(alpha: 0.08),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.warning_amber_rounded, size: 18, color: c),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: t.textTheme.bodySmall)),
      ]),
    );
  }
}

class ProgressRow extends StatelessWidget {
  final double fraction;
  final String stage;
  final VoidCallback onCancel;
  const ProgressRow(
      {super.key,
      required this.fraction,
      required this.stage,
      required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(stage, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: fraction),
        ]),
      ),
      const SizedBox(width: 12),
      TextButton(onPressed: onCancel, child: const Text('Cancel')),
    ]);
  }
}

class ImageDropZone extends StatelessWidget {
  final VoidCallback onPick;
  final bool highlighted;
  const ImageDropZone(
      {super.key, required this.onPick, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final ios = DesignScope.of(context) == DesignLanguage.ios;
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(ios ? 20 : 8),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: highlighted
              ? t.colorScheme.primary.withValues(alpha: 0.08)
              : t.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(ios ? 20 : 8),
          border: highlighted
              ? Border.all(color: t.colorScheme.primary, width: 2)
              : null,
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.image_outlined,
              size: 32, color: t.colorScheme.onSurface.withValues(alpha: 0.6)),
          const SizedBox(height: 8),
          const Text('Open image'),
          Text('PNG, JPEG, BMP · output is always PNG',
              style: t.textTheme.bodySmall),
        ]),
      ),
    );
  }
}
