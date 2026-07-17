import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

// A point never survives more than this many failed retry attempts. Without a
// cap, a point the server will genuinely never accept (or some unforeseen
// persistent failure) would sit in the queue forever, permanently showing
// "N offline" in the tracking notification.
const int _maxAttempts = 20;

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
          list.add({'payload': data, 'attempts': 0});
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
          for (final raw in list) {
            final entry = raw is Map ? Map<String, dynamic>.from(raw) : {'payload': raw, 'attempts': 0};
            final payload = entry['payload'] ?? entry;
            final attempts = (entry['attempts'] as num?)?.toInt() ?? 0;

            try {
              final resp = await http.post(
                Uri.parse('${ApiConfig.baseUrl}/location'),
                headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
                body: jsonEncode(payload),
              ).timeout(ApiConfig.timeout, onTimeout: () => http.Response('', 408));

              final ok = resp.statusCode >= 200 && resp.statusCode < 300;
              // 401/403 might recover after the user re-logs in with a fresh
              // token, so keep retrying those. Other 4xx (bad payload, etc.)
              // will fail identically forever — drop them instead of
              // clogging the queue. 5xx/408 are transient — always retry.
              final isPermanentRejection =
                  resp.statusCode >= 400 && resp.statusCode < 500 && resp.statusCode != 401 && resp.statusCode != 403;

              if (!ok && !isPermanentRejection) {
                final nextAttempts = attempts + 1;
                if (nextAttempts < _maxAttempts) {
                  remaining.add({'payload': payload, 'attempts': nextAttempts});
                }
              }
            } catch (_) {
              final nextAttempts = attempts + 1;
              if (nextAttempts < _maxAttempts) {
                remaining.add({'payload': payload, 'attempts': nextAttempts});
              }
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
