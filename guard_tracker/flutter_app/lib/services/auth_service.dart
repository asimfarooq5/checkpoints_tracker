import '../models/user.dart';
import 'api_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final ApiService _api = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _userKey = 'auth_user';

  Future<User> login(String username, String password) async {
    final data = await _api.post('/auth/login', body: {
      'username': username,
      'password': password,
    });

    await _api.saveToken(data['token']);
    final user = User.fromJson(data['user']);
    await _storage.write(key: _userKey, value: userToJson(user));
    return user;
  }

  Future<void> logout() async {
    await _api.deleteToken();
    await _storage.delete(key: _userKey);
  }

  Future<User?> tryAutoLogin() async {
    final token = await _api.getToken();
    if (token == null) return null;

    try {
      final data = await _api.get('/auth/me');
      return User.fromJson(data['user']);
    } catch (_) {
      await _api.deleteToken();
      return null;
    }
  }

  String userToJson(User user) {
    return '${user.id}|${user.username}|${user.displayName}|${user.role}|${user.latitude}|${user.longitude}|${user.createdAt}';
  }

  User? userFromJson(String json) {
    final parts = json.split('|');
    if (parts.length < 7) return null;
    return User(
      id: int.parse(parts[0]),
      username: parts[1],
      displayName: parts[2],
      role: parts[3],
      latitude: double.tryParse(parts[4]),
      longitude: double.tryParse(parts[5]),
      createdAt: parts[6],
    );
  }
}
