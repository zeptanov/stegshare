import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../crypto/kdf.dart';
import '../crypto/secure_random.dart';

abstract class AppLockStore {
  Future<void> setPassword(String password);
  Future<bool> verifyPassword(String password);
  Future<void> clear();
}

class SecureAppLockStore implements AppLockStore {
  static const _key = 'stegshare.appLock.v1';
  final FlutterSecureStorage _storage;

  SecureAppLockStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                  accessibility:
                      KeychainAccessibility.first_unlock_this_device),
            );

  @override
  Future<void> setPassword(String password) async {
    if (password.length < 8) {
      throw const FormatException('Password must be at least 8 characters.');
    }
    final salt = SecureRandomBytes.next(PasswordKdf.saltLength);
    final verifier = await PasswordKdf.deriveKey(
      password: password,
      salt: salt,
      params: KdfParams.defaultArgon2id,
    );
    await _storage.write(
      key: _key,
      value: jsonEncode({
        'salt': base64Url.encode(salt),
        'verifier': base64Url.encode(await verifier.extractBytes()),
      }),
    );
  }

  @override
  Future<bool> verifyPassword(String password) async {
    if (password.length < 8) return false;
    final raw = await _storage.read(key: _key);
    if (raw == null) return false;
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final salt = base64Url.decode(data['salt'] as String);
    final expected = base64Url.decode(data['verifier'] as String);
    final actual = await PasswordKdf.deriveKey(
      password: password,
      salt: salt,
      params: KdfParams.defaultArgon2id,
    );
    final bytes = await actual.extractBytes();
    if (bytes.length != expected.length) return false;
    var difference = 0;
    for (var i = 0; i < bytes.length; i++) {
      difference |= bytes[i] ^ expected[i];
    }
    return difference == 0;
  }

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

class InMemoryAppLockStore implements AppLockStore {
  Uint8List? _salt;
  Uint8List? _verifier;

  @override
  Future<void> setPassword(String password) async {
    if (password.length < 8) {
      throw const FormatException('Password must be at least 8 characters.');
    }
    _salt = SecureRandomBytes.next(PasswordKdf.saltLength);
    _verifier = Uint8List.fromList(await (await PasswordKdf.deriveKey(
      password: password,
      salt: _salt!,
      params: KdfParams.defaultArgon2id,
    ))
        .extractBytes());
  }

  @override
  Future<bool> verifyPassword(String password) async {
    if (password.length < 8) return false;
    final salt = _salt;
    final verifier = _verifier;
    if (salt == null || verifier == null) return false;
    final actual = await (await PasswordKdf.deriveKey(
      password: password,
      salt: salt,
      params: KdfParams.defaultArgon2id,
    ))
        .extractBytes();
    if (actual.length != verifier.length) return false;
    var difference = 0;
    for (var i = 0; i < actual.length; i++) {
      difference |= actual[i] ^ verifier[i];
    }
    return difference == 0;
  }

  @override
  Future<void> clear() async {
    _salt = null;
    _verifier = null;
  }
}

final appLockStoreProvider =
    Provider<AppLockStore>((_) => SecureAppLockStore());
