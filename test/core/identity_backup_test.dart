import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stegshare/core/crypto/identity.dart';
import 'package:stegshare/core/crypto/identity_backup.dart';
import 'package:stegshare/core/errors.dart';

void main() {
  test('private identity backup is encrypted and round-trips', () async {
    final original = StegIdentity.generate('Alice');
    final bytes = await IdentityBackup.export(
        identity: original, password: 'correct horse battery');
    final serialized = utf8.decode(bytes);

    expect(serialized, isNot(contains(base64Url.encode(original.x25519Seed))));
    expect(serialized, isNot(contains(base64Url.encode(original.ed25519Seed))));

    final restored = await IdentityBackup.import(
        bytes: bytes, password: 'correct horse battery');
    expect(restored.name, original.name);
    expect(restored.x25519Seed, original.x25519Seed);
    expect(restored.ed25519Seed, original.ed25519Seed);
  });

  test('private identity backup rejects an incorrect password', () async {
    final bytes = await IdentityBackup.export(
      identity: StegIdentity.generate('Alice'),
      password: 'correct horse battery',
    );

    await expectLater(
      IdentityBackup.import(bytes: bytes, password: 'incorrect password'),
      throwsA(isA<DecryptionException>()),
    );
  });
}
