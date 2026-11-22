import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class LocalStorageService {
  static const String appFolder = 'DompetLinc';

  static Future<Directory?> getMediaDirectory(String mediaType) async {
    if (kIsWeb) return null;
    Directory baseDir;
    try {
      baseDir = (await getExternalStorageDirectory()) ?? await getApplicationDocumentsDirectory();
    } catch (_) {
      baseDir = await getApplicationDocumentsDirectory();
    }

    String subFolder = 'Documents';
    if (mediaType == 'image') {
      subFolder = 'Images';
    } else if (mediaType == 'video') {
      subFolder = 'Videos';
    }

    final targetDir = Directory(p.join(baseDir.path, appFolder, 'Media', subFolder));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    return targetDir;
  }

  static Future<String> saveMediaLocally(File sourceFile, String mediaType, {String? customFileName}) async {
    if (kIsWeb) return sourceFile.path;
    final dir = await getMediaDirectory(mediaType);
    if (dir == null) return sourceFile.path;
    final ext = p.extension(sourceFile.path);
    final name = customFileName ?? 'LINC_${DateTime.now().millisecondsSinceEpoch}$ext';
    final destinationPath = p.join(dir.path, name);

    final destFile = await sourceFile.copy(destinationPath);
    return destFile.path;
  }

  static Future<String?> downloadAndSaveMedia(String fullUrl, String mediaType, String fileName) async {
    if (kIsWeb) return null;
    try {
      final dir = await getMediaDirectory(mediaType);
      if (dir == null) return null;
      final destPath = p.join(dir.path, fileName);
      final destFile = File(destPath);

      if (await destFile.exists()) {
        return destPath;
      }

      final res = await http.get(Uri.parse(fullUrl));
      if (res.statusCode == 200) {
        await destFile.writeAsBytes(res.bodyBytes);
        return destPath;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> deleteLocalFile(String? localPath) async {
    if (kIsWeb || localPath == null || localPath.isEmpty) return false;
    try {
      final file = File(localPath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (_) {}
    return false;
  }
}
