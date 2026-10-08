import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../crypto/identity.dart';

/// Contacts are PUBLIC keys only, so non-secure preferences are acceptable.
class ContactsStore {
  static const _key = 'stegshare.contacts.v1';
  final SharedPreferences _prefs;
  ContactsStore(this._prefs);

  List<PublicIdentity> load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return const [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => PublicIdentity.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> save(List<PublicIdentity> contacts) =>
      _prefs.setString(_key, jsonEncode(contacts.map((c) => c.toJson()).toList()));
}