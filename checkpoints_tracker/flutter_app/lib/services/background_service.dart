import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:workmanager/workmanager.dart';
import '../config/api_config.dart';
import 'offline_queue.dart';
import 'sync_status.dart';

// This is the top-level callback function required by WorkManager.
// It must be a top-level function, not a class method.
//
// Safety-net for when the OS (or an aggressive OEM battery manager) kills the
// flutter_background_service foreground service outright. WorkManager is allowed
// to run even then, so this makes a best-effort location ping every ~15 minutes
// instead of the tracker going silent until the app is reopened.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final storage = FlutterSecureStorage();
      final token = await storage.read(key: 'auth_token');
      if (token == null) return Future.value(true);

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return Future.value(true);

      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return Future.value(true);
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      final payload = {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      try {
        final resp = await http
            .post(Uri.parse('${ApiConfig.baseUrl}/location'), headers: headers, body: jsonEncode(payload))
            .timeout(ApiConfig.timeout);
        if (resp.statusCode < 200 || resp.statusCode >= 300) {
          await OfflineQueue.enqueue(payload);
        } else {
          await SyncStatus.markSynced();
          await OfflineQueue.flush();
        }
      } catch (_) {
        await OfflineQueue.enqueue(payload);
      }
    } catch (_) {
      // Best-effort only — never let this crash the WorkManager task.
    }
    return Future.value(true);
  });
}
