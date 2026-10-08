import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
                    onChanged: (v) => ref.read(settingsProvider.notifier).setDesignLanguage(v!),
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
              onSelectionChanged: (v) => ref.read(settingsProvider.notifier).setThemeMode(v.first),
            ),
          ),
          Section(
            title: 'My keys',
            child: Panel(
              child: identity.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Secure storage error: $e'),
                data: (id) => id == null
                    ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('No identity yet. Generate an X25519 + Ed25519 key pair; '
                            'private keys are stored in the platform secure storage.'),
                        const SizedBox(height: 10),
                        AdaptivePrimaryButton(
                          label: 'Generate key pair',
                          icon: Icons.vpn_key_outlined,
                          onPressed: () async {
                            final name = await _promptName(context);
                            if (name != null) await ref.read(identityProvider.notifier).generate(name);
                          },
                        ),
                      ])
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(id.name, style: Theme.of(context).textTheme.titleMedium),
                        Text('Fingerprint: ${id.fingerprint}',
                            style: const TextStyle(fontFamily: 'monospace')),
                        const SizedBox(height: 8),
                        const Text('Share the public key via the QR tab.'),
                        const SizedBox(height: 10),
                        AdaptiveSecondaryButton(
                          label: 'Delete identity',
                          icon: Icons.delete_outline,
                          onPressed: () async {
                            final ok = await showAdaptiveConfirm(context, 'Delete identity?',
                                'Containers encrypted for this key will become unreadable. This cannot be undone.',
                                confirmLabel: 'Delete');
                            if (ok) await ref.read(identityProvider.notifier).delete();
                          },
                        ),
                      ]),
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
                      child: Text('No contacts. Import public keys from the QR tab.'))
                  : Column(children: [
                      for (final c in contacts)
                        ListTile(
                          dense: true,
                          title: Text(c.name),
                          subtitle: Text(c.fingerprint, style: const TextStyle(fontFamily: 'monospace')),
                          trailing: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => ref.read(contactsProvider.notifier).remove(c)),
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
        content: TextField(controller: c, decoration: const InputDecoration(hintText: 'e.g. Alice')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Generate')),
        ],
      ),
    );
  }
}