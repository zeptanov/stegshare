import 'dart:typed_data';

import '../crypto/kdf.dart';
import '../crypto/symmetric_cipher.dart';
import '../errors.dart';
import '../util/byte_io.dart';

/// STEGSHARE container, version 1 (all integers big-endian):
///
/// ```
/// magic "SGSH"        4
/// version             u8
/// flags               u8   bit0 = zlib compressed, bit1 = signed
/// encryption alg      u8
/// key mode            u8   0 none, 1 password, 2 public key
/// kdf alg             u8
/// kdf memory KiB      u32
/// kdf iterations      u32
/// kdf parallelism     u8
/// salt len + salt     u8 + n
/// nonce len + nonce   u8 + n
/// ext len + ext TLVs  u16 + n   (type u8, len u16, value)
/// body len + body     u32 + n   (ciphertext||tag, or plaintext when unencrypted)
/// [sig len + sig]     u8 + n    (only if flag bit1)
/// crc32               u32  over everything above
/// ```
/// AEAD AAD = header bytes (magic .. end of ext). Signature = Ed25519 over
/// header || body_len || body. Unknown TLV types are ignored for forward compat.
enum KeyMode {
  none(0),
  password(1),
  publicKey(2);

  final int code;
  const KeyMode(this.code);
  static KeyMode fromCode(int c) => values.firstWhere((v) => v.code == c,
      orElse: () => throw ContainerFormatException('Unknown key mode $c'));
}

class ContainerFlags {
  static const compressed = 1 << 0;
  static const signed = 1 << 1;
}

class ExtType {
  static const ephemeralPublicKey = 1;
  static const wrappedKey = 2;
  static const wrapNonce = 3;
  static const signerPublicKey = 5;
  static const recipientFingerprint = 6; // first 8 bytes of SHA-256(recipient pub)
}

class ContainerHeader {
  static const magic = [0x53, 0x47, 0x53, 0x48]; // "SGSH"
  static const currentVersion = 1;
  static const maxSalt = 64;
  static const maxNonce = 32;
  static const maxExt = 8192;

  final int version;
  final int flags;
  final EncryptionAlgorithm encryption;
  final KeyMode keyMode;
  final KdfParams kdf;
  final Uint8List salt;
  final Uint8List nonce;
  final Map<int, Uint8List> extensions;

  const ContainerHeader({
    this.version = currentVersion,
    required this.flags,
    required this.encryption,
    required this.keyMode,
    required this.kdf,
    required this.salt,
    required this.nonce,
    required this.extensions,
  });

  bool get isCompressed => flags & ContainerFlags.compressed != 0;
  bool get isSigned => flags & ContainerFlags.signed != 0;

  Uint8List encode() {
    final w = ByteWriter()
      ..bytes(magic)
      ..u8(version)
      ..u8(flags)
      ..u8(encryption.code)
      ..u8(keyMode.code)
      ..u8(kdf.algorithm.code)
      ..u32(kdf.memoryKiB)
      ..u32(kdf.iterations)
      ..u8(kdf.parallelism)
      ..u8(salt.length)
      ..bytes(salt)
      ..u8(nonce.length)
      ..bytes(nonce);
    final ext = ByteWriter();
    for (final e in extensions.entries) {
      ext
        ..u8(e.key)
        ..u16(e.value.length)
        ..bytes(e.value);
    }
    final extBytes = ext.toBytes();
    w
      ..u16(extBytes.length)
      ..bytes(extBytes);
    return w.toBytes();
  }

  static bool hasMagic(Uint8List data) {
    if (data.length < magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (data[i] != magic[i]) return false;
    }
    return true;
  }

  static ContainerHeader decode(ByteReader r) {
    final m = r.bytes(4);
    for (var i = 0; i < 4; i++) {
      if (m[i] != magic[i]) throw const ContainerFormatException('Not a STEGSHARE container.');
    }
    final version = r.u8();
    if (version != currentVersion) {
      throw ContainerFormatException('Unsupported container version $version.');
    }
    final flags = r.u8();
    final enc = EncryptionAlgorithm.fromCode(r.u8());
    final keyMode = KeyMode.fromCode(r.u8());
    final kdfAlg = KdfAlgorithm.fromCode(r.u8());
    final kdf = KdfParams(
        algorithm: kdfAlg, memoryKiB: r.u32(), iterations: r.u32(), parallelism: r.u8());
    kdf.validate();
    final saltLen = r.u8();
    if (saltLen > maxSalt) throw const ContainerFormatException('Salt too long.');
    final salt = r.bytes(saltLen);
    final nonceLen = r.u8();
    if (nonceLen > maxNonce) throw const ContainerFormatException('Nonce too long.');
    final nonce = r.bytes(nonceLen);
    final extLen = r.u16();
    if (extLen > maxExt) throw const ContainerFormatException('Extension block too long.');
    final extReader = ByteReader(r.bytes(extLen));
    final ext = <int, Uint8List>{};
    while (!extReader.isAtEnd) {
      final type = extReader.u8();
      final len = extReader.u16();
      final value = extReader.bytes(len);
      if (ext.containsKey(type)) throw const ContainerFormatException('Duplicate extension.');
      ext[type] = Uint8List.fromList(value);
    }
    // Consistency checks between encryption and key mode.
    if ((enc == EncryptionAlgorithm.none) != (keyMode == KeyMode.none)) {
      throw const ContainerFormatException('Inconsistent encryption/key mode.');
    }
    if (enc != EncryptionAlgorithm.none && nonce.length != SymmetricCipher.nonceLength) {
      throw const ContainerFormatException('Bad nonce length.');
    }
    return ContainerHeader(
      version: version,
      flags: flags,
      encryption: enc,
      keyMode: keyMode,
      kdf: kdf,
      salt: Uint8List.fromList(salt),
      nonce: Uint8List.fromList(nonce),
      extensions: ext,
    );
  }
}