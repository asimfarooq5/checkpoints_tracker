import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/checkpoint.dart';
import '../services/checkpoint_service.dart';

class CheckpointProvider extends ChangeNotifier {
  final CheckpointService _service = CheckpointService();

  List<Checkpoint> _checkpoints = [];
  bool _isLoading = false;
  String? _error;

  List<Checkpoint> get checkpoints => _checkpoints;
  List<Checkpoint> get pendingCheckpoints => _checkpoints.where((c) => !c.isCompleted).toList();
  List<Checkpoint> get completedCheckpoints => _checkpoints.where((c) => c.isCompleted).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadCheckpoints() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _checkpoints = await _service.fetchCheckpoints();
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> markCompleted(int id) async {
    try {
      final updated = await _service.updateStatus(id, 'completed');
      final index = _checkpoints.indexWhere((c) => c.id == id);
      if (index != -1) {
        _checkpoints[index] = updated;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> checkIn(int id) async {
    try {
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      );
      final updated = await _service.checkIn(id, position.latitude, position.longitude);
      final index = _checkpoints.indexWhere((c) => c.id == id);
      if (index != -1) {
        _checkpoints[index] = updated;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> checkInAllPending() async {
    final pending = pendingCheckpoints;
    for (final cp in pending) {
      await checkIn(cp.id);
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
