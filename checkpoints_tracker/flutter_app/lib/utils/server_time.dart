// The backend stores timestamps via SQLite's datetime('now'), which is UTC
// formatted as "YYYY-MM-DD HH:MM:SS" with no timezone marker. DateTime.parse
// treats a string like that as *local* time, not UTC, so a checkpoint
// completed at 13:02 UTC (18:02 PKT) displayed as "13:02" — off by the full
// UTC offset. Only append Z when there's no 'T', since that's the signature
// of the server's space-separated format; anything already ISO8601 (e.g.
// DateTime.now().toIso8601String()) is left alone.
DateTime? parseServerTime(String raw) {
  final iso = raw.contains('T') ? raw : '${raw.replaceFirst(' ', 'T')}Z';
  return DateTime.tryParse(iso);
}
