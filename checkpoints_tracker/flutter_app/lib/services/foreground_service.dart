import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/api_config.dart';
import 'offline_queue.dart';

const String _channelId = 'checkpoints_tracker_service';
const String _channelName = 'Checkpoint Tracking';
const String _channelDesc = 'Checkpoints Tracker is running in the background.';
const String _alarmChannelId = 'checkpoints_tracker_alarm';
const String _alarmChannelName = 'Location Alarm';
const String _alarmChannelDesc = 'Loud alert when location services are turned off.';
const String _checkpointChannelId = 'checkpoints_tracker_checkpoint';
const String _checkpointChannelName = 'Checkpoint Completed';
const String _checkpointChannelDesc = 'Alert with a distinct tone when a checkpoint is auto-completed.';
const int _notificationId = 7410;
const double _autoCompleteDistance = 150;

// Distinct double-buzz pattern so a completed checkpoint feels different from other alerts.
final Int64List _checkpointVibrationPattern = Int64List.fromList([0, 200, 100, 200]);

// Ceiling on how long a stationary worker can go without a location ping.
// Without this, the position stream (distanceFilter: 10) stays silent while the
// device doesn't move, and the admin dashboard can't tell "not moving" from "tracking broken".
const Duration _heartbeatInterval = Duration(minutes: 5);

enum _NotifKind { tracking, alarm, checkpoint }

final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
bool _alarmPlaying = false;
bool _alarmEnabled = false;
DateTime? _lastPositionAt;

double _haversine(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371000;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLon = (lon2 - lon1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
  return R * 2 * atan2(sqrt(a), sqrt(1 - a));
}

Future<void> _showNotif({String? msg, int? id, _NotifKind kind = _NotifKind.tracking}) async {
  final isAlarm = kind == _NotifKind.alarm;
  final isCheckpoint = kind == _NotifKind.checkpoint;
  final isTracking = kind == _NotifKind.tracking;

  final String channelId;
  final String channelName;
  final String channelDesc;
  if (isAlarm) {
    channelId = _alarmChannelId; channelName = _alarmChannelName; channelDesc = _alarmChannelDesc;
  } else if (isCheckpoint) {
    channelId = _checkpointChannelId; channelName = _checkpointChannelName; channelDesc = _checkpointChannelDesc;
  } else {
    channelId = _channelId; channelName = _channelName; channelDesc = _channelDesc;
  }

  await _notifications.show(
    id ?? _notificationId, 'Checkpoints Tracker', msg ?? 'Tracking...',
    NotificationDetails(android: AndroidNotificationDetails(
      channelId, channelName, channelDescription: channelDesc,
      importance: Importance.max, priority: Priority.max,
      playSound: !isTracking,
      enableVibration: !isTracking,
      vibrationPattern: isCheckpoint ? _checkpointVibrationPattern : null,
      ongoing: isTracking,
      showWhen: true, usesChronometer: isTracking,
      visibility: NotificationVisibility.public, fullScreenIntent: isAlarm,
      category: isAlarm ? AndroidNotificationCategory.alarm : null,
    )),
  );
}

Future<void> _playAlarm() async {
  if (_alarmPlaying || !_alarmEnabled) return;
  _alarmPlaying = true;
  await _showNotif(
    msg: '🔊 LOCATION OFF — Enable location now!',
    id: 7411, kind: _NotifKind.alarm,
  );
  // Re-trigger alarm every 30s while location is off
  Timer.periodic(const Duration(seconds: 30), (t) async {
    final locOn = await Geolocator.isLocationServiceEnabled();
    if (locOn || !_alarmEnabled) {
      _alarmPlaying = false;
      t.cancel();
      return;
    }
    await _showNotif(
      msg: '🔊 LOCATION OFF — Enable location now!',
      id: 7411, kind: _NotifKind.alarm,
    );
  });
}

Future<void> _checkAlarm(FlutterSecureStorage storage) async {
  final token = await storage.read(key: 'auth_token');
  if (token == null) return;
  try {
    final resp = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/auth/me'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    ).timeout(ApiConfig.timeout);
    if (resp.statusCode == 200) {
      final u = jsonDecode(resp.body)['user'];
      _alarmEnabled = u['alarm_enabled'] == 1 || u['alarm_enabled'] == true;
    }
  } catch (_) {}
}

Future<void> _onPosition(Position pos, FlutterSecureStorage storage) async {
  final token = await storage.read(key: 'auth_token');
  if (token == null) return;
  _lastPositionAt = DateTime.now();

  final isConnected = await Connectivity().checkConnectivity();
  final online = isConnected.any((c) => c != ConnectivityResult.none);

  final payload = {'latitude': pos.latitude, 'longitude': pos.longitude, 'timestamp': DateTime.now().toIso8601String()};

  if (!online) {
    await OfflineQueue.enqueue(payload);
    return;
  }

  // Flush any queued offline data first
  await OfflineQueue.flush();

  final base = ApiConfig.baseUrl;
  try {
    final resp = await http.post(Uri.parse('$base/location'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    ).timeout(ApiConfig.timeout, onTimeout: () => http.Response('', 408));

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      await storage.write(key: 'last_sync_at', value: DateTime.now().toIso8601String());
    } else {
      await OfflineQueue.enqueue(payload);
    }
  } catch (_) {
    await OfflineQueue.enqueue(payload);
  }

  try {
    final resp = await http.get(Uri.parse('$base/checkpoints'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    ).timeout(ApiConfig.timeout);

    if (resp.statusCode != 200) return;
    final list = (jsonDecode(resp.body) as Map)['checkpoints'] as List;
    final completed = <Map<String, dynamic>>[];

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
        completed.add(cp as Map<String, dynamic>);
      }
    }

    for (final cp in completed) {
      final label = cp['label'] as String? ?? 'Checkpoint';
      await _showNotif(
        msg: '✓ "$label" completed!',
        id: 8000 + (cp['id'] as num).toInt(),
        kind: _NotifKind.checkpoint,
      );
    }

    final t = '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}';
    await _showNotif(msg: completed.isNotEmpty ? '✓ ${completed.length} completed!' : 'Tracking — $t');
  } catch (_) {
    await _showNotif(msg: 'Tracking...');
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

  await _showNotif();
  await _checkAlarm(storage);

  try {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        timeLimit: null,
      ),
    ).listen((pos) => _onPosition(pos, storage), onError: (_) {});
  } catch (_) {}

  // 30s timer: check location status + alarm + flush offline data
  Timer.periodic(const Duration(seconds: 30), (_) async {
    final locOn = await Geolocator.isLocationServiceEnabled();
    await _checkAlarm(storage);

    if (!locOn) {
      await _showNotif(msg: '⚠ Location OFF — tap to enable');
      if (_alarmEnabled) await _playAlarm();
      return;
    }
    _alarmPlaying = false;

    // Heartbeat: force a location ping if nothing has gone out recently. The
    // position stream only fires on movement (distanceFilter: 10), so a
    // stationary-but-healthy worker would otherwise go silent indefinitely.
    final lastPos = _lastPositionAt;
    if (lastPos == null || DateTime.now().difference(lastPos) >= _heartbeatInterval) {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
        );
        await _onPosition(pos, storage);
      } catch (_) {}
    } else {
      // Try to flush offline data
      await OfflineQueue.flush();
    }

    final count = await OfflineQueue.count();
    final t = '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}';
    await _showNotif(msg: count > 0 ? 'Tracking — $t ($count offline)' : 'Tracking — $t');
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
  const alarmCh = AndroidNotificationChannel(_alarmChannelId, _alarmChannelName,
    description: _alarmChannelDesc, importance: Importance.max,
    playSound: true, enableVibration: true,
    audioAttributesUsage: AudioAttributesUsage.alarm);
  final checkpointCh = AndroidNotificationChannel(_checkpointChannelId, _checkpointChannelName,
    description: _checkpointChannelDesc, importance: Importance.high,
    playSound: true, enableVibration: true,
    sound: const RawResourceAndroidNotificationSound('checkpoint_complete'),
    vibrationPattern: _checkpointVibrationPattern);
  final plugin = _notifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await plugin?.createNotificationChannel(ch);
  await plugin?.createNotificationChannel(alarmCh);
  await plugin?.createNotificationChannel(checkpointCh);

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

Future<DateTime?> getLastSyncAt() async {
  const storage = FlutterSecureStorage();
  final raw = await storage.read(key: 'last_sync_at');
  if (raw == null) return null;
  return DateTime.tryParse(raw);
}
