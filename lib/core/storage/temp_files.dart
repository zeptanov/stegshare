import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../crypto/hashing.dart';
import '../crypto/secure_random.dart';

/// Private, unpredictable temp directory; always wiped with [dispose].
class TempWorkspace {
  final Directory dir;
  TempWorkspace._(this.dir);

  static Future<TempWorkspace> create() async {
    final base = await getTemporaryDirectory();
    final name = 'stegshare_${Hashing.hex(SecureRandomBytes.next(8))}';
    final dir = await Directory(p.join(base.path, name)).create(recursive: true);
    return TempWorkspace._(dir);
  }

  File file(String safeName) => File(p.join(dir.path, safeName));

  Future<void> dispose() async {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {
      // Best effort cleanup.
    }
  }
}