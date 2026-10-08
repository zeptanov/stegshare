import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors.dart';
import '../../core/util/cancellation.dart';
import '../../domain/models.dart';
import '../../platform/file_access.dart';
import '../settings/settings_controller.dart';

class ExtractState {
  final String? imagePath;
  final Uint8List? imageBytes;
  final String password;
  final String scatterKey;
  final bool busy;
  final double progress;
  final String stage;
  final String? error;
  final bool needsPassword;
  final ExtractResult? result;
  final String? lastSaved;

  const ExtractState({
    this.imagePath,
    this.imageBytes,
    this.password = '',
    this.scatterKey = '',
    this.busy = false,
    this.progress = 0,
    this.stage = '',
    this.error,
    this.needsPassword = false,
    this.result,
    this.lastSaved,
  });

  ExtractState copyWith({
    String? imagePath,
    Uint8List? imageBytes,
    String? password,
    String? scatterKey,
    bool? busy,
    double? progress,
    String? stage,
    String? error,
    bool clearError = false,
    bool? needsPassword,
    ExtractResult? result,
    bool clearResult = false,
    String? lastSaved,
  }) =>
      ExtractState(
        imagePath: imagePath ?? this.imagePath,
        imageBytes: imageBytes ?? this.imageBytes,
        password: password ?? this.password,
        scatterKey: scatterKey ?? this.scatterKey,
        busy: busy ?? this.busy,
        progress: progress ?? this.progress,
        stage: stage ?? this.stage,
        error: clearError ? null : (error ?? this.error),
        needsPassword: needsPassword ?? this.needsPassword,
        result: clearResult ? null : (result ?? this.result),
        lastSaved: lastSaved ?? this.lastSaved,
      );
}

class ExtractController extends Notifier<ExtractState> {
  CancellationToken? _token;

  @override
  ExtractState build() => const ExtractState();

  Future<void> setImagePath(String path) async {
    try {
      final bytes = await FileAccess.readBytes(path);
      state = state.copyWith(imagePath: path, imageBytes: bytes, clearError: true, clearResult: true, needsPassword: false);
    } catch (_) {
      state = state.copyWith(error: 'Could not read image.');
    }
  }

  void setPassword(String p) => state = state.copyWith(password: p);
  void setScatterKey(String k) => state = state.copyWith(scatterKey: k);
  void cancel() => _token?.cancel();

  Future<void> extract() async {
    final bytes = state.imageBytes;
    if (bytes == null || state.busy) return;
    final id = await ref.read(identityProvider.notifier).loadSecret();
    _token = CancellationToken();
    state = state.copyWith(busy: true, progress: 0, stage: 'Starting', clearError: true, clearResult: true);
    try {
      final r = await ref.read(stegServiceProvider).extract(
            ExtractJob(
              imageBytes: bytes,
              password: state.password.isEmpty ? null : state.password,
              recipientSeed: id?.x25519Seed,
              scatterKey: state.scatterKey.isEmpty ? null : state.scatterKey,
            ),
            token: _token,
            onProgress: (f, s) => state = state.copyWith(progress: f, stage: s),
          );
      state = state.copyWith(busy: false, stage: '', result: r, needsPassword: false);
    } on PasswordRequiredException catch (e) {
      state = state.copyWith(busy: false, stage: '', needsPassword: true, error: e.message);
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

  Future<void> saveItem(int index) async {
    final it = state.result!.items[index];
    final path = await FileAccess.saveBytes(it.entry.name, it.data);
    if (path != null) state = state.copyWith(lastSaved: path);
  }

  Future<void> saveAll() async {
    final dir = await FileAccess.pickDirectory();
    if (dir == null) return;
    String? last;
    try {
      for (final it in state.result!.items) {
        last = await FileAccess.writeInto(dir, it.entry.name, it.data);
      }
      state = state.copyWith(lastSaved: last);
    } on StegShareException catch (e) {
      state = state.copyWith(error: e.message);
    }
  }
}

final extractProvider = NotifierProvider<ExtractController, ExtractState>(ExtractController.new);