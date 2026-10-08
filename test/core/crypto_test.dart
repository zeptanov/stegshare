import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stegshare/core/crypto/hashing.dart';
import 'package:stegshare/core/crypto/hybrid_encryption.dart';
import 'package:stegshare/core/crypto/identity.dart';
import 'package:stegshare/core/crypto/kdf.dart';
import 'package:stegshare/core/crypto/secure_random.dart';
import 'package:stegshare/core/crypto/signing.dart';
import 'package:stegshare/core/crypto/symmetric_cipher.dart';
import 'package:stegshare/core/errors.dart';

const smallArgon = KdfParams(algorithm: KdfAlgorithm.argon2id, memoryKiB: 256, iterations: 1, parallelism: 1);

void main() {
  group('KDF', () {
    test('argon2id is deterministic and salt-sensitive', () async {
      final salt = Uint8List.fromList(List.filled(16, 7));
      final a = await PasswordKdf.deriveKey(password: 'pw', salt: salt, params: smallArgon);
      final b = await PasswordKdf.deriveKey(password: 'pw', salt: salt, params: smallArgon);
      final c = await PasswordKdf.deriveKey(password: 'pw', salt: Uint8List(16), params: smallArgon);
      expect(await a.extractBytes(), equals(await b.extractBytes()));
      expect(await a.extractBytes(), isNot(equals(await c.extractBytes())));
    });

    test('pbkdf2 works and rejects insane params', () async {
      final k = await PasswordKdf.deriveKey(
          password: 'x', salt: Uint8List(16), params: const KdfParams(algorithm: KdfAlgorithm.pbkdf2HmacSha256, memoryKiB: 0, iterations: 1000, parallelism: 1));
      expect((await k.extractBytes()).length, 32);
      expect(
          () => const KdfParams(algorithm: KdfAlgorithm.argon2id, memoryKiB: 1 << 30, iterations: 1, parallelism: 1).validate(),
          throwsA(isA<ContainerFormatException>()));
    });
  });

  group('AEAD', () {
    for (final alg in [EncryptionAlgorithm.aes256Gcm, EncryptionAlgorithm.chacha20Poly1305]) {
      test('$alg round trip + tamper detection', () async {
        final key = SecretKey(SecureRandomBytes.next(32));
        final nonce = SecureRandomBytes.next(12);
        final aad = Uint8List.fromList([1, 2, 3]);
        final pt = Uint8List.fromList(List.generate(1000, (i) => i & 0xFF));
        final ct = await SymmetricCipher.encrypt(algorithm: alg, key: key, nonce: nonce, plaintext: pt, aad: aad);
        final back = await SymmetricCipher.decrypt(algorithm: alg, key: key, nonce: nonce, ciphertextWithTag: ct, aad: aad);
        expect(back, equals(pt));
        ct[10] ^= 1;
        expect(
            () => SymmetricCipher.decrypt(algorithm: alg, key: key, nonce: nonce, ciphertextWithTag: ct, aad: aad),
            throwsA(isA<DecryptionException>()));
        ct[10] ^= 1;
        expect(
            () => SymmetricCipher.decrypt(algorithm: alg, key: key, nonce: nonce, ciphertextWithTag: ct, aad: Uint8List(0)),
            throwsA(isA<DecryptionException>()));
      });
    }
  });

  test('hybrid wrap/unwrap and wrong key', () async {
    final alice = StegIdentity.generate('alice');
    final bob = StegIdentity.generate('bob');
    final cek = SecureRandomBytes.next(32);
    final blob = await HybridEncryption.wrapKey(contentKey: cek, recipientPublicKey: (await alice.publicIdentity()).encryptionKey);
    expect(await HybridEncryption.unwrapKey(blob: blob, recipientSeed: alice.x25519Seed), equals(cek));
    expect(() => HybridEncryption.unwrapKey(blob: blob, recipientSeed: bob.x25519Seed), throwsA(isA<DecryptionException>()));
  });

  test('ed25519 sign/verify', () async {
    final id = StegIdentity.generate('s');
    final msg = [1, 2, 3, 4];
    final sig = await Signing.sign(seed: id.ed25519Seed, message: msg);
    final pub = (await id.publicIdentity()).signingKey;
    expect(await Signing.verify(publicKey: pub, message: msg, signature: sig), isTrue);
    expect(await Signing.verify(publicKey: pub, message: [9], signature: sig), isFalse);
  });

  test('sha256 known vector', () {
    expect(Hashing.hex(Hashing.sha256('abc'.codeUnits)),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
  });
}