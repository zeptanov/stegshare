import 'dart:convert';
import 'dart:typed_data';

import '../errors.dart';
import 'identity.dart';
import 'kdf.dart';
import 'secure_random.dart';
import 'symmetric_cipher.dart';

class IdentityBackup {
  static const _version = 1;
  static const List<int> _aad = [
    83, 84, 69, 71, 83, 72, 65, 82, 69, 45, 73, 68, 69, 78, 84, 73, 84, 89, 45, 66, 65, 67, 75, 85, 80, 45, 86, 49
  ];

  static Future<Uint8List> export({
    required StegIdentity identity,
    required String password,
  }) async {
    if (password.length < 8) {
      throw const FormatException('Backup password must be at least 8 characters.');
    }
    final salt = SecureRandomBytes.next(PasswordKdf.saltLength);
    final nonce = SecureRandomBytes.next(SymmetricCipher.nonceLength);
    const params = KdfParams.defaultArgon2id;
    final key = await PasswordKdf.deriveKey(password: password, salt: salt, params: params);
    final plaintext = Uint8List.fromList(utf8.encode(jsonEncode(identity.toJson())));
    final ciphertext = await SymmetricCipher.encrypt(
      algorithm: EncryptionAlgorithm.aes256Gcm,
      key: key,
      nonce: nonce,
      plaintext: plaintext,
      aad: Uint8List.fromList(_aad),
    );

    return Uint8List.fromList(utf8.encode(jsonEncode({
      'format': 'stegshare-identity',
      'v': _version,
      'kdf': {
        'algorithm': params.algorithm.code,
        'memoryKiB': params.memoryKiB,
        'iterations': params.iterations,
        'parallelism': params.parallelism,
      },
      'salt': base64Url.encode(salt),
      'nonce': base64Url.encode(nonce),
      'ciphertext': base64Url.encode(ciphertext),
    })));
  }

  static Future<StegIdentity> import({
    required Uint8List bytes,
    required String password,
  }) async {
    try {
      if (password.length < 8 || bytes.isEmpty || bytes.length > 16 * 1024) {
        throw const FormatException('Invalid identity backup or password.');
      }
      final document = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (document['format'] != 'stegshare-identity' || document['v'] != _version) {
        throw const FormatException('Unsupported identity backup format.');
      }
      final kdfJson = document['kdf'] as Map<String, dynamic>;
      final params = KdfParams(
        algorithm: KdfAlgorithm.fromCode(kdfJson['algorithm'] as int),
        memoryKiB: kdfJson['memoryKiB'] as int,
        iterations: kdfJson['iterations'] as int,
        parallelism: kdfJson['parallelism'] as int,
      );
      const expectedParams = KdfParams.defaultArgon2id;
      if (params.algorithm != expectedParams.algorithm ||
          params.memoryKiB != expectedParams.memoryKiB ||
          params.iterations != expectedParams.iterations ||
          params.parallelism != expectedParams.parallelism) {
        throw const FormatException('Unsupported identity backup KDF parameters.');
      }
      final salt = base64Url.decode(document['salt'] as String);
      final nonce = base64Url.decode(document['nonce'] as String);
      final ciphertext = base64Url.decode(document['ciphertext'] as String);
      if (salt.length != PasswordKdf.saltLength ||
          ciphertext.length < SymmetricCipher.tagLength ||
          ciphertext.length > 4096) {
        throw const FormatException('Invalid identity backup data.');
      }
      if (nonce.length != SymmetricCipher.nonceLength) {
        throw const FormatException('Invalid identity backup nonce.');
      }
      final key = await PasswordKdf.deriveKey(password: password, salt: salt, params: params);
      final plaintext = await SymmetricCipher.decrypt(
        algorithm: EncryptionAlgorithm.aes256Gcm,
        key: key,
        nonce: nonce,
        ciphertextWithTag: ciphertext,
        aad: Uint8List.fromList(_aad),
      );
      return StegIdentity.fromJson(jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>);
    } on DecryptionException {
      rethrow;
    } on FormatException {
      rethrow;
    } on TypeError {
      throw const FormatException('Invalid identity backup file.');
    } on ArgumentError {
      throw const FormatException('Invalid identity backup file.');
    }
  }
}
