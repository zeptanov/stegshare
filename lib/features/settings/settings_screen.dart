import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/crypto/identity.dart';
import '../../core/errors.dart';
import '../../platform/file_access.dart';
import '../../presentation/design_system/components.dart';
import '../../presentation/platform_design/adaptive.dart';
import '../../presentation/platform_design/design_language.dart';
import 'settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final identity = ref.watch(identityProvider);
    final contacts = ref.watch(contactsProvider);

    return AdaptivePage(
      title: 'Settings',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Section(
            title: 'Design language',
            child: Panel(
              child: Column(children: [
                for (final l in DesignLanguage.values)
                  RadioListTile<DesignLanguage>(
                    dense: true,
                    title: Text(l.label),
                    value: l,
                    groupValue: s.designLanguage,
                    onChanged: (v) => ref
                        .read(settingsProvider.notifier)
                        .setDesignLanguage(v!),
                  ),
              ]),
            ),
          ),
          Section(
            title: 'Theme',
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('System')),
                ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ],
              selected: {s.themeMode},
              onSelectionChanged: (v) =>
                  ref.read(settingsProvider.notifier).setThemeMode(v.first),
            ),
          ),
          Section(
            title: 'My keys',
            child: Panel(
              child: identity.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Secure storage error: $e'),
                data: (id) => id == null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            const Text(
                                'No identity yet. Generate an X25519 + Ed25519 key pair; '
                                'private keys are stored in the platform secure storage.'),
                            const SizedBox(height: 10),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              AdaptivePrimaryButton(
                                label: 'Generate key pair',
                                icon: Icons.vpn_key_outlined,
                                onPressed: () async {
                                  final name = await _promptName(context);
                                  if (name != null) {
                                    await ref
                                        .read(identityProvider.notifier)
                                        .generate(name);
                                  }
                                },
                              ),
                              AdaptiveSecondaryButton(
                                label: 'Import private key',
                                icon: Icons.file_open_outlined,
                                onPressed: () => _importIdentity(
                                    context, ref, identity.valueOrNull),
                              ),
                            ]),
                          ])
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Text(id.name,
                                style: Theme.of(context).textTheme.titleMedium),
                            Text('Fingerprint: ${id.fingerprint}',
                                style:
                                    const TextStyle(fontFamily: 'monospace')),
                            const SizedBox(height: 8),
                            const Text('Share the public key via the QR tab.'),
                            const SizedBox(height: 10),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              AdaptivePrimaryButton(
                                label: 'Export private key',
                                icon: Icons.download_outlined,
                                onPressed: () => _exportIdentity(context, ref),
                              ),
                              AdaptiveSecondaryButton(
                                label: 'Import private key',
                                icon: Icons.file_open_outlined,
                                onPressed: () =>
                                    _importIdentity(context, ref, id),
                              ),
                            ]),
                            const SizedBox(height: 10),
                            AdaptiveSecondaryButton(
                              label: 'Delete identity',
                              icon: Icons.delete_outline,
                              onPressed: () async {
                                final ok = await showAdaptiveConfirm(
                                    context,
                                    'Delete identity?',
                                    'Containers encrypted for this key will become unreadable. This cannot be undone.',
                                    confirmLabel: 'Delete');
                                if (ok) {
                                  await ref
                                      .read(identityProvider.notifier)
                                      .delete();
                                }
                              },
                            ),
                          ]),
              ),
            ),
          ),
          Section(
            title: 'App protection',
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.appLockEnabled
                      ? 'App lock is on. The app locks when it goes to the background and when it is reopened.'
                      : 'Protect the app with a password. On supported devices, biometrics can be used to unlock it. '
                          'There is no password reset; export your private-key backup first.'),
                  const SizedBox(height: 10),
                  s.appLockEnabled
                      ? AdaptiveSecondaryButton(
                          label: 'Turn off app lock',
                          icon: Icons.lock_open_outlined,
                          onPressed: () async {
                            final ok = await showAdaptiveConfirm(
                              context,
                              'Turn off app lock?',
                              'The app will no longer require a password or biometrics.',
                              confirmLabel: 'Turn off',
                            );
                            if (!ok || !context.mounted) return;
                            try {
                              await ref
                                  .read(settingsProvider.notifier)
                                  .disableAppLock();
                            } catch (e) {
                              if (context.mounted) {
                                await showAdaptiveMessage(context,
                                    'Could not turn off app lock', '$e');
                              }
                            }
                          },
                        )
                      : AdaptivePrimaryButton(
                          label: 'Set app password',
                          icon: Icons.lock_outline,
                          onPressed: () async {
                            final password = await _promptPassword(context,
                                title: 'Set app password',
                                confirmPassword: true);
                            if (password == null || !context.mounted) return;
                            try {
                              await ref
                                  .read(settingsProvider.notifier)
                                  .enableAppLock(password);
                            } catch (e) {
                              if (context.mounted) {
                                await showAdaptiveMessage(
                                    context, 'Could not enable app lock', '$e');
                              }
                            }
                          },
                        ),
                ],
              ),
            ),
          ),
          Section(
            title: 'Contacts (public keys)',
            child: Panel(
              padding: EdgeInsets.zero,
              child: contacts.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: Text(
                          'No contacts. Import public keys from the QR tab.'))
                  : Column(children: [
                      for (final c in contacts)
                        ListTile(
                          dense: true,
                          title: Text(c.name),
                          subtitle: Text(c.fingerprint,
                              style: const TextStyle(fontFamily: 'monospace')),
                          trailing: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => ref
                                  .read(contactsProvider.notifier)
                                  .remove(c)),
                        ),
                    ]),
            ),
          ),
          const Section(
            title: 'About',
            child: Text(
              'STEGSHARE is local-first: no accounts, no servers, no telemetry. '
              'LSB steganography is detectable by statistical analysis and is destroyed by '
              'lossy re-encoding (JPEG, messengers). Encryption protects content, not the fact of hiding.',
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _promptName(BuildContext context) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Identity name'),
        content: TextField(
            controller: c,
            decoration: const InputDecoration(hintText: 'e.g. Alice')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text),
              child: const Text('Generate')),
        ],
      ),
    );
  }

  Future<void> _exportIdentity(BuildContext context, WidgetRef ref) async {
    final password = await _promptPassword(
      context,
      title: 'Encrypt private-key backup',
      confirmPassword: true,
    );
    if (password == null || !context.mounted) return;
    try {
      final bytes =
          await ref.read(identityProvider.notifier).exportBackup(password);
      final path = await FileAccess.saveBytes(
        'stegshare-identity.stegkey',
        bytes,
        extensions: const ['stegkey'],
      );
      if (path != null && context.mounted) {
        await showAdaptiveMessage(context, 'Backup exported',
            'Encrypted identity backup saved to $path');
      }
    } catch (e) {
      if (context.mounted) {
        await showAdaptiveMessage(context, 'Could not export key', '$e');
      }
    }
  }

  Future<void> _importIdentity(
    BuildContext context,
    WidgetRef ref,
    PublicIdentity? existing,
  ) async {
    try {
      final path = await FileAccess.pickFilePath(extensions: const ['stegkey']);
      if (path == null || !context.mounted) return;
      final password =
          await _promptPassword(context, title: 'Decrypt identity backup');
      if (password == null || !context.mounted) return;
      if (existing != null) {
        final replace = await showAdaptiveConfirm(
          context,
          'Replace current identity?',
          'The imported private key will replace the identity currently stored on this device.',
          confirmLabel: 'Replace',
        );
        if (!replace || !context.mounted) return;
      }
      await ref.read(identityProvider.notifier).importBackup(
            await FileAccess.readBytes(path),
            password,
          );
      if (context.mounted) {
        await showAdaptiveMessage(context, 'Identity imported',
            'The private key is stored securely on this device.');
      }
    } on DecryptionException {
      if (context.mounted) {
        await showAdaptiveMessage(context, 'Could not import key',
            'Incorrect backup password or damaged file.');
      }
    } catch (e) {
      if (context.mounted) {
        await showAdaptiveMessage(context, 'Could not import key', '$e');
      }
    }
  }

  Future<String?> _promptPassword(
    BuildContext context, {
    required String title,
    bool confirmPassword = false,
  }) {
    final password = TextEditingController();
    final confirmation = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        String? error;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'Password (at least 8 characters)'),
                ),
                if (confirmPassword)
                  TextField(
                    controller: confirmation,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'Confirm password'),
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(error!,
                        style:
                            TextStyle(color: Theme.of(ctx).colorScheme.error)),
                  ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  if (password.text.length < 8) {
                    setDialogState(() => error = 'Use at least 8 characters.');
                    return;
                  }
                  if (confirmPassword && password.text != confirmation.text) {
                    setDialogState(() => error = 'Passwords do not match.');
                    return;
                  }
                  Navigator.pop(ctx, password.text);
                },
                child: const Text('Continue'),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      password.dispose();
      confirmation.dispose();
    });
  }
}
