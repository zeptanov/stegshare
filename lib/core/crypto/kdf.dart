import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../errors.dart';

enum KdfAlgorithm {
  none(0),
  argon2id(1),
  pbkdf2HmacSha256(2);

  final int code;
  const KdfAlgorithm(this.code);

  static KdfAlgorithm fromCode(int c) => values.firstWhere(
        (v) => v.code == c,
        orElse: () => throw ContainerFormatException('Unknown KDF code $c'),
      );
}

class KdfParams {
  final KdfAlgorithm algorithm;
  final int memoryKiB;
  final int iterations;
  final int parallelism;

  const KdfParams({
    required this.algorithm,
    required this.memoryKiB,
    required this.iterations,
    required this.parallelism,
  });

  static const none =
      KdfParams(algorithm: KdfAlgorithm.none, memoryKiB: 0, iterations: 0, parallelism: 0);

  /// Default: Argon2id, 32 MiB, 3 passes (pure-Dart implementation is slow on
  /// mobile, so parameters are moderate).
  static const defaultArgon2id = KdfParams(
      algorithm: KdfAlgorithm.argon2id, memoryKiB: 32 * 1024, iterations: 3, parallelism: 1);

  /// Fallback for environments where Argon2id is too slow.
  static const fallbackPbkdf2 = KdfParams(
      algorithm: KdfAlgorithm.pbkdf2HmacSha256, memoryKiB: 0, iterations: 600000, parallelism: 1);

  /// Upper bounds protect against DoS via a malicious container header.
  void validate() {
    switch (algorithm) {
      case KdfAlgorithm.none:
        return;
      case KdfAlgorithm.argon2id:
        if (memoryKiB < 8 || memoryKiB > (1 << 20)) {
          throw const ContainerFormatException('Argon2id memory out of range.');
        }
        if (iterations < 1 || iterations > 64) {
          throw const ContainerFormatException('Argon2id iterations out of range.');
        }
        if (parallelism < 1 || parallelism > 16) {
          throw const ContainerFormatException('Argon2id parallelism out of range.');
        }
      case KdfAlgorithm.pbkdf2HmacSha256:
        if (iterations < 1000 || iterations > 10000000) {
          throw const ContainerFormatException('PBKDF2 iterations out of range.');
        }
    }
  }
}

class PasswordKdf {
  static const saltLength = 16;
  static const keyLength = 32;

  static Future<SecretKey> deriveKey({
    required String password,
    required Uint8List salt,
    required KdfParams params,
  }) async {
    params.validate();
    if (salt.length < 8) throw const ContainerFormatException('Salt too short.');
    switch (params.algorithm) {
      case KdfAlgorithm.none:
        throw const StegShareException('KDF "none" cannot derive a key.');
      case KdfAlgorithm.argon2id:
        final kdf = Argon2id(
          parallelism: params.parallelism,
          memory: params.memoryKiB,
          iterations: params.iterations,
          hashLength: keyLength,
        );
        return kdf.deriveKeyFromPassword(password: password, nonce: salt);
      case KdfAlgorithm.pbkdf2HmacSha256:
        final kdf = Pbkdf2(
          macAlgorithm: Hmac.sha256(),
          iterations: params.iterations,
          bits: keyLength * 8,
        );
        return kdf.deriveKeyFromPassword(password: password, nonce: salt);
    }
  }
}