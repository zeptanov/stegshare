import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/crypto/symmetric_cipher.dart';
import '../../platform/file_access.dart';
import '../../presentation/design_system/components.dart';
import '../../presentation/platform_design/adaptive.dart';
import '../settings/settings_controller.dart';
import 'hide_controller.dart';
import 'text_editor_page.dart';

class HideScreen extends ConsumerStatefulWidget {
  const HideScreen({super.key});
  @override
  ConsumerState<HideScreen> createState() => _HideScreenState();
}

class _HideScreenState extends ConsumerState<HideScreen> {
  bool _dragging = false;

  static const _imageExt = {
    'png',
    'jpg',
    'jpeg',
    'bmp',
    'webp',
    'gif',
    'tif',
    'tiff'
  };

  Future<void> _onDrop(List<String> paths) async {
    final c = ref.read(hideProvider.notifier);
    final images = paths
        .where((p) => _imageExt.contains(p.split('.').last.toLowerCase()))
        .toList();
    final hasImage = ref.read(hideProvider).image != null;
    if (!hasImage && images.isNotEmpty) {
      await c.setImagePath(images.first);
      await c.addFilePaths(paths.where((p) => p != images.first));
    } else {
      await c.addFilePaths(paths);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(hideProvider);
    final c = ref.read(hideProvider.notifier);
    final contacts = ref.watch(contactsProvider);
    final identity = ref.watch(identityProvider).valueOrNull;
    final t = Theme.of(context);

    Widget body = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Section(
          title: 'Cover image',
          trailing: s.image != null
              ? TextButton(
                  onPressed: s.busy
                      ? null
                      : () async {
                          final p = await FileAccess.pickImagePath();
                          if (p != null) c.setImagePath(p);
                        },
                  child: const Text('Change'))
              : null,
          child: s.image == null
              ? ImageDropZone(
                  highlighted: _dragging,
                  onPick: () async {
                    final p = await FileAccess.pickImagePath();
                    if (p != null) c.setImagePath(p);
                  })
              : Panel(
                  child: Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.memory(s.imageBytes!,
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                          gaplessPlayback: true),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.imagePath!.split(RegExp(r'[\\/]')).last,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.textTheme.titleSmall),
                            Text('${s.image!.width} × ${s.image!.height} px'),
                            Text(
                                'Capacity: ${formatBytes(s.capacity)}${s.keyed ? ' (scattered)' : ''}',
                                style: t.textTheme.bodySmall),
                            const SizedBox(height: 8),
                            CapacityBar(
                                used: s.estimatedSize, capacity: s.capacity),
                          ]),
                    ),
                  ]),
                ),
        ),
        Section(
          title: 'Payload',
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            TextButton.icon(
              onPressed: s.busy
                  ? null
                  : () async {
                      final r = await Navigator.push<TextEditorResult>(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const TextEditorPage()));
                      if (r != null && r.text.isNotEmpty)
                        c.addText(r.title, r.text);
                    },
              icon: const Icon(Icons.notes, size: 18),
              label: const Text('Add text'),
            ),
            TextButton.icon(
              onPressed: s.busy
                  ? null
                  : () async {
                      final files = await FileAccess.pickFiles();
                      c.addFilePaths(files.map((f) => f.path));
                    },
              icon: const Icon(Icons.attach_file, size: 18),
              label: const Text('Add files'),
            ),
          ]),
          child: Panel(
            padding: EdgeInsets.zero,
            child: s.items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                        'Nothing to hide yet. Add text messages or files.',
                        style: t.textTheme.bodyMedium?.copyWith(
                            color: t.colorScheme.onSurface.withOpacity(0.6))))
                : Column(children: [
                    for (final it in s.items)
                      ListTile(
                        dense: true,
                        leading: Icon(it.isText
                            ? Icons.notes
                            : Icons.insert_drive_file_outlined),
                        title: Text(it.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(formatBytes(it.size)),
                        onTap: it.isText && !s.busy
                            ? () async {
                                final r =
                                    await Navigator.push<TextEditorResult>(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => TextEditorPage(
                                                initialTitle: it.name
                                                    .replaceAll(
                                                        RegExp(r'\.txt$'), ''),
                                                initialText: it.text ?? '')));
                                if (r != null)
                                  c.updateText(it.id, r.title, r.text);
                              }
                            : null,
                        trailing: IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed:
                                s.busy ? null : () => c.removeItem(it.id)),
                      ),
                  ]),
          ),
        ),
        Section(
          title: 'Protection',
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SegmentedButton<ProtectionMode>(
              segments: const [
                ButtonSegment(
                    value: ProtectionMode.password,
                    label: Text('Password'),
                    icon: Icon(Icons.password)),
                ButtonSegment(
                    value: ProtectionMode.publicKey,
                    label: Text('Public key'),
                    icon: Icon(Icons.key)),
                ButtonSegment(
                    value: ProtectionMode.none,
                    label: Text('None'),
                    icon: Icon(Icons.lock_open)),
              ],
              selected: {s.mode},
              onSelectionChanged: s.busy ? null : (v) => c.setMode(v.first),
            ),
            const SizedBox(height: 12),
            if (s.mode == ProtectionMode.none)
              const WarningNote(
                  'Data will NOT be encrypted. Anyone who suspects an LSB container can read it. '
                  'Only integrity (CRC32 + SHA-256) is checked.',
                  danger: true),
            if (s.mode == ProtectionMode.password) ...[
              AdaptiveTextField(
                  placeholder: 'Password',
                  obscure: true,
                  onChanged: c.setPassword),
              const SizedBox(height: 6),
              Text(
                  'Key derived with Argon2id (32 MiB, 3 passes). Payload is encrypted with ${s.algorithm.label}.',
                  style: t.textTheme.bodySmall),
            ],
            if (s.mode == ProtectionMode.publicKey) ...[
              if (contacts.isEmpty)
                const WarningNote(
                    'No contacts. Import a recipient public key in the QR tab first.')
              else
                DropdownButtonFormField<String>(
                  value: s.recipient?.fingerprint,
                  decoration: const InputDecoration(labelText: 'Recipient'),
                  items: [
                    for (final k in contacts)
                      DropdownMenuItem(
                          value: k.fingerprint,
                          child: Text('${k.name} · ${k.fingerprint}')),
                  ],
                  onChanged: (fp) => c.setRecipient(
                      contacts.firstWhere((k) => k.fingerprint == fp)),
                ),
              const SizedBox(height: 6),
              Text(
                  'X25519 key agreement + HKDF wraps a random content key; payload uses ${s.algorithm.label}.',
                  style: t.textTheme.bodySmall),
            ],
            if (s.mode != ProtectionMode.none) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Expanded(child: Text('Cipher')),
                Container(
                  decoration: BoxDecoration(
                    color: t.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<EncryptionAlgorithm>(
                      value: s.algorithm,
                      items: const [
                        DropdownMenuItem(
                            value: EncryptionAlgorithm.aes256Gcm,
                            child: Text('AES-256-GCM')),
                        DropdownMenuItem(
                            value: EncryptionAlgorithm.chacha20Poly1305,
                            child: Text('ChaCha20-Poly1305')),
                      ],
                      onChanged: s.busy ? null : (v) => c.setAlgorithm(v!),
                    ),
                  ),
                ),
              ]),
              Row(children: [
                Expanded(
                    child: Text(identity == null
                        ? 'Sign with my key (no identity — see Settings)'
                        : 'Sign with my key (${identity.name})')),
                AdaptiveSwitch(
                    value: s.sign,
                    onChanged: identity == null || s.busy ? null : c.setSign),
              ]),
            ],
          ]),
        ),
        Section(
          title: 'Embedding',
          child: Panel(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AdaptiveTextField(
                  placeholder:
                      'Scatter key (optional) — pseudo-random bit positions',
                  onChanged: c.setScatterKey),
              const SizedBox(height: 4),
              Text(
                  'The recipient must enter the same scatter key. This hides the sequential layout but does not '
                  'defeat statistical steganalysis. Reduces capacity to 90%.',
                  style: t.textTheme.bodySmall),
              const SizedBox(height: 8),
              Row(children: [
                const Expanded(
                    child: Text('Compress payload (zlib) when it helps')),
                AdaptiveSwitch(
                    value: s.compress,
                    onChanged: s.busy ? null : c.setCompress),
              ]),
            ]),
          ),
        ),
        if (s.error != null) ...[
          WarningNote(s.error!, danger: true),
          const SizedBox(height: 12)
        ],
        if (s.savedPath != null) ...[
          Panel(
            child: Row(children: [
              Icon(Icons.check_circle_outline, color: t.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text('Saved: ${s.savedPath}')),
            ]),
          ),
          const SizedBox(height: 12),
        ],
        if (s.busy)
          ProgressRow(fraction: s.progress, stage: s.stage, onCancel: c.cancel)
        else
          AdaptivePrimaryButton(
            label: 'Hide & save PNG',
            icon: Icons.lock_outline,
            onPressed: s.canStart
                ? () async {
                    if (s.mode == ProtectionMode.none) {
                      final ok = await showAdaptiveConfirm(
                          context,
                          'No encryption',
                          'The payload will be stored in plain form. Continue?');
                      if (!ok) return;
                    }
                    c.start();
                  }
                : null,
          ),
        const SizedBox(height: 24),
      ],
    );

    if (FileAccess.isDesktop) {
      body = DropTarget(
        onDragEntered: (_) => setState(() => _dragging = true),
        onDragExited: (_) => setState(() => _dragging = false),
        onDragDone: (d) {
          setState(() => _dragging = false);
          _onDrop(d.files.map((f) => f.path).toList());
        },
        child: body,
      );
    }
    return AdaptivePage(title: 'Hide data', body: body);
  }
}
