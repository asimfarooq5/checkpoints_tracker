import 'dart:async';
import 'dart:convert';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

const String _channelId = 'checkpoints_tracker_service';
const String _channelName = 'Checkpoint Tracking';
const String _channelDesc = 'Guard Tracker is running in the background to send your location.';
const int _notificationId = 7410;

final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

/// Show the persistent notification (called on start and when dismissed).
Future<void> showPersistentNotification() async {
  await _notifications.show(
    _notificationId,
    'Guard Tracker',
    'Tracking your checkpoints...',
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

  // Show persistent notification immediately
  await showPersistentNotification();

  Timer.periodic(const Duration(minutes: 5), (timer) async {
    final token = await storage.read(key: 'auth_token');
    if (token == null) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final base = ApiConfig.baseUrl;
      final uri = Uri.parse('$base/checkpoints');
      final response = await http
          .get(uri, headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'})
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map;
        final checkpoints = data['checkpoints'] as List;
        for (final cp in checkpoints) {
          if (cp['status'] == 'pending') {
            final checkinUri = Uri.parse('$base/checkpoints/${cp['id']}/checkin');
            await http.patch(
              checkinUri,
              headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
              body: jsonEncode({'latitude': position.latitude, 'longitude': position.longitude}),
            ).timeout(ApiConfig.timeout);
          }
        }
      }
    } catch (_) {}

    // Update notification with timestamp
    await _notifications.show(
      _notificationId,
      'Guard Tracker',
      'Tracking — ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
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
  });

  return true;
}

Future<void> initForegroundService() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  await _notifications.initialize(
    const InitializationSettings(android: androidSettings),
    onDidReceiveNotificationResponse: (_) {
      // Tap on notification does nothing (just keeps app present)
    },
  );

  const androidChannel = AndroidNotificationChannel(
    _channelId,
    _channelName,
    description: _channelDesc,
    importance: Importance.high,
    showBadge: false,
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
      initialNotificationTitle: 'Guard Tracker',
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
