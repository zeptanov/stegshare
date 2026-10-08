import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stegshare/core/container/container_codec.dart';
import 'package:stegshare/core/container/container_format.dart';
import 'package:stegshare/core/container/manifest.dart';
import 'package:stegshare/core/crypto/identity.dart';
import 'package:stegshare/core/crypto/kdf.dart';
import 'package:stegshare/core/errors.dart';

const fastKdf = KdfParams(algorithm: KdfAlgorithm.argon2id, memoryKiB: 256, iterations: 1, parallelism: 1);

PayloadInput text(String name, String s) => PayloadInput(
    type: PayloadType.text, name: name, mime: 'text/plain', data: Uint8List.fromList(utf8.encode(s)));

PayloadInput file(String name, int n) => PayloadInput(
    type: PayloadType.file, name: name, mime: 'application/octet-stream', data: Uint8List.fromList(List.generate(n, (i) => (i * 31) & 0xFF)));

void main() {
  final codec = ContainerCodec();

  test('unencrypted multi-payload round trip', () async {
    final bytes = await codec.build(items: [text('a.txt', 'hello'), file('b.bin', 5000), text('c.txt', 'мир')], spec: const EncryptionSpec.none());
    expect(ContainerCodec.probe(bytes)?.keyMode, KeyMode.none);
    final d = await codec.open(bytes);
    expect(d.items.length, 3);
    expect(d.items[0].asText, 'hello');
    expect(d.items[1].data.length, 5000);
    expect(d.items[2].asText, 'мир');
    expect(d.signature, SignatureStatus.none);
  });

  test('password round trip, wrong password fails', () async {
    final bytes = await codec.build(items: [text('m.txt', 'secret')], spec: const EncryptionSpec.password('pw', kdf: fastKdf));
    final d = await codec.open(bytes, password: 'pw');
    expect(d.items.single.asText, 'secret');
    expect(() => codec.open(bytes, password: 'nope'), throwsA(isA<DecryptionException>()));
    expect(() => codec.open(bytes), throwsA(isA<PasswordRequiredException>()));
  });

  test('corrupted byte detected by CRC or AEAD', () async {
    final bytes = await codec.build(items: [file('x', 2000)], spec: const EncryptionSpec.password('pw', kdf: fastKdf));
    for (final pos in [5, 40, bytes.length ~/ 2, bytes.length - 2]) {
      final bad = Uint8List.fromList(bytes);
      bad[pos] ^= 0x01;
      expect(() => codec.open(bad, password: 'pw'), throwsA(isA<StegShareException>()), reason: 'pos $pos');
    }
  });

  test('truncated / garbage input is rejected safely', () async {
    final bytes = await codec.build(items: [text('t', 'x')], spec: const EncryptionSpec.none());
    expect(() => codec.open(Uint8List.sublistView(bytes, 0, 20)), throwsA(isA<ContainerFormatException>()));
    expect(() => codec.open(Uint8List.fromList([1, 2, 3])), throwsA(isA<ContainerFormatException>()));
    expect(ContainerCodec.probe(Uint8List(100)), isNull);
  });

  test('public key mode + signature', () async {
    final alice = StegIdentity.generate('alice');
    final bob = StegIdentity.generate('bob');
    final alicePub = await alice.publicIdentity();
    final bytes = await codec.build(
      items: [text('m', 'for alice')],
      spec: EncryptionSpec.publicKey(alicePub.encryptionKey, signerSeed: bob.ed25519Seed),
    );
    final d = await codec.open(bytes, recipientSeed: alice.x25519Seed);
    expect(d.items.single.asText, 'for alice');
    expect(d.signature, SignatureStatus.valid);
    expect(d.signerPublicKey, equals((await bob.publicIdentity()).signingKey));
    expect(() => codec.open(bytes, recipientSeed: bob.x25519Seed), throwsA(isA<NotForThisRecipientException>()));
    expect(() => codec.open(bytes), throwsA(isA<PrivateKeyRequiredException>()));
  });

  test('large payload with compression flag', () async {
    final big = PayloadInput(type: PayloadType.file, name: 'zeros.bin', mime: 'x', data: Uint8List(3 * 1024 * 1024));
    final bytes = await codec.build(items: [big], spec: const EncryptionSpec.password('p', kdf: fastKdf));
    expect(bytes.length, lessThan(100 * 1024));
    expect(ContainerCodec.probe(bytes)!.isCompressed, isTrue);
    final d = await codec.open(bytes, password: 'p');
    expect(d.items.single.data.length, 3 * 1024 * 1024);
  });

  test('dangerous names are sanitised in manifest', () async {
    final bytes = await codec.build(items: [text('../../etc/passwd', 'x')], spec: const EncryptionSpec.none());
    final d = await codec.open(bytes);
    expect(d.items.single.entry.name, 'passwd');
  });
}