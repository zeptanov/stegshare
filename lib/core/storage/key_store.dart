import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../crypto/identity.dart';

abstract class KeyStore {
  Future<StegIdentity?> loadIdentity();
  Future<void> saveIdentity(StegIdentity identity);
  Future<void> deleteIdentity();
}

/// Private keys live in platform secure storage (Keychain / Keystore / DPAPI).
class SecureKeyStore implements KeyStore {
  static const _key = 'stegshare.identity.v1';
  final FlutterSecureStorage _storage;

  SecureKeyStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
            );

  @override
  Future<StegIdentity?> loadIdentity() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    return StegIdentity.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> saveIdentity(StegIdentity identity) =>
      _storage.write(key: _key, value: jsonEncode(identity.toJson()));

  @override
  Future<void> deleteIdentity() => _storage.delete(key: _key);
}

class InMemoryKeyStore implements KeyStore {
  StegIdentity? _identity;
  @override
  Future<StegIdentity?> loadIdentity() async => _identity;
  @override
  Future<void> saveIdentity(StegIdentity identity) async => _identity = identity;
  @override
  Future<void> deleteIdentity() async => _identity = null;
}