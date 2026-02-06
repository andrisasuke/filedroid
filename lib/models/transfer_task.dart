enum TransferDirection { toAndroid, toMac }

enum TransferStatus { queued, inProgress, completed, failed, cancelled }

class TransferTask {
  final String id;
  final String sourcePath;
  final String destPath;
  final String fileName;
  final TransferDirection direction;
  TransferStatus status;
  int totalBytes;
  int transferredBytes;
  String? errorMessage;
  final DateTime startedAt;
  DateTime? completedAt;

  TransferTask({
    required this.id,
    required this.sourcePath,
    required this.destPath,
    required this.fileName,
    required this.direction,
    this.status = TransferStatus.queued,
    this.totalBytes = 0,
    this.transferredBytes = 0,
    this.errorMessage,
    DateTime? startedAt,
    this.completedAt,
  }) : startedAt = startedAt ?? DateTime.now();

  double get progress {
    if (totalBytes <= 0) return 0;
    return (transferredBytes / totalBytes).clamp(0.0, 1.0);
  }

  String get formattedSpeed {
    if (status != TransferStatus.inProgress) return '';
    final elapsed = DateTime.now().difference(startedAt);
    if (elapsed.inSeconds == 0) return '';
    final bytesPerSecond = transferredBytes / elapsed.inSeconds;
    if (bytesPerSecond < 1024) return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  String get formattedTotal {
    if (totalBytes <= 0) return '';
    if (totalBytes < 1024) return '$totalBytes B';
    if (totalBytes < 1024 * 1024) {
      return '${(totalBytes / 1024).toStringAsFixed(0)} KB';
    }
    if (totalBytes < 1024 * 1024 * 1024) {
      final mb = totalBytes / (1024 * 1024);
      return '${mb < 10 ? mb.toStringAsFixed(1) : mb.toStringAsFixed(0)} MB';
    }
    return '${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  bool get isActive =>
      status == TransferStatus.inProgress || status == TransferStatus.queued;
  bool get isFinished =>
      status == TransferStatus.completed ||
      status == TransferStatus.failed ||
      status == TransferStatus.cancelled;
}
