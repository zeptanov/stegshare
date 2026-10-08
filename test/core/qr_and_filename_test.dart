import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stegshare/core/container/safe_filename.dart';
import 'package:stegshare/core/crypto/identity.dart';
import 'package:stegshare/core/qr/stegshare_uri.dart';

void main() {
  test('public key URI round trip', () async {
    final pub = await StegIdentity.generate('Alice & Co').publicIdentity();
    final uri = StegShareUri.encodePublicIdentity(pub);
    final parsed = StegShareUri.parse(uri) as PublicKeyPayload;
    expect(parsed.identity.name, 'Alice & Co');
    expect(parsed.identity.encryptionKey, equals(pub.encryptionKey));
    expect(parsed.identity.fingerprint, pub.fingerprint);
  });

  test('message URI round trip and limits', () {
    final data = Uint8List.fromList(List.generate(300, (i) => i & 0xFF));
    final parsed = StegShareUri.parse(StegShareUri.encodeMessage(data)) as MessagePayload;
    expect(parsed.containerBytes, equals(data));
    expect(() => StegShareUri.encodeMessage(Uint8List(5000)), throwsFormatException);
  });

  test('rejects malformed URIs', () {
    expect(() => StegShareUri.parse('https://example.com'), throwsFormatException);
    expect(() => StegShareUri.parse('STEGSHARE://key/v9?enc=a'), throwsFormatException);
    expect(() => StegShareUri.parse('STEGSHARE://key/v1?enc=AAAA&sig=AAAA'), throwsFormatException);
    expect(() => StegShareUri.parse('STEGSHARE://foo/v1'), throwsFormatException);
  });

  test('safe filenames', () {
    expect(SafeFilename.sanitize('../../etc/passwd'), 'passwd');
    expect(SafeFilename.sanitize('C:\\Windows\\evil.exe'), 'evil.exe');
    expect(SafeFilename.sanitize('CON'), '_CON');
    expect(SafeFilename.sanitize('..'), 'file');
    expect(SafeFilename.sanitize('a<b>:c"|?*.txt'), 'a_b__c____.txt');
    expect(SafeFilename.sanitize('.hidden'), 'hidden');
    expect(SafeFilename.sanitize('x' * 500).length, lessThanOrEqualTo(200));
    expect(() => SafeFilename.joinWithin('/tmp/out', '../x'), returnsNormally);
  });
}