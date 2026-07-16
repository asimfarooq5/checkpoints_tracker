import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

const String _channelId = 'checkpoints_tracker_service';
const String _channelName = 'Checkpoint Tracking';
const String _channelDesc = 'Checkpoints Tracker is running in the background.';
const int _notificationId = 7410;
const double _autoCompleteDistance = 150;

final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

double _haversine(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371000;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLon = (lon2 - lon1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
  return R * 2 * atan2(sqrt(a), sqrt(1 - a));
}

Future<void> showNotif({String? msg}) async {
  await _notifications.show(
    _notificationId, 'Checkpoints Tracker', msg ?? 'Tracking...',
    const NotificationDetails(android: AndroidNotificationDetails(
      _channelId, _channelName, channelDescription: _channelDesc,
      importance: Importance.max, priority: Priority.max,
      playSound: false, enableVibration: false, ongoing: true,
      showWhen: true, usesChronometer: true,
      visibility: NotificationVisibility.public, fullScreenIntent: true,
    )),
  );
}

void _onPosition(Position pos, FlutterSecureStorage storage) async {
  final token = await storage.read(key: 'auth_token');
  if (token == null) return;

  final base = ApiConfig.baseUrl;
  await http.post(Uri.parse('$base/location'),
    headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    body: jsonEncode({'latitude': pos.latitude, 'longitude': pos.longitude}),
  ).timeout(ApiConfig.timeout, onTimeout: () => http.Response('', 408));

  try {
    final resp = await http.get(Uri.parse('$base/checkpoints'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    ).timeout(ApiConfig.timeout);

    if (resp.statusCode != 200) return;
    final list = (jsonDecode(resp.body) as Map)['checkpoints'] as List;
    int done = 0;

    for (final cp in list) {
      if (cp['status'] != 'pending') continue;
      final d = _haversine(pos.latitude, pos.longitude,
          (cp['latitude'] as num).toDouble(), (cp['longitude'] as num).toDouble());

      await http.patch(Uri.parse('$base/checkpoints/${cp['id']}/checkin'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'latitude': pos.latitude, 'longitude': pos.longitude}),
      ).timeout(ApiConfig.timeout, onTimeout: () => http.Response('', 408));

      if (d <= _autoCompleteDistance) {
        await http.patch(Uri.parse('$base/checkpoints/${cp['id']}/status'),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          body: jsonEncode({'status': 'completed'}),
        ).timeout(ApiConfig.timeout, onTimeout: () => http.Response('', 408));
        done++;
      }
    }

    final t = '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}';
    await showNotif(msg: done > 0 ? '✓ $done completed!' : 'Tracking — $t');
  } catch (_) {
    await showNotif(msg: 'Tracking...');
  }
}

@pragma('vm:entry-point')
Future<bool> foregroundServiceMain(ServiceInstance service) async {
  final storage = FlutterSecureStorage();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((_) => service.setAsForegroundService());
    service.on('setAsBackground').listen((_) => service.setAsBackgroundService());
  }
  service.on('stopService').listen((_) => service.stopSelf());

  await showNotif();

  // Real-time GPS stream — fires every ~10m of movement
  try {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // 10 meters
        timeLimit: null, // never stop
      ),
    ).listen((pos) => _onPosition(pos, storage), onError: (_) {});
  } catch (_) {}

  // Fallback 30s timer (fires when stationary / GPS stream is idle)
  Timer.periodic(const Duration(seconds: 30), (_) async {
    // Update notification even without GPS movement
    final locOn = await Geolocator.isLocationServiceEnabled();
    if (!locOn) {
      await showNotif(msg: '⚠ Location OFF — tap to enable');
      return;
    }
    // If stream is active, just update the notification
    final t = '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}';
    await showNotif(msg: 'Tracking — $t');
  });

  return true;
}

Future<void> initForegroundService() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  await _notifications.initialize(
    const InitializationSettings(android: androidSettings),
    onDidReceiveNotificationResponse: (resp) async {
      final locOn = await Geolocator.isLocationServiceEnabled();
      if (!locOn) { await Geolocator.openLocationSettings(); }
      else { FlutterBackgroundService().invoke('setAsForeground'); }
    },
  );

  const ch = AndroidNotificationChannel(_channelId, _channelName,
    description: _channelDesc, importance: Importance.high,
    playSound: false, enableVibration: false);
  await _notifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(ch);

  final svc = FlutterBackgroundService();
  await svc.configure(
    androidConfiguration: AndroidConfiguration(
      autoStart: true, isForegroundMode: true, autoStartOnBoot: true,
      notificationChannelId: _channelId,
      initialNotificationTitle: 'Checkpoints Tracker',
      initialNotificationContent: 'Tracking your checkpoints...',
      foregroundServiceNotificationId: _notificationId,
      onStart: foregroundServiceMain,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true, onForeground: foregroundServiceMain, onBackground: foregroundServiceMain,
    ),
  );
  svc.startService();
}

Future<bool> isServiceRunning() async => await FlutterBackgroundService().isRunning();
