import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/crypto/identity.dart';
import '../../core/crypto/identity_backup.dart';
import '../../core/storage/app_lock_store.dart';
import '../../core/storage/contacts_store.dart';
import '../../core/storage/key_store.dart';
import '../../domain/stegshare_service.dart';
import '../../presentation/platform_design/design_language.dart';

final sharedPrefsProvider = Provider<SharedPreferences>((_) => throw UnimplementedError());
final keyStoreProvider = Provider<KeyStore>((_) => SecureKeyStore());
final stegServiceProvider = Provider<StegShareService>((_) => StegShareService());
final contactsStoreProvider = Provider<ContactsStore>((ref) => ContactsStore(ref.watch(sharedPrefsProvider)));

class SettingsState {
  final DesignLanguage designLanguage;
  final ThemeMode themeMode;
  final bool appLockEnabled;
  const SettingsState({
    required this.designLanguage,
    required this.themeMode,
    required this.appLockEnabled,
  });

  SettingsState copyWith({
    DesignLanguage? designLanguage,
    ThemeMode? themeMode,
    bool? appLockEnabled,
  }) => SettingsState(
        designLanguage: designLanguage ?? this.designLanguage,
        themeMode: themeMode ?? this.themeMode,
        appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      );
}

class SettingsController extends Notifier<SettingsState> {
  static const _kLang = 'ui.designLanguage';
  static const _kTheme = 'ui.themeMode';
  static const _kAppLock = 'security.appLockEnabled';

  @override
  SettingsState build() {
    final p = ref.watch(sharedPrefsProvider);
    return SettingsState(
      designLanguage: DesignLanguage.values[(p.getInt(_kLang) ?? 0).clamp(0, DesignLanguage.values.length - 1)],
      themeMode: ThemeMode.values[(p.getInt(_kTheme) ?? 0).clamp(0, ThemeMode.values.length - 1)],
      appLockEnabled: p.getBool(_kAppLock) ?? false,
    );
  }

  void setDesignLanguage(DesignLanguage l) {
    ref.read(sharedPrefsProvider).setInt(_kLang, l.index);
    state = state.copyWith(designLanguage: l);
  }

  void setThemeMode(ThemeMode m) {
    ref.read(sharedPrefsProvider).setInt(_kTheme, m.index);
    state = state.copyWith(themeMode: m);
  }

  Future<void> enableAppLock(String password) async {
    await ref.read(appLockStoreProvider).setPassword(password);
    await ref.read(sharedPrefsProvider).setBool(_kAppLock, true);
    state = state.copyWith(appLockEnabled: true);
  }

  Future<void> disableAppLock() async {
    await ref.read(appLockStoreProvider).clear();
    await ref.read(sharedPrefsProvider).setBool(_kAppLock, false);
    state = state.copyWith(appLockEnabled: false);
  }
}

final settingsProvider = NotifierProvider<SettingsController, SettingsState>(SettingsController.new);

/// Current local identity (private seeds in secure storage) + its public half.
class IdentityController extends AsyncNotifier<PublicIdentity?> {
  @override
  Future<PublicIdentity?> build() async {
    final id = await ref.watch(keyStoreProvider).loadIdentity();
    return id?.publicIdentity();
  }

  Future<void> generate(String name) async {
    state = const AsyncLoading();
    final id = StegIdentity.generate(name.trim().isEmpty ? 'Me' : name.trim());
    await ref.read(keyStoreProvider).saveIdentity(id);
    state = AsyncData(await id.publicIdentity());
  }

  Future<void> delete() async {
    await ref.read(keyStoreProvider).deleteIdentity();
    state = const AsyncData(null);
  }

  Future<void> importBackup(Uint8List bytes, String password) async {
    final id = await IdentityBackup.import(bytes: bytes, password: password);
    await ref.read(keyStoreProvider).saveIdentity(id);
    state = AsyncData(await id.publicIdentity());
  }

  Future<Uint8List> exportBackup(String password) async {
    final id = await ref.read(keyStoreProvider).loadIdentity();
    if (id == null) throw StateError('No identity is available to export.');
    return IdentityBackup.export(identity: id, password: password);
  }

  Future<StegIdentity?> loadSecret() => ref.read(keyStoreProvider).loadIdentity();
}

final identityProvider = AsyncNotifierProvider<IdentityController, PublicIdentity?>(IdentityController.new);

class ContactsController extends Notifier<List<PublicIdentity>> {
  @override
  List<PublicIdentity> build() => ref.watch(contactsStoreProvider).load();

  Future<void> add(PublicIdentity c) async {
    final list = [...state.where((e) => e.fingerprint != c.fingerprint), c];
    await ref.read(contactsStoreProvider).save(list);
    state = list;
  }

  Future<void> remove(PublicIdentity c) async {
    final list = state.where((e) => e.fingerprint != c.fingerprint).toList();
    await ref.read(contactsStoreProvider).save(list);
    state = list;
  }
}

final contactsProvider = NotifierProvider<ContactsController, List<PublicIdentity>>(ContactsController.new);