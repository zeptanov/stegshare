import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../errors.dart';
import 'secure_random.dart';

/// Hybrid scheme: random content key encrypts the payload; the content key is
/// wrapped with a KEK derived from X25519(ephemeral, recipient) via HKDF-SHA256.
/// This provides *encryption* only. Authenticity of the sender requires an
/// Ed25519 signature (see signing.dart) — the two are deliberately separate.
class HybridBlob {
  final Uint8List ephemeralPublicKey; // 32
  final Uint8List wrapNonce; // 12
  final Uint8List wrappedKey; // 32 + 16 tag

  const HybridBlob({
    required this.ephemeralPublicKey,
    required this.wrapNonce,
    required this.wrappedKey,
  });
}

class HybridEncryption {
  static const publicKeyLength = 32;
  static final _info = utf8.encode('STEGSHARE/v1/kek');

  static Future<SecretKey> _kek(
      SimpleKeyPair local, Uint8List remotePub, Uint8List ephPub, Uint8List recipientPub) async {
    final shared = await X25519().sharedSecretKey(
      keyPair: local,
      remotePublicKey: SimplePublicKey(remotePub, type: KeyPairType.x25519),
    );
    return Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
      secretKey: shared,
      nonce: [...ephPub, ...recipientPub],
      info: _info,
    );
  }

  static Future<HybridBlob> wrapKey({
    required Uint8List contentKey,
    required Uint8List recipientPublicKey,
  }) async {
    if (recipientPublicKey.length != publicKeyLength) {
      throw ArgumentError('Recipient public key must be 32 bytes');
    }
    final x = X25519();
    final eph = await x.newKeyPair();
    final ephPub = Uint8List.fromList((await eph.extractPublicKey()).bytes);
    final kek = await _kek(eph, recipientPublicKey, ephPub, recipientPublicKey);
    final nonce = SecureRandomBytes.next(12);
    final box = await Chacha20.poly1305Aead().encrypt(contentKey, secretKey: kek, nonce: nonce);
    return HybridBlob(
      ephemeralPublicKey: ephPub,
      wrapNonce: nonce,
      wrappedKey: Uint8List.fromList([...box.cipherText, ...box.mac.bytes]),
    );
  }

  static Future<Uint8List> unwrapKey({
    required HybridBlob blob,
    required Uint8List recipientSeed,
  }) async {
    if (blob.ephemeralPublicKey.length != publicKeyLength ||
        blob.wrapNonce.length != 12 ||
        blob.wrappedKey.length != 32 + 16) {
      throw const ContainerFormatException('Malformed recipient block.');
    }
    final kp = await X25519().newKeyPairFromSeed(recipientSeed);
    final myPub = Uint8List.fromList((await kp.extractPublicKey()).bytes);
    final kek = await _kek(kp, blob.ephemeralPublicKey, blob.ephemeralPublicKey, myPub);
    final box = SecretBox(
      Uint8List.sublistView(blob.wrappedKey, 0, 32),
      nonce: blob.wrapNonce,
      mac: Mac(Uint8List.sublistView(blob.wrappedKey, 32)),
    );
    try {
      return Uint8List.fromList(await Chacha20.poly1305Aead().decrypt(box, secretKey: kek));
    } on SecretBoxAuthenticationError {
      throw const DecryptionException('Could not unwrap content key with this private key.');
    }
  }
}