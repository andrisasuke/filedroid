import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/transfer_task.dart';
import '../services/adb_service.dart';

class TransferProvider extends ChangeNotifier {
  final AdbService _adb;
  final List<TransferTask> _tasks = [];
  bool _isTransferring = false;
  int _taskCounter = 0;

  /// Called when a transfer completes (success or fail). Listeners can refresh the file list.
  VoidCallback? onTransferComplete;

  TransferProvider(this._adb);

  List<TransferTask> get tasks => _tasks;
  bool get isTransferring => _isTransferring;

  List<TransferTask> get activeTasks =>
      _tasks.where((t) => t.status == TransferStatus.inProgress).toList();
  List<TransferTask> get queuedTasks =>
      _tasks.where((t) => t.status == TransferStatus.queued).toList();
  List<TransferTask> get completedTasks =>
      _tasks.where((t) => t.status == TransferStatus.completed).toList();
  List<TransferTask> get failedTasks =>
      _tasks.where((t) => t.status == TransferStatus.failed).toList();

  int get totalActive => activeTasks.length + queuedTasks.length;

  String get overallSpeed {
    final active = activeTasks;
    if (active.isEmpty) return '';
    double totalBps = 0;
    for (final task in active) {
      final elapsed = DateTime.now().difference(task.startedAt);
      if (elapsed.inSeconds > 0) {
        totalBps += task.transferredBytes / elapsed.inSeconds;
      }
    }
    if (totalBps < 1024) return '${totalBps.toStringAsFixed(0)} B/s';
    if (totalBps < 1024 * 1024) {
      return '${(totalBps / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(totalBps / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  Future<void> pullFiles(List<String> remotePaths, String localDir) async {
    for (final remotePath in remotePaths) {
      _taskCounter++;
      final fileName = remotePath.split('/').last;
      final task = TransferTask(
        id: 'task_$_taskCounter',
        sourcePath: remotePath,
        destPath: '$localDir/$fileName',
        fileName: fileName,
        direction: TransferDirection.toMac,
      );

      // Try to get remote file size
      try {
        task.totalBytes = await _adb.getRemoteFileSize(remotePath);
      } catch (_) {}

      _tasks.insert(0, task);
    }
    notifyListeners();
    _processQueue();
  }

  Future<void> pushFiles(List<String> localPaths, String remoteDir) async {
    for (final localPath in localPaths) {
      _taskCounter++;
      final fileName = localPath.split('/').last;
      final file = File(localPath);
      final size = await file.exists() ? await file.length() : 0;

      final task = TransferTask(
        id: 'task_$_taskCounter',
        sourcePath: localPath,
        destPath: '$remoteDir/$fileName',
        fileName: fileName,
        direction: TransferDirection.toAndroid,
        totalBytes: size,
      );

      _tasks.insert(0, task);
    }
    notifyListeners();
    _processQueue();
  }

  Future<void> _processQueue() async {
    if (_isTransferring) return;
    _isTransferring = true;

    while (true) {
      final queued = _tasks.cast<TransferTask?>().firstWhere(
            (t) => t!.status == TransferStatus.queued,
            orElse: () => null,
          );
      if (queued == null) break;

      queued.status = TransferStatus.inProgress;
      notifyListeners();

      try {
        if (queued.direction == TransferDirection.toMac) {
          await _adb.pullFileWithProgress(
            queued.sourcePath,
            queued.destPath,
            (transferred, total) {
              queued.transferredBytes = transferred;
              queued.totalBytes = total;
              notifyListeners();
            },
          );
        } else {
          await _adb.pushFileWithProgress(
            queued.sourcePath,
            queued.destPath,
            (transferred, total) {
              queued.transferredBytes = transferred;
              queued.totalBytes = total;
              notifyListeners();
            },
          );
        }
        queued.status = TransferStatus.completed;
        queued.completedAt = DateTime.now();
      } catch (e) {
        if (queued.status == TransferStatus.cancelled) {
          // Already marked as cancelled by cancelTask — keep that status
        } else {
          queued.status = TransferStatus.failed;
          queued.errorMessage = e.toString();
        }
        queued.completedAt = DateTime.now();
      }

      notifyListeners();
      onTransferComplete?.call();
    }

    _isTransferring = false;
    notifyListeners();
  }

  void cancelTask(String id) {
    final task = _tasks.cast<TransferTask?>().firstWhere(
          (t) => t!.id == id,
          orElse: () => null,
        );
    if (task != null && task.isActive) {
      final wasInProgress = task.status == TransferStatus.inProgress;
      task.status = TransferStatus.cancelled;
      task.completedAt = DateTime.now();
      if (wasInProgress) {
        _adb.cancelCurrentTransfer();
      }
      notifyListeners();
    }
  }

  void retryTask(String id) {
    final task = _tasks.cast<TransferTask?>().firstWhere(
          (t) => t!.id == id,
          orElse: () => null,
        );
    if (task != null && task.isFinished) {
      task.status = TransferStatus.queued;
      task.transferredBytes = 0;
      task.errorMessage = null;
      task.completedAt = null;
      notifyListeners();
      _processQueue();
    }
  }

  void clearFinished() {
    _tasks.removeWhere((t) => t.isFinished);
    notifyListeners();
  }
}
