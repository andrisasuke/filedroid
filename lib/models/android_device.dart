class AndroidDevice {
  final String id;
  final String model;
  final String status;
  final String? androidVersion;

  const AndroidDevice({
    required this.id,
    required this.model,
    required this.status,
    this.androidVersion,
  });

  bool get isOnline => status == 'device';
  bool get isUnauthorized => status == 'unauthorized';
  bool get isOffline => status == 'offline';

  String get displayName => model.isNotEmpty ? model : id;

  String get statusLabel {
    switch (status) {
      case 'device':
        return 'Connected';
      case 'unauthorized':
        return 'Unauthorized';
      case 'offline':
        return 'Offline';
      default:
        return status;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AndroidDevice && id == other.id && status == other.status;

  @override
  int get hashCode => id.hashCode ^ status.hashCode;
}
