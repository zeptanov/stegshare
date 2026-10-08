import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Ed25519 digital signatures (sender authenticity). Separate from AEAD
/// integrity, which only proves "whoever had the key produced this".
class Signing {
  static const signatureLength = 64;
  static const publicKeyLength = 32;

  static Future<Uint8List> sign({required Uint8List seed, required List<int> message}) async {
    final kp = await Ed25519().newKeyPairFromSeed(seed);
    final sig = await Ed25519().sign(message, keyPair: kp);
    return Uint8List.fromList(sig.bytes);
  }

  static Future<bool> verify({
    required Uint8List publicKey,
    required List<int> message,
    required Uint8List signature,
  }) async {
    if (publicKey.length != publicKeyLength || signature.length != signatureLength) return false;
    return Ed25519().verify(
      message,
      signature: Signature(signature, publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519)),
    );
  }
}