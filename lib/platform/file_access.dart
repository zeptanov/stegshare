import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../core/container/safe_filename.dart';

enum _PickSource { gallery, files }

class PickedFileInfo {
  final String path;
  final String name;
  final int size;
  const PickedFileInfo({required this.path, required this.name, required this.size});
}

/// Thin wrapper over platform file dialogs; keeps dart:io out of the UI.
class FileAccess {
  static bool get isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;

  static Future<String?> pickImagePath({required BuildContext context}) async {
    if (isMobile) {
      final source = await _chooseSource(context, includeGallery: true);
      if (source == null) return null;
      if (source == _PickSource.gallery) {
        return (await ImagePicker().pickImage(source: ImageSource.gallery))?.path;
      }
    }
    final r = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
    return r?.files.single.path;
  }

  static Future<List<PickedFileInfo>> pickFiles({required BuildContext context}) async {
    if (isMobile) {
      final source = await _chooseSource(context, includeGallery: true);
      if (source == null) return const [];
      if (source == _PickSource.gallery) {
        final images = await ImagePicker().pickMultiImage();
        final files = <PickedFileInfo>[];
        for (final image in images) {
          files.add(await describe(image.path));
        }
        return files;
      }
    }
    final r = await FilePicker.platform.pickFiles(allowMultiple: true, withData: false);
    if (r == null) return const [];
    final out = <PickedFileInfo>[];
    for (final f in r.files) {
      if (f.path == null) continue;
      out.add(await describe(f.path!));
    }
    return out;
  }

  static Future<String?> pickFilePath({List<String>? extensions}) async {
    final result = await FilePicker.platform.pickFiles(
      type: extensions == null ? FileType.any : FileType.custom,
      allowedExtensions: extensions,
      allowMultiple: false,
      withData: false,
    );
    return result?.files.single.path;
  }

  static Future<_PickSource?> _chooseSource(
    BuildContext context, {
    required bool includeGallery,
  }) =>
      showModalBottomSheet<_PickSource>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (includeGallery)
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Gallery'),
                  onTap: () => Navigator.pop(context, _PickSource.gallery),
                ),
              ListTile(
                leading: const Icon(Icons.folder_open_outlined),
                title: const Text('Files'),
                onTap: () => Navigator.pop(context, _PickSource.files),
              ),
            ],
          ),
        ),
      );

  static Future<PickedFileInfo> describe(String path) async =>
      PickedFileInfo(path: path, name: p.basename(path), size: await File(path).length());

  static Future<Uint8List> readBytes(String path) => File(path).readAsBytes();

  /// Save dialog. Mobile plugins write [bytes] themselves; desktop returns a path.
  static Future<String?> saveBytes(String suggestedName, Uint8List bytes,
      {List<String>? extensions}) async {
    final name = SafeFilename.sanitize(suggestedName);
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save $name',
      fileName: name,
      bytes: isMobile ? bytes : null,
      type: extensions == null ? FileType.any : FileType.custom,
      allowedExtensions: extensions,
    );
    if (path == null) return null;
    if (!isMobile) await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  static Future<String?> pickDirectory() => FilePicker.platform.getDirectoryPath();

  /// Writes into [dir] with a sanitised name, never overwriting existing files.
  static Future<String> writeInto(String dir, String name, Uint8List bytes) async {
    var target = SafeFilename.joinWithin(dir, name);
    final base = p.basenameWithoutExtension(target);
    final ext = p.extension(target);
    var n = 1;
    while (await File(target).exists()) {
      target = SafeFilename.joinWithin(dir, '$base ($n)$ext');
      n++;
    }
    await File(target).writeAsBytes(bytes, flush: true);
    return target;
  }

  static String guessMime(String name) {
    switch (p.extension(name).toLowerCase()) {
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.pdf':
        return 'application/pdf';
      case '.txt':
        return 'text/plain';
      case '.json':
        return 'application/json';
      case '.zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }
}