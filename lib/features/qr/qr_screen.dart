import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/container/container_codec.dart';
import '../../core/container/manifest.dart';
import '../../core/crypto/kdf.dart';
import '../../core/errors.dart';
import '../../core/qr/stegshare_uri.dart';
import '../../presentation/design_system/components.dart';
import '../../presentation/platform_design/adaptive.dart';
import '../settings/settings_controller.dart';

class QrScreen extends ConsumerStatefulWidget {
  const QrScreen({super.key});
  @override
  ConsumerState<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends ConsumerState<QrScreen> {
  final _input = TextEditingController();
  final _msg = TextEditingController();
  final _msgPw = TextEditingController();
  String? _generatedMessageUri;
  String? _status;

  static bool get _canScan => Platform.isAndroid || Platform.isIOS;

  Future<void> _handleUri(String text) async {
    try {
      final payload = StegShareUri.parse(text);
      switch (payload) {
        case PublicKeyPayload(:final identity):
          final ok = await showAdaptiveConfirm(context, 'Import public key?',
              '${identity.name}\n${identity.fingerprint}\n\nVerify the fingerprint with the sender out-of-band.',
              confirmLabel: 'Import');
          if (ok) {
            await ref.read(contactsProvider.notifier).add(identity);
            setState(() => _status = 'Imported ${identity.name}.');
          }
        case MessagePayload(:final containerBytes):
          await _openMessage(containerBytes);
      }
    } on FormatException catch (e) {
      setState(() => _status = 'Invalid STEGSHARE URI: ${e.message}');
    }
  }

  Future<void> _openMessage(Uint8List bytes) async {
    final pwCtl = TextEditingController();
    final pw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Message password'),
        content: TextField(
            controller: pwCtl,
            obscureText: true,
            decoration: const InputDecoration(
                hintText: 'Password (leave empty if none)')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, pwCtl.text),
              child: const Text('Open')),
        ],
      ),
    );
    if (pw == null) return;
    try {
      final id = await ref.read(identityProvider.notifier).loadSecret();
      final d = await ContainerCodec().open(bytes,
          password: pw.isEmpty ? null : pw, recipientSeed: id?.x25519Seed);
      final text = d.items
          .map((i) => i.asText ?? '[${i.entry.name}, ${i.entry.size} bytes]')
          .join('\n\n');
      if (!mounted) return;
      await showAdaptiveMessage(context, 'Decoded message', text);
    } on StegShareException catch (e) {
      setState(() => _status = e.message);
    }
  }

  Future<void> _generateMessage() async {
    final text = _msg.text;
    if (text.isEmpty) return;
    try {
      // PBKDF2 is used here so that QR messages decode quickly; Argon2id remains the default for images.
      final spec = _msgPw.text.isEmpty
          ? const EncryptionSpec.none()
          : EncryptionSpec.password(_msgPw.text, kdf: KdfParams.fallbackPbkdf2);
      final bytes = await ContainerCodec().build(
        items: [
          PayloadInput(
              type: PayloadType.text,
              name: 'message.txt',
              mime: 'text/plain',
              data: Uint8List.fromList(utf8.encode(text)))
        ],
        spec: spec,
      );
      setState(() {
        _generatedMessageUri = StegShareUri.encodeMessage(bytes);
        _status = null;
      });
    } on FormatException {
      setState(() => _status =
          'Message too large for a QR code (limit ~2 KB after encryption).');
    } on StegShareException catch (e) {
      setState(() => _status = e.message);
    }
  }

  Future<void> _scan() async {
    final value = await Navigator.push<String>(
        context, MaterialPageRoute(builder: (_) => const _ScanPage()));
    if (value != null) await _handleUri(value);
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(identityProvider).valueOrNull;
    final t = Theme.of(context);
    return AdaptivePage(
      title: 'QR',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Section(
            title: 'My public key',
            child: Panel(
              child: identity == null
                  ? const Text(
                      'Generate an identity in Settings to share your public key.')
                  : Column(children: [
                      Center(
                        child: Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(8),
                          child: QrImageView(
                              data: StegShareUri.encodePublicIdentity(identity),
                              size: 200),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('${identity.name} · ${identity.fingerprint}',
                          style: const TextStyle(fontFamily: 'monospace')),
                      TextButton.icon(
                        onPressed: () => Clipboard.setData(ClipboardData(
                            text: StegShareUri.encodePublicIdentity(identity))),
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy as text'),
                      ),
                    ]),
            ),
          ),
          Section(
            title: 'Import / open',
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_canScan)
                    AdaptiveSecondaryButton(
                        label: 'Scan QR code',
                        icon: Icons.qr_code_scanner,
                        onPressed: _scan)
                  else
                    Text(
                        'Camera scanning on Windows is not implemented yet (TODO). Paste the STEGSHARE:// text below.',
                        style: t.textTheme.bodySmall),
                  const SizedBox(height: 8),
                  AdaptiveTextField(
                      controller: _input,
                      placeholder: 'STEGSHARE://…',
                      maxLines: 3),
                  const SizedBox(height: 8),
                  AdaptivePrimaryButton(
                      label: 'Process',
                      onPressed: () => _handleUri(_input.text)),
                ]),
          ),
          Section(
            title: 'Small encrypted message as QR',
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AdaptiveTextField(
                      controller: _msg,
                      placeholder: 'Short message',
                      maxLines: 3),
                  const SizedBox(height: 8),
                  AdaptiveTextField(
                      controller: _msgPw,
                      placeholder: 'Password (optional)',
                      obscure: true),
                  const SizedBox(height: 8),
                  AdaptiveSecondaryButton(
                      label: 'Generate QR',
                      icon: Icons.qr_code_2,
                      onPressed: _generateMessage),
                  if (_generatedMessageUri != null) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(8),
                        child: QrImageView(
                            data: _generatedMessageUri!,
                            size: 240,
                            errorCorrectionLevel: QrErrorCorrectLevel.L),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => Clipboard.setData(
                          ClipboardData(text: _generatedMessageUri!)),
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy URI'),
                    ),
                  ],
                ]),
          ),
          if (_status != null) WarningNote(_status!),
        ],
      ),
    );
  }
}

class _ScanPage extends StatefulWidget {
  const _ScanPage();
  @override
  State<_ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<_ScanPage> {
  bool _done = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan')),
      body: MobileScanner(
        errorBuilder: (context, error, child) {
          final message = switch (error.errorCode) {
            MobileScannerErrorCode.permissionDenied =>
              'Camera access is disabled. Allow camera access in your device settings, then try again.',
            MobileScannerErrorCode.unsupported =>
              'Camera scanning is not supported on this device.',
            _ => 'Could not start the camera.',
          };
          return ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.no_photography_outlined, size: 40),
                    const SizedBox(height: 12),
                    Text(message, textAlign: TextAlign.center),
                    if (error.errorDetails?.message case final details?)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          details,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
        onDetect: (capture) {
          if (_done) return;
          final v = capture.barcodes.firstOrNull?.rawValue;
          if (v != null) {
            _done = true;
            Navigator.pop(context, v);
          }
        },
      ),
    );
  }
}
