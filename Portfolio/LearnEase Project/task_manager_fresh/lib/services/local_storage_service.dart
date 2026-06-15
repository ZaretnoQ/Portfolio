// lib/services/local_storage_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class LocalStorageService {
  static Future<Directory> get _appDocDir async =>
      await getApplicationDocumentsDirectory();

  static Future<File> _file(String name) async {
    final dir = await _appDocDir;
    return File('${dir.path}/$name.json');
  }

  /// Reads a JSON array from `$name.json`, or returns [] if missing/invalid.
  static Future<List<Map<String, dynamic>>> readList(String name) async {
    try {
      final f = await _file(name);
      if (!await f.exists()) return [];
      final raw = await f.readAsString();
      final decoded = json.decode(raw) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Writes `list` as a JSON array to `$name.json`.
  static Future<void> writeList(
      String name, List<Map<String, dynamic>> list) async {
    final f = await _file(name);
    await f.writeAsString(json.encode(list));
  }
}
