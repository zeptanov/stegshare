import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/container/container_codec.dart';
import '../../core/crypto/identity.dart';
import '../../core/crypto/symmetric_cipher.dart';
import '../../core/errors.dart';
import '../../core/util/cancellation.dart';
import '../../domain/models.dart';
import '../../platform/file_access.dart';
import '../settings/settings_controller.dart';

enum ProtectionMode { none, password, publicKey }

class PayloadDraft {
  final String id;
  final bool isText;
  final String name;
  final String? text;
  final String? path;
  final int size;
  const PayloadDraft({
    required this.id,
    required this.isText,
    required this.name,
    this.text,
    this.path,
    required this.size,
  });
}

class HideState {
  final String? imagePath;
  final Uint8List? imageBytes;
  final ImageInspection? image;
  final List<PayloadDraft> items;
  final ProtectionMode mode;
  final String password;
  final EncryptionAlgorithm algorithm;
  final PublicIdentity? recipient;
  final bool sign;
  final String scatterKey;
  final bool compress;
  final bool busy;
  final double progress;
  final String stage;
  final String? error;
  final String? savedPath;

  const HideState({
    this.imagePath,
    this.imageBytes,
    this.image,
    this.items = const [],
    this.mode = ProtectionMode.password,
    this.password = '',
    this.algorithm = EncryptionAlgorithm.aes256Gcm,
    this.recipient,
    this.sign = false,
    this.scatterKey = '',
    this.compress = true,
    this.busy = false,
    this.progress = 0,
    this.stage = '',
    this.error,
    this.savedPath,
  });

  bool get keyed => scatterKey.isNotEmpty;
  int get capacity => image == null ? 0 : (keyed ? image!.capacityKeyed : image!.capacitySequential);

  /// Rough container size: header/crypto overhead + per-entry manifest JSON.
  int get estimatedSize => items.isEmpty ? 0 : 160 + items.fold(0, (s, i) => s + i.size + 200);

  bool get canStart =>
      !busy &&
      image != null &&
      items.isNotEmpty &&
      estimatedSize <= capacity &&
      (mode != ProtectionMode.password || password.isNotEmpty) &&
      (mode != ProtectionMode.publicKey || recipient != null);

  HideState copyWith({
    String? imagePath,
    Uint8List? imageBytes,
    ImageInspection? image,
    List<PayloadDraft>? items,
    ProtectionMode? mode,
    String? password,
    EncryptionAlgorithm? algorithm,
    PublicIdentity? recipient,
    bool clearRecipient = false,
    bool? sign,
    String? scatterKey,
    bool? compress,
    bool? busy,
    double? progress,
    String? stage,
    String? error,
    bool clearError = false,
    String? savedPath,
    bool clearSaved = false,
  }) =>
      HideState(
        imagePath: imagePath ?? this.imagePath,
        imageBytes: imageBytes ?? this.imageBytes,
        image: image ?? this.image,
        items: items ?? this.items,
        mode: mode ?? this.mode,
        password: password ?? this.password,
        algorithm: algorithm ?? this.algorithm,
        recipient: clearRecipient ? null : (recipient ?? this.recipient),
        sign: sign ?? this.sign,
        scatterKey: scatterKey ?? this.scatterKey,
        compress: compress ?? this.compress,
        busy: busy ?? this.busy,
        progress: progress ?? this.progress,
        stage: stage ?? this.stage,
        error: clearError ? null : (error ?? this.error),
        savedPath: clearSaved ? null : (savedPath ?? this.savedPath),
      );
}

class HideController extends Notifier<HideState> {
  CancellationToken? _token;
  int _seq = 0;

  @override
  HideState build() => const HideState();

  Future<void> setImagePath(String path) async {
    state = state.copyWith(busy: true, stage: 'Inspecting image', clearError: true, clearSaved: true);
    try {
      final bytes = await FileAccess.readBytes(path);
      final info = await ref.read(stegServiceProvider).inspectImage(bytes);
      state = state.copyWith(imagePath: path, imageBytes: bytes, image: info, busy: false, stage: '');
    } on StegShareException catch (e) {
      state = state.copyWith(busy: false, stage: '', error: e.message);
    } catch (e) {
      state = state.copyWith(busy: false, stage: '', error: 'Could not open image.');
    }
  }

  void addText(String title, String text) {
    final name = title.trim().isEmpty ? 'message-${_seq + 1}.txt' : '${title.trim()}.txt';
    state = state.copyWith(items: [
      ...state.items,
      PayloadDraft(id: '${_seq++}', isText: true, name: name, text: text, size: utf8.encode(text).length),
    ], clearSaved: true);
  }

  void updateText(String id, String title, String text) {
    final name = title.trim().isEmpty ? 'message.txt' : '${title.trim()}.txt';
    state = state.copyWith(items: [
      for (final it in state.items)
        if (it.id == id)
          PayloadDraft(id: id, isText: true, name: name, text: text, size: utf8.encode(text).length)
        else
          it,
    ]);
  }

  Future<void> addFilePaths(Iterable<String> paths) async {
    final added = <PayloadDraft>[];
    for (final p in paths) {
      try {
        final f = await FileAccess.describe(p);
        added.add(PayloadDraft(id: '${_seq++}', isText: false, name: f.name, path: f.path, size: f.size));
      } catch (_) {
        state = state.copyWith(error: 'Could not read $p');
      }
    }
    state = state.copyWith(items: [...state.items, ...added], clearSaved: true);
  }

  void removeItem(String id) =>
      state = state.copyWith(items: state.items.where((i) => i.id != id).toList());

  void setMode(ProtectionMode m) => state = state.copyWith(mode: m, clearError: true);
  void setPassword(String p) => state = state.copyWith(password: p);
  void setAlgorithm(EncryptionAlgorithm a) => state = state.copyWith(algorithm: a);
  void setRecipient(PublicIdentity? r) =>
      state = r == null ? state.copyWith(clearRecipient: true) : state.copyWith(recipient: r);
  void setSign(bool v) => state = state.copyWith(sign: v);
  void setScatterKey(String k) => state = state.copyWith(scatterKey: k);
  void setCompress(bool v) => state = state.copyWith(compress: v);
  void clearError() => state = state.copyWith(clearError: true);

  void cancel() => _token?.cancel();

  Future<void> start() async {
    if (!state.canStart) return;
    final s = state;
    Uint8List? signerSeed;
    if (s.sign) {
      final id = await ref.read(identityProvider.notifier).loadSecret();
      if (id == null) {
        state = state.copyWith(error: 'No identity to sign with. Generate keys in Settings.');
        return;
      }
      signerSeed = id.ed25519Seed;
    }
    final spec = switch (s.mode) {
      ProtectionMode.none => const EncryptionSpec.none(),
      ProtectionMode.password =>
        EncryptionSpec.password(s.password, algorithm: s.algorithm, signerSeed: signerSeed),
      ProtectionMode.publicKey => EncryptionSpec.publicKey(s.recipient!.encryptionKey,
          algorithm: s.algorithm, signerSeed: signerSeed),
    };
    final job = HideJob(
      imageBytes: s.imageBytes!,
      items: [
        for (final it in s.items)
          it.isText
              ? HidePayloadItem.text(name: it.name, data: Uint8List.fromList(utf8.encode(it.text!)))
              : HidePayloadItem.file(name: it.name, mime: FileAccess.guessMime(it.name), filePath: it.path!),
      ],
      spec: spec,
      compress: s.compress,
      scatterKey: s.scatterKey.isEmpty ? null : s.scatterKey,
    );

    _token = CancellationToken();
    state = state.copyWith(busy: true, progress: 0, stage: 'Starting', clearError: true, clearSaved: true);
    try {
      final png = await ref.read(stegServiceProvider).hide(
            job,
            token: _token,
            onProgress: (f, st) => state = state.copyWith(progress: f, stage: st),
          );
      state = state.copyWith(stage: 'Saving');
      final base = s.imagePath!.split(RegExp(r'[\\/]')).last.replaceAll(RegExp(r'\.[^.]+$'), '');
      final path = await FileAccess.saveBytes('$base-stegshare.png', png, extensions: ['png']);
      state = state.copyWith(busy: false, stage: '', savedPath: path, error: path == null ? 'Save cancelled.' : null);
    } on CancelledException {
      state = state.copyWith(busy: false, stage: '', error: 'Cancelled.');
    } on StegShareException catch (e) {
      state = state.copyWith(busy: false, stage: '', error: e.message);
    } catch (e) {
      state = state.copyWith(busy: false, stage: '', error: 'Unexpected error: ${e.runtimeType}');
    } finally {
      _token?.dispose();
      _token = null;
    }
  }
}

final hideProvider = NotifierProvider<HideController, HideState>(HideController.new);