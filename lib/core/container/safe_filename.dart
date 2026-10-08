import 'package:path/path.dart' as p;

import '../errors.dart';

/// Normalises untrusted file names from a container before touching the disk.
class SafeFilename {
  static const _maxLength = 200;
  static final _reservedWindows = RegExp(
      r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\..*)?$', caseSensitive: false);
  static final _badChars = RegExp(r'[<>:"|?*\x00-\x1F\x7F]');

  static String sanitize(String? raw) {
    var name = (raw ?? '').trim();
    // Drop any directory components from both separators.
    name = name.split(RegExp(r'[\\/]+')).where((s) => s.isNotEmpty).lastOrNull ?? '';
    name = name.replaceAll(_badChars, '_').trim();
    name = name.replaceAll(RegExp(r'^\.+'), ''); // no hidden/dot-only names
    if (name.isEmpty || name == '.' || name == '..') name = 'file';
    if (_reservedWindows.hasMatch(name)) name = '_$name';
    if (name.endsWith('.') || name.endsWith(' ')) name = '${name}_';
    if (name.length > _maxLength) {
      final ext = p.extension(name);
      name = name.substring(0, _maxLength - ext.length) + ext;
    }
    return name;
  }

  /// Ensures `dir/name` resolves inside `dir`.
  static String joinWithin(String dir, String name) {
    final safe = sanitize(name);
    final target = p.normalize(p.join(dir, safe));
    final root = p.normalize(dir);
    if (!p.isWithin(root, target)) {
      throw const UnsafeInputException('Refusing to write outside target directory.');
    }
    return target;
  }
}