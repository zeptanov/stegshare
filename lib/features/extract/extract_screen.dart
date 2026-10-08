import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stegshare/domain/models.dart';

import '../../core/container/container_codec.dart';
import '../../core/container/container_format.dart';
import '../../domain/steg_pipeline.dart';
import '../../platform/file_access.dart';
import '../../presentation/design_system/components.dart';
import '../../presentation/platform_design/adaptive.dart';
import 'extract_controller.dart';

class ExtractScreen extends ConsumerWidget {
  const ExtractScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(extractProvider);
    final c = ref.read(extractProvider.notifier);
    final t = Theme.of(context);

    Widget body = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Section(
          title: 'Image',
          trailing: s.imageBytes != null
              ? TextButton(
                  onPressed: () async {
                    final p = await FileAccess.pickImagePath();
                    if (p != null) c.setImagePath(p);
                  },
                  child: const Text('Change'))
              : null,
          child: s.imageBytes == null
              ? ImageDropZone(onPick: () async {
                  final p = await FileAccess.pickImagePath();
                  if (p != null) c.setImagePath(p);
                })
              : Panel(
                  child: Row(children: [
                    ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.memory(s.imageBytes!, width: 72, height: 72, fit: BoxFit.cover)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(s.imagePath!, maxLines: 2, overflow: TextOverflow.ellipsis)),
                  ]),
                ),
        ),
        Section(
          title: 'Keys',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AdaptiveTextField(placeholder: 'Password (if any)', obscure: true, onChanged: c.setPassword),
            const SizedBox(height: 8),
            AdaptiveTextField(placeholder: 'Scatter key (if used)', onChanged: c.setScatterKey),
            const SizedBox(height: 4),
            Text('Public-key containers are decrypted automatically with your identity from Settings.',
                style: t.textTheme.bodySmall),
          ]),
        ),
        if (s.error != null) ...[WarningNote(s.error!, danger: !s.needsPassword), const SizedBox(height: 12)],
        if (s.busy)
          ProgressRow(fraction: s.progress, stage: s.stage, onCancel: c.cancel)
        else
          AdaptivePrimaryButton(
              label: 'Extract', icon: Icons.lock_open_outlined, onPressed: s.imageBytes == null ? null : c.extract),
        const SizedBox(height: 20),
        if (s.result != null) _ResultView(result: s.result!, lastSaved: s.lastSaved),
      ],
    );

    if (FileAccess.isDesktop) {
      body = DropTarget(
        onDragDone: (d) {
          if (d.files.isNotEmpty) c.setImagePath(d.files.first.path);
        },
        child: body,
      );
    }
    return AdaptivePage(title: 'Extract data', body: body);
  }
}

class _ResultView extends ConsumerWidget {
  final ExtractResult result;
  final String? lastSaved;
  const _ResultView({required this.result, this.lastSaved});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(extractProvider.notifier);
    final t = Theme.of(context);
    final modeText = switch (result.keyMode) {
      KeyMode.none => 'Not encrypted',
      KeyMode.password => 'Password · ${result.algorithm.label}',
      KeyMode.publicKey => 'Public key · ${result.algorithm.label}',
    };
    final sig = switch (result.signature) {
      SignatureStatus.none => 'Unsigned',
      SignatureStatus.valid => 'Signature valid · ${StegPipeline.fingerprintOf(result.signerPublicKey!)}',
      SignatureStatus.invalid => 'SIGNATURE INVALID',
    };
    return Section(
      title: 'Contents',
      trailing: TextButton.icon(onPressed: c.saveAll, icon: const Icon(Icons.folder_outlined, size: 18), label: const Text('Save all')),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(modeText),
            Text(sig,
                style: TextStyle(
                    color: result.signature == SignatureStatus.invalid ? t.colorScheme.error : null,
                    fontWeight: result.signature == SignatureStatus.invalid ? FontWeight.bold : null)),
            if (result.keyMode == KeyMode.none)
              const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: WarningNote('Unencrypted container: integrity verified by checksum only, not authenticated.')),
          ]),
        ),
        const SizedBox(height: 10),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (var i = 0; i < result.items.length; i++)
              ListTile(
                dense: true,
                leading: Icon(result.items[i].asText != null ? Icons.notes : Icons.insert_drive_file_outlined),
                title: Text(result.items[i].entry.name),
                subtitle: Text('${formatBytes(result.items[i].entry.size)} · ${result.items[i].entry.mime}'),
                onTap: result.items[i].asText != null
                    ? () => showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text(result.items[i].entry.name),
                            content: SingleChildScrollView(child: SelectableText(result.items[i].asText!)),
                            actions: [
                              TextButton(
                                  onPressed: () => Clipboard.setData(ClipboardData(text: result.items[i].asText!)),
                                  child: const Text('Copy')),
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                            ],
                          ),
                        )
                    : null,
                trailing: IconButton(icon: const Icon(Icons.download_outlined), onPressed: () => c.saveItem(i)),
              ),
          ]),
        ),
        if (lastSaved != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Saved: $lastSaved', style: t.textTheme.bodySmall)),
      ]),
    );
  }
}