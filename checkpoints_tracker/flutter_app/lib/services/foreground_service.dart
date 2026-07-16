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
const double _autoCompleteDistance = 150; // meters

final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

double _haversine(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371000;
  final dLat = _toRad(lat2 - lat1);
  final dLon = _toRad(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
  return R * 2 * atan2(sqrt(a), sqrt(1 - a));
}

double _toRad(double deg) => deg * pi / 180;

Future<void> showPersistentNotification({String? message}) async {
  await _notifications.show(
    _notificationId,
    'Checkpoints Tracker',
    message ?? 'Tracking your checkpoints...',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.max,
        playSound: false,
        enableVibration: false,
        ongoing: true,
        showWhen: true,
        usesChronometer: true,
        visibility: NotificationVisibility.public,
        fullScreenIntent: true,
      ),
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> foregroundServiceMain(ServiceInstance service) async {
  final storage = FlutterSecureStorage();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((_) => service.setAsForegroundService());
    service.on('setAsBackground').listen((_) => service.setAsBackgroundService());
  }
  service.on('stopService').listen((_) => service.stopSelf());

  await showPersistentNotification();

  // Unified 30s timer: location push + proximity check + notification pin
  Timer.periodic(const Duration(seconds: 30), (_) async {
    final token = await storage.read(key: 'auth_token');
    if (token == null) return;

    final locationEnabled = await Geolocator.isLocationServiceEnabled();
    if (!locationEnabled) {
      await showPersistentNotification(message: '⚠ Location is OFF — tracking paused');
      return;
    }

    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
      );
    } catch (_) {
      await showPersistentNotification(message: '⚠ Cannot get location — retrying...');
      return;
    }

    final base = ApiConfig.baseUrl;
    int completed = 0;

    // 1. Push location
    try {
      await http
          .post(Uri.parse('$base/location'),
              headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
              body: jsonEncode({'latitude': position.latitude, 'longitude': position.longitude}))
          .timeout(ApiConfig.timeout);
    } catch (_) {}

    // 2. Fetch checkpoints + check proximity
    try {
      final uri = Uri.parse('$base/checkpoints');
      final response = await http
          .get(uri, headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'})
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map;
        final checkpoints = data['checkpoints'] as List;

        for (final cp in checkpoints) {
          if (cp['status'] != 'pending') continue;
          final cpLat = (cp['latitude'] as num).toDouble();
          final cpLng = (cp['longitude'] as num).toDouble();
          final distance = _haversine(position.latitude, position.longitude, cpLat, cpLng);

          // Always check-in
          try {
            await http
                .patch(Uri.parse('$base/checkpoints/${cp['id']}/checkin'),
                    headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
                    body: jsonEncode({'latitude': position.latitude, 'longitude': position.longitude}))
                .timeout(ApiConfig.timeout);
          } catch (_) {}

          // Auto-complete if within 150m
          if (distance <= _autoCompleteDistance) {
            try {
              await http
                  .patch(Uri.parse('$base/checkpoints/${cp['id']}/status'),
                      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
                      body: jsonEncode({'status': 'completed'}))
                  .timeout(ApiConfig.timeout);
              completed++;
            } catch (_) {}
          }
        }
      }
    } catch (_) {}

    final time = '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}';
    final msg = completed > 0
        ? '✓ $completed checkpoint(s) auto-completed!'
        : 'Tracking — $time';
    await showPersistentNotification(message: msg);
  });

  return true;
}

Future<void> initForegroundService() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  await _notifications.initialize(
    const InitializationSettings(android: androidSettings),
    onDidReceiveNotificationResponse: (response) async {
      // Notification tapped — open location settings if location is off
      final locationOn = await Geolocator.isLocationServiceEnabled();
      if (!locationOn) {
        await Geolocator.openLocationSettings();
      } else {
        FlutterBackgroundService().invoke('setAsForeground');
      }
    },
  );

  const androidChannel = AndroidNotificationChannel(
    _channelId,
    _channelName,
    description: _channelDesc,
    importance: Importance.high,
    playSound: false,
    enableVibration: false,
  );

  await _notifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(androidChannel);

  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      autoStart: true,
      isForegroundMode: true,
      autoStartOnBoot: true,
      notificationChannelId: _channelId,
      initialNotificationTitle: 'Checkpoints Tracker',
      initialNotificationContent: 'Tracking your checkpoints...',
      foregroundServiceNotificationId: _notificationId,
      onStart: foregroundServiceMain,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: foregroundServiceMain,
      onBackground: foregroundServiceMain,
    ),
  );

  service.startService();
}

Future<bool> isServiceRunning() async {
  final service = FlutterBackgroundService();
  return await service.isRunning();
}
