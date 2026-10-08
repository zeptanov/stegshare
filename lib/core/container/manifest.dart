import '../errors.dart';
import 'safe_filename.dart';

enum PayloadType {
  text('text'),
  file('file');

  final String code;
  const PayloadType(this.code);
  static PayloadType fromCode(String c) => values.firstWhere((v) => v.code == c,
      orElse: () => throw ContainerFormatException('Unknown payload type "$c"'));
}

class ManifestEntry {
  final int id;
  final PayloadType type;
  final String name;
  final String mime;
  final int size;
  final int timestampMs;
  final String sha256Hex;

  const ManifestEntry({
    required this.id,
    required this.type,
    required this.name,
    required this.mime,
    required this.size,
    required this.timestampMs,
    required this.sha256Hex,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.code,
        'name': name,
        'mime': mime,
        'size': size,
        'ts': timestampMs,
        'sha256': sha256Hex,
      };

  factory ManifestEntry.fromJson(Map<String, dynamic> j) {
    final id = j['id'];
    final size = j['size'];
    final ts = j['ts'];
    final sha = j['sha256'];
    final name = j['name'];
    final mime = j['mime'];
    if (id is! int || size is! int || ts is! int || sha is! String || name is! String || mime is! String) {
      throw const ContainerFormatException('Malformed manifest entry.');
    }
    if (size < 0 || size > 0xFFFFFFFF) throw const ContainerFormatException('Bad entry size.');
    if (sha.length != 64 || !RegExp(r'^[0-9a-f]+$').hasMatch(sha)) {
      throw const ContainerFormatException('Bad entry hash.');
    }
    if (mime.length > 255) throw const ContainerFormatException('MIME too long.');
    return ManifestEntry(
      id: id,
      type: PayloadType.fromCode(j['type'] as String? ?? ''),
      name: SafeFilename.sanitize(name),
      mime: mime,
      size: size,
      timestampMs: ts,
      sha256Hex: sha,
    );
  }
}

class Manifest {
  static const formatVersion = 1;
  static const maxEntries = 10000;

  final int version;
  final int createdAtMs;
  final List<ManifestEntry> entries;
  /// Free-form map for future extensions; unknown keys are preserved.
  final Map<String, dynamic> extra;

  const Manifest({
    this.version = formatVersion,
    required this.createdAtMs,
    required this.entries,
    this.extra = const {},
  });

  Map<String, dynamic> toJson() => {
        'v': version,
        'created': createdAtMs,
        'entries': entries.map((e) => e.toJson()).toList(),
        if (extra.isNotEmpty) 'extra': extra,
      };

  factory Manifest.fromJson(Map<String, dynamic> j) {
    final v = j['v'];
    final created = j['created'];
    final list = j['entries'];
    if (v is! int || created is! int || list is! List) {
      throw const ContainerFormatException('Malformed manifest.');
    }
    if (v > formatVersion) throw ContainerFormatException('Manifest version $v not supported.');
    if (list.length > maxEntries) throw const ContainerFormatException('Too many entries.');
    return Manifest(
      version: v,
      createdAtMs: created,
      entries: list.map((e) => ManifestEntry.fromJson(e as Map<String, dynamic>)).toList(),
      extra: (j['extra'] as Map<String, dynamic>?) ?? const {},
    );
  }
}