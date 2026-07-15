class Checkpoint {
  final int id;
  final int userId;
  final String label;
  final double latitude;
  final double longitude;
  final String status;
  final String assignedAt;
  final String? completedAt;
  final double? lastLatitude;
  final double? lastLongitude;
  final String? lastCheckedAt;
  final String? userName;

  Checkpoint({
    required this.id,
    required this.userId,
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.assignedAt,
    this.completedAt,
    this.lastLatitude,
    this.lastLongitude,
    this.lastCheckedAt,
    this.userName,
  });

  bool get isCompleted => status == 'completed';

  factory Checkpoint.fromJson(Map<String, dynamic> json) {
    return Checkpoint(
      id: json['id'],
      userId: json['user_id'],
      label: json['label'],
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      status: json['status'],
      assignedAt: json['assigned_at'] ?? '',
      completedAt: json['completed_at'],
      lastLatitude: (json['last_latitude'] as num?)?.toDouble(),
      lastLongitude: (json['last_longitude'] as num?)?.toDouble(),
      lastCheckedAt: json['last_checked_at'],
      userName: json['user_name'],
    );
  }

  Checkpoint copyWith({String? status, double? lastLatitude, double? lastLongitude, String? lastCheckedAt}) {
    return Checkpoint(
      id: id,
      userId: userId,
      label: label,
      latitude: latitude,
      longitude: longitude,
      status: status ?? this.status,
      assignedAt: assignedAt,
      completedAt: status == 'completed' ? DateTime.now().toIso8601String() : completedAt,
      lastLatitude: lastLatitude ?? this.lastLatitude,
      lastLongitude: lastLongitude ?? this.lastLongitude,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      userName: userName,
    );
  }
}
