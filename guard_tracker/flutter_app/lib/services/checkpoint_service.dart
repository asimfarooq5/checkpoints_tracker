import '../models/checkpoint.dart';
import 'api_service.dart';

class CheckpointService {
  final ApiService _api = ApiService();

  Future<List<Checkpoint>> fetchCheckpoints() async {
    final data = await _api.get('/checkpoints');
    final list = data['checkpoints'] as List;
    return list.map((c) => Checkpoint.fromJson(c)).toList();
  }

  Future<Checkpoint> updateStatus(int id, String status) async {
    final data = await _api.patch('/checkpoints/$id/status', body: {'status': status});
    return Checkpoint.fromJson(data['checkpoint']);
  }

  Future<Checkpoint> checkIn(int id, double latitude, double longitude) async {
    final data = await _api.patch('/checkpoints/$id/checkin', body: {
      'latitude': latitude,
      'longitude': longitude,
    });
    return Checkpoint.fromJson(data['checkpoint']);
  }
}
