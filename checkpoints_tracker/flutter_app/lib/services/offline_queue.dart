import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

class OfflineQueue {
  static final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static Future<File> get _file async =>
      File('${(await getApplicationDocumentsDirectory()).path}/offline_queue.json');

  static Future<void> enqueue(Map<String, dynamic> data) async {
    final f = await _file;
    final list = f.existsSync() ? jsonDecode(await f.readAsString()) as List : [];
    list.add(data);
    await f.writeAsString(jsonEncode(list));
  }

  static Future<void> flush() async {
    final f = await _file;
    if (!f.existsSync()) return;
    final list = jsonDecode(await f.readAsString()) as List;
    if (list.isEmpty) return;

    final token = await _storage.read(key: 'auth_token');
    if (token == null) return;

    final remaining = <Map<String, dynamic>>[];
    for (final item in list) {
      try {
        final resp = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/location'),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          body: jsonEncode(item),
        ).timeout(ApiConfig.timeout, onTimeout: () => http.Response('', 408));
        if (resp.statusCode < 200 || resp.statusCode >= 300) {
          remaining.add(item as Map<String, dynamic>);
        }
      } catch (_) {
        remaining.add(item as Map<String, dynamic>);
      }
    }

    await f.writeAsString(jsonEncode(remaining));
  }

  static Future<int> count() async {
    final f = await _file;
    if (!f.existsSync()) return 0;
    return (jsonDecode(await f.readAsString()) as List).length;
  }
}
