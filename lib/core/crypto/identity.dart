import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'hashing.dart';
import 'secure_random.dart';

/// Public half of an identity: X25519 key for encryption, Ed25519 for signatures.
class PublicIdentity {
  final String name;
  final Uint8List encryptionKey;
  final Uint8List signingKey;

  const PublicIdentity({required this.name, required this.encryptionKey, required this.signingKey});

  String get fingerprint {
    final h = Hashing.hex(Hashing.sha256([...encryptionKey, ...signingKey])).substring(0, 16);
    return RegExp('.{4}').allMatches(h).map((m) => m.group(0)).join(' ').toUpperCase();
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'enc': base64Url.encode(encryptionKey),
        'sig': base64Url.encode(signingKey),
      };

  factory PublicIdentity.fromJson(Map<String, dynamic> j) => PublicIdentity(
        name: j['name'] as String,
        encryptionKey: base64Url.decode(j['enc'] as String),
        signingKey: base64Url.decode(j['sig'] as String),
      );
}

/// Secret identity: seeds for both key pairs. Stored only in secure storage.
class StegIdentity {
  final String name;
  final Uint8List x25519Seed;
  final Uint8List ed25519Seed;

  const StegIdentity({required this.name, required this.x25519Seed, required this.ed25519Seed});

  static StegIdentity generate(String name) => StegIdentity(
        name: name,
        x25519Seed: SecureRandomBytes.next(32),
        ed25519Seed: SecureRandomBytes.next(32),
      );

  Future<PublicIdentity> publicIdentity() async {
    final x = await X25519().newKeyPairFromSeed(x25519Seed);
    final e = await Ed25519().newKeyPairFromSeed(ed25519Seed);
    return PublicIdentity(
      name: name,
      encryptionKey: Uint8List.fromList((await x.extractPublicKey()).bytes),
      signingKey: Uint8List.fromList((await e.extractPublicKey()).bytes),
    );
  }

  Map<String, dynamic> toJson() => {
        'v': 1,
        'name': name,
        'x': base64Url.encode(x25519Seed),
        'e': base64Url.encode(ed25519Seed),
      };

  factory StegIdentity.fromJson(Map<String, dynamic> j) {
    final x = base64Url.decode(j['x'] as String);
    final e = base64Url.decode(j['e'] as String);
    if (x.length != 32 || e.length != 32) throw const FormatException('Bad identity seeds');
    return StegIdentity(name: j['name'] as String, x25519Seed: x, ed25519Seed: e);
  }
}