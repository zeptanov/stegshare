import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart' show getCrc32;
import 'package:cryptography/cryptography.dart';

import '../compression/compressor.dart';
import '../crypto/hashing.dart';
import '../crypto/hybrid_encryption.dart';
import '../crypto/kdf.dart';
import '../crypto/secure_random.dart';
import '../crypto/signing.dart';
import '../crypto/symmetric_cipher.dart';
import '../errors.dart';
import '../util/byte_io.dart';
import '../util/cancellation.dart';
import 'container_format.dart';
import 'manifest.dart';
import 'safe_filename.dart';

/// Input item for building a container. Data is in memory because payloads are
/// bounded by image capacity (a few MB for typical photos).
class PayloadInput {
  final PayloadType type;
  final String name;
  final String mime;
  final Uint8List data;
  const PayloadInput({required this.type, required this.name, required this.mime, required this.data});
}

/// Data-only encryption specification (isolate friendly; no live key objects).
class EncryptionSpec {
  final KeyMode mode;
  final EncryptionAlgorithm algorithm;
  final KdfParams kdf;
  final String? password;
  final Uint8List? recipientPublicKey;
  final Uint8List? signerSeed; // Ed25519 seed, optional

  const EncryptionSpec._({
    required this.mode,
    required this.algorithm,
    required this.kdf,
    this.password,
    this.recipientPublicKey,
    this.signerSeed,
  });

  const EncryptionSpec.none()
      : this._(mode: KeyMode.none, algorithm: EncryptionAlgorithm.none, kdf: KdfParams.none);

  const EncryptionSpec.password(
    String password, {
    EncryptionAlgorithm algorithm = EncryptionAlgorithm.aes256Gcm,
    KdfParams kdf = KdfParams.defaultArgon2id,
    Uint8List? signerSeed,
  }) : this._(
            mode: KeyMode.password,
            algorithm: algorithm,
            kdf: kdf,
            password: password,
            signerSeed: signerSeed);

  const EncryptionSpec.publicKey(
    Uint8List recipientPublicKey, {
    EncryptionAlgorithm algorithm = EncryptionAlgorithm.chacha20Poly1305,
    Uint8List? signerSeed,
  }) : this._(
            mode: KeyMode.publicKey,
            algorithm: algorithm,
            kdf: KdfParams.none,
            recipientPublicKey: recipientPublicKey,
            signerSeed: signerSeed);
}

class ExtractedItem {
  final ManifestEntry entry;
  final Uint8List data;
  const ExtractedItem(this.entry, this.data);
  String? get asText => entry.type == PayloadType.text ? utf8.decode(data, allowMalformed: true) : null;
}

enum SignatureStatus { none, valid, invalid }

class DecodedContainer {
  final ContainerHeader header;
  final Manifest manifest;
  final List<ExtractedItem> items;
  final SignatureStatus signature;
  final Uint8List? signerPublicKey;
  const DecodedContainer({
    required this.header,
    required this.manifest,
    required this.items,
    required this.signature,
    this.signerPublicKey,
  });
}

class ContainerCodec {
  static const maxManifestBytes = 4 << 20;

  Future<Uint8List> build({
    required List<PayloadInput> items,
    required EncryptionSpec spec,
    bool compress = true,
    ProgressFn? onProgress,
    CancellationToken? token,
  }) async {
    if (items.isEmpty) throw const StegShareException('Nothing to hide.');
    final now = DateTime.now().millisecondsSinceEpoch;
    final entries = <ManifestEntry>[];
    final dataBuilder = BytesBuilder(copy: false);
    for (var i = 0; i < items.length; i++) {
      token?.throwIfCancelled();
      final it = items[i];
      entries.add(ManifestEntry(
        id: i + 1,
        type: it.type,
        name: SafeFilename.sanitize(it.name),
        mime: it.mime,
        size: it.data.length,
        timestampMs: now,
        sha256Hex: Hashing.hex(Hashing.sha256(it.data)),
      ));
      dataBuilder.add(it.data);
      onProgress?.call(0.1 * (i + 1) / items.length, 'Hashing payload');
    }
    final manifestJson = utf8.encode(jsonEncode(Manifest(createdAtMs: now, entries: entries).toJson()));
    final plain = (ByteWriter()
          ..u32(manifestJson.length)
          ..bytes(manifestJson)
          ..bytes(dataBuilder.takeBytes()))
        .toBytes();

    var flags = 0;
    var body = plain;
    if (compress) {
      onProgress?.call(0.15, 'Compressing');
      final c = Compressor.compressIfSmaller(plain);
      if (c != null) {
        body = c;
        flags |= ContainerFlags.compressed;
      }
    }
    token?.throwIfCancelled();

    final ext = <int, Uint8List>{};
    SecretKey? key;
    var salt = Uint8List(0);
    var nonce = Uint8List(0);
    var kdf = KdfParams.none;

    switch (spec.mode) {
      case KeyMode.none:
        break;
      case KeyMode.password:
        final pw = spec.password;
        if (pw == null || pw.isEmpty) throw const StegShareException('Password is empty.');
        kdf = spec.kdf;
        salt = SecureRandomBytes.next(PasswordKdf.saltLength);
        nonce = SecureRandomBytes.next(SymmetricCipher.nonceLength);
        onProgress?.call(0.2, 'Deriving key');
        key = await PasswordKdf.deriveKey(password: pw, salt: salt, params: kdf);
      case KeyMode.publicKey:
        final pub = spec.recipientPublicKey;
        if (pub == null) throw const StegShareException('Recipient public key missing.');
        final contentKey = SecureRandomBytes.next(SymmetricCipher.keyLength);
        nonce = SecureRandomBytes.next(SymmetricCipher.nonceLength);
        onProgress?.call(0.2, 'Wrapping key');
        final blob = await HybridEncryption.wrapKey(contentKey: contentKey, recipientPublicKey: pub);
        ext[ExtType.ephemeralPublicKey] = blob.ephemeralPublicKey;
        ext[ExtType.wrappedKey] = blob.wrappedKey;
        ext[ExtType.wrapNonce] = blob.wrapNonce;
        ext[ExtType.recipientFingerprint] = Uint8List.sublistView(Hashing.sha256(pub), 0, 8);
        key = SecretKey(contentKey);
    }

    Uint8List? signerPub;
    if (spec.signerSeed != null) {
      flags |= ContainerFlags.signed;
      final kp = await Ed25519().newKeyPairFromSeed(spec.signerSeed!);
      signerPub = Uint8List.fromList((await kp.extractPublicKey()).bytes);
      ext[ExtType.signerPublicKey] = signerPub;
    }

    final header = ContainerHeader(
      flags: flags,
      encryption: spec.algorithm,
      keyMode: spec.mode,
      kdf: kdf,
      salt: salt,
      nonce: nonce,
      extensions: ext,
    );
    final headerBytes = header.encode();

    token?.throwIfCancelled();
    if (key != null) {
      onProgress?.call(0.4, 'Encrypting');
      body = await SymmetricCipher.encrypt(
          algorithm: spec.algorithm, key: key, nonce: nonce, plaintext: body, aad: headerBytes);
    }

    final w = ByteWriter()
      ..bytes(headerBytes)
      ..u32(body.length)
      ..bytes(body);
    if (spec.signerSeed != null) {
      onProgress?.call(0.5, 'Signing');
      final sig = await Signing.sign(seed: spec.signerSeed!, message: w.toBytes());
      w
        ..u8(sig.length)
        ..bytes(sig);
    }
    final soFar = w.toBytes();
    w.u32(getCrc32(soFar));
    return w.toBytes();
  }

  /// Reads header only (no secrets needed). Returns null if not a container.
  static ContainerHeader? probe(Uint8List bytes) {
    if (!ContainerHeader.hasMagic(bytes)) return null;
    try {
      return ContainerHeader.decode(ByteReader(bytes));
    } on StegShareException {
      return null;
    }
  }

  Future<DecodedContainer> open(
    Uint8List bytes, {
    String? password,
    Uint8List? recipientSeed,
    ProgressFn? onProgress,
    CancellationToken? token,
  }) async {
    final r = ByteReader(bytes);
    final header = ContainerHeader.decode(r);
    final aad = Uint8List.sublistView(bytes, 0, r.offset);
    final bodyLen = r.u32();
    if (bodyLen > r.remaining) throw const ContainerFormatException('Body length exceeds data.');
    var body = Uint8List.fromList(r.bytes(bodyLen));
    Uint8List? signature;
    if (header.isSigned) {
      final sigLen = r.u8();
      signature = Uint8List.fromList(r.bytes(sigLen));
    }
    final signedRegionEnd = header.isSigned ? r.offset - 1 - signature!.length : r.offset;
    final crcOffset = r.offset;
    final expectedCrc = r.u32();
    if (!r.isAtEnd) throw const ContainerFormatException('Trailing data after container.');
    if (getCrc32(Uint8List.sublistView(bytes, 0, crcOffset)) != expectedCrc) {
      throw const ContainerFormatException('Checksum mismatch: container is corrupted.');
    }

    var sigStatus = SignatureStatus.none;
    Uint8List? signerPub;
    if (header.isSigned) {
      signerPub = header.extensions[ExtType.signerPublicKey];
      if (signerPub == null) throw const ContainerFormatException('Signed container without signer key.');
      onProgress?.call(0.1, 'Verifying signature');
      final ok = await Signing.verify(
          publicKey: signerPub,
          message: Uint8List.sublistView(bytes, 0, signedRegionEnd),
          signature: signature!);
      sigStatus = ok ? SignatureStatus.valid : SignatureStatus.invalid;
    }
    token?.throwIfCancelled();

    SecretKey? key;
    switch (header.keyMode) {
      case KeyMode.none:
        break;
      case KeyMode.password:
        if (password == null || password.isEmpty) throw const PasswordRequiredException();
        onProgress?.call(0.2, 'Deriving key');
        key = await PasswordKdf.deriveKey(password: password, salt: header.salt, params: header.kdf);
      case KeyMode.publicKey:
        if (recipientSeed == null) throw const PrivateKeyRequiredException();
        final fp = header.extensions[ExtType.recipientFingerprint];
        if (fp != null) {
          final kp = await X25519().newKeyPairFromSeed(recipientSeed);
          final myPub = (await kp.extractPublicKey()).bytes;
          final myFp = Uint8List.sublistView(Hashing.sha256(myPub), 0, 8);
          if (!Hashing.constantTimeEquals(fp, myFp)) throw const NotForThisRecipientException();
        }
        final eph = header.extensions[ExtType.ephemeralPublicKey];
        final wrapped = header.extensions[ExtType.wrappedKey];
        final wnonce = header.extensions[ExtType.wrapNonce];
        if (eph == null || wrapped == null || wnonce == null) {
          throw const ContainerFormatException('Missing recipient block.');
        }
        onProgress?.call(0.2, 'Unwrapping key');
        key = SecretKey(await HybridEncryption.unwrapKey(
            blob: HybridBlob(ephemeralPublicKey: eph, wrapNonce: wnonce, wrappedKey: wrapped),
            recipientSeed: recipientSeed));
    }
    token?.throwIfCancelled();

    if (key != null) {
      onProgress?.call(0.5, 'Decrypting');
      body = await SymmetricCipher.decrypt(
          algorithm: header.encryption, key: key, nonce: header.nonce, ciphertextWithTag: body, aad: aad);
    }
    if (header.isCompressed) {
      onProgress?.call(0.7, 'Decompressing');
      body = Compressor.decompress(body);
    }

    onProgress?.call(0.8, 'Parsing manifest');
    final br = ByteReader(body);
    final mLen = br.u32();
    if (mLen > maxManifestBytes) throw const ContainerFormatException('Manifest too large.');
    final Manifest manifest;
    try {
      manifest = Manifest.fromJson(jsonDecode(utf8.decode(br.bytes(mLen))) as Map<String, dynamic>);
    } on StegShareException {
      rethrow;
    } catch (_) {
      throw const ContainerFormatException('Manifest is not valid JSON.');
    }
    final items = <ExtractedItem>[];
    var consumed = 0;
    for (final e in manifest.entries) {
      if (e.size > br.remaining) throw const ContainerFormatException('Entry size exceeds payload.');
      final data = Uint8List.fromList(br.bytes(e.size));
      consumed += e.size;
      if (consumed > body.length) throw const ContainerFormatException('Size overflow.');
      if (Hashing.hex(Hashing.sha256(data)) != e.sha256Hex) {
        throw ContainerFormatException('SHA-256 mismatch for "${e.name}".');
      }
      items.add(ExtractedItem(e, data));
    }
    if (!br.isAtEnd) throw const ContainerFormatException('Unexpected trailing payload bytes.');
    onProgress?.call(1.0, 'Done');
    return DecodedContainer(
        header: header, manifest: manifest, items: items, signature: sigStatus, signerPublicKey: signerPub);
  }
}