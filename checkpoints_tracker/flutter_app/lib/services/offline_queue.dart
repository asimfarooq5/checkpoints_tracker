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

  // Position updates from the GPS stream can fire in quick succession (e.g. every
  // few seconds while driving). Without serializing file access, two concurrent
  // enqueue() calls can both read the queue before either writes it back, and the
  // second write silently discards the first point — this was dropping most points
  // recorded while offline, leaving only a couple of far-apart points on the trail.
  static Future<void> _tail = Future.value();
  static Future<T> _synchronized<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then((_) => null, onError: (_) => null);
    return result;
  }

  static Future<List<dynamic>> _readList(File f) async {
    if (!f.existsSync()) return [];
    try {
      final decoded = jsonDecode(await f.readAsString());
      return decoded is List ? decoded : [];
    } catch (_) {
      // Corrupted/partial write (e.g. from a past race or interrupted write).
      // Treat as empty instead of throwing, so a single bad write can't
      // permanently break every future enqueue/flush call.
      return [];
    }
  }

  static Future<void> enqueue(Map<String, dynamic> data) => _synchronized(() async {
        try {
          final f = await _file;
          final list = await _readList(f);
          list.add(data);
          await f.writeAsString(jsonEncode(list));
        } catch (_) {}
      });

  static Future<void> flush() => _synchronized(() async {
        try {
          final f = await _file;
          final list = await _readList(f);
          if (list.isEmpty) return;

          final token = await _storage.read(key: 'auth_token');
          if (token == null) return;

          final remaining = <dynamic>[];
          for (final item in list) {
            try {
              final resp = await http.post(
                Uri.parse('${ApiConfig.baseUrl}/location'),
                headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
                body: jsonEncode(item),
              ).timeout(ApiConfig.timeout, onTimeout: () => http.Response('', 408));
              if (resp.statusCode < 200 || resp.statusCode >= 300) {
                remaining.add(item);
              }
            } catch (_) {
              remaining.add(item);
            }
          }

          await f.writeAsString(jsonEncode(remaining));
        } catch (_) {}
      });

  static Future<int> count() => _synchronized(() async {
        try {
          final f = await _file;
          return (await _readList(f)).length;
        } catch (_) {
          return 0;
        }
      });
}
