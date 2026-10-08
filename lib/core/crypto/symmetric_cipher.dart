import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../errors.dart';

enum EncryptionAlgorithm {
  none(0),
  aes256Gcm(1),
  chacha20Poly1305(2);

  final int code;
  const EncryptionAlgorithm(this.code);

  static EncryptionAlgorithm fromCode(int c) => values.firstWhere(
        (v) => v.code == c,
        orElse: () => throw ContainerFormatException('Unknown encryption code $c'),
      );

  String get label => switch (this) {
        none => 'No encryption',
        aes256Gcm => 'AES-256-GCM',
        chacha20Poly1305 => 'ChaCha20-Poly1305',
      };
}

/// Authenticated encryption. Output layout: ciphertext || 16-byte tag.
class SymmetricCipher {
  static const nonceLength = 12;
  static const tagLength = 16;
  static const keyLength = 32;

  static Cipher _cipher(EncryptionAlgorithm alg) => switch (alg) {
        EncryptionAlgorithm.aes256Gcm => AesGcm.with256bits(),
        EncryptionAlgorithm.chacha20Poly1305 => Chacha20.poly1305Aead(),
        EncryptionAlgorithm.none => throw ArgumentError('No cipher for "none"'),
      };

  static Future<Uint8List> encrypt({
    required EncryptionAlgorithm algorithm,
    required SecretKey key,
    required Uint8List nonce,
    required Uint8List plaintext,
    required Uint8List aad,
  }) async {
    if (nonce.length != nonceLength) throw ArgumentError('Nonce must be 12 bytes');
    final box = await _cipher(algorithm).encrypt(plaintext, secretKey: key, nonce: nonce, aad: aad);
    final out = BytesBuilder(copy: false)
      ..add(box.cipherText)
      ..add(box.mac.bytes);
    return out.toBytes();
  }

  static Future<Uint8List> decrypt({
    required EncryptionAlgorithm algorithm,
    required SecretKey key,
    required Uint8List nonce,
    required Uint8List ciphertextWithTag,
    required Uint8List aad,
  }) async {
    if (ciphertextWithTag.length < tagLength) {
      throw const ContainerFormatException('Ciphertext too short.');
    }
    final split = ciphertextWithTag.length - tagLength;
    final box = SecretBox(
      Uint8List.sublistView(ciphertextWithTag, 0, split),
      nonce: nonce,
      mac: Mac(Uint8List.sublistView(ciphertextWithTag, split)),
    );
    try {
      final clear = await _cipher(algorithm).decrypt(box, secretKey: key, aad: aad);
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      throw const DecryptionException(
          'Authentication failed: wrong password/key or corrupted container.');
    }
  }
}