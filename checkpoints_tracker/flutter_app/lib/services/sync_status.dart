import 'dart:io';
import 'package:path_provider/path_provider.dart';

// Tracks the last successful sync time via a plain file instead of
// FlutterSecureStorage. Empirically, secure-storage writes made from the
// background isolate weren't reliably visible when read back from the main
// isolate afterward (last_sync_at stuck on "never" for minutes despite
// confirmed successful deliveries), while plain file reads/writes — as
// OfflineQueue already relies on for its own cross-isolate state — worked.
class SyncStatus {
  static Future<File> get _file async =>
      File('${(await getApplicationDocumentsDirectory()).path}/last_sync_at.txt');

  static Future<void> markSynced() async {
    try {
      final f = await _file;
      await f.writeAsString(DateTime.now().toIso8601String());
    } catch (_) {}
  }

  static Future<DateTime?> read() async {
    try {
      final f = await _file;
      if (!f.existsSync()) return null;
      return DateTime.tryParse(await f.readAsString());
    } catch (_) {
      return null;
    }
  }
}
