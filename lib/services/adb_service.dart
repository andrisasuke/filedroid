import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/android_device.dart';
import '../models/android_file.dart';

class AdbException implements Exception {
  final String message;
  const AdbException(this.message);
  @override
  String toString() => 'AdbException: $message';
}

class TransferResult {
  final bool success;
  final String message;
  final int bytesTransferred;

  const TransferResult({
    required this.success,
    this.message = '',
    this.bytesTransferred = 0,
  });
}

class StorageInfo {
  final int totalBytes;
  final int usedBytes;
  final int availableBytes;

  const StorageInfo({
    required this.totalBytes,
    required this.usedBytes,
    required this.availableBytes,
  });

  double get usedPercentage =>
      totalBytes > 0 ? (usedBytes / totalBytes).clamp(0.0, 1.0) : 0;

  String get formattedTotal => _formatBytes(totalBytes);
  String get formattedUsed => _formatBytes(usedBytes);
  String get formattedAvailable => _formatBytes(availableBytes);

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class AdbService {
  String? _adbPath;
  String? _activeDeviceId;
  Process? _currentTransferProcess;

  String? get activeDeviceId => _activeDeviceId;

  void setActiveDevice(String? deviceId) {
    _activeDeviceId = deviceId;
  }

  void cancelCurrentTransfer() {
    _currentTransferProcess?.kill();
    _currentTransferProcess = null;
  }

  /// Set a user-chosen adb path and persist it.
  Future<bool> setCustomAdbPath(String path) async {
    final file = File(path);
    if (!await file.exists()) return false;

    // Verify it's actually adb
    try {
      final result = await Process.run(path, ['version']);
      if (result.exitCode != 0) return false;
    } catch (_) {
      return false;
    }

    _adbPath = path;

    // Persist to config file
    try {
      final configFile = await _configFile();
      await configFile.parent.create(recursive: true);
      await configFile.writeAsString(path);
    } catch (_) {}

    return true;
  }

  Future<File> _configFile() async {
    final home = Platform.environment['HOME'] ?? '';
    return File('$home/Library/Application Support/com.filedroid/adb_path.txt');
  }

  Future<String?> _resolveAdbPath() async {
    if (_adbPath != null) return _adbPath;

    // 0. Check saved user preference
    try {
      final configFile = await _configFile();
      if (await configFile.exists()) {
        final saved = (await configFile.readAsString()).trim();
        if (saved.isNotEmpty && await File(saved).exists()) {
          _adbPath = saved;
          return _adbPath;
        }
      }
    } catch (_) {}

    // 1. Try 'which adb' via login shell (picks up user's PATH from .zshrc/.bashrc)
    for (final shell in ['/bin/zsh', '/bin/bash']) {
      try {
        final result = await Process.run(shell, ['-l', '-c', 'which adb']);
        if (result.exitCode == 0) {
          final path = (result.stdout as String).trim();
          if (path.isNotEmpty && await File(path).exists()) {
            _adbPath = path;
            return _adbPath;
          }
        }
      } catch (_) {}
    }

    // 2. Common locations
    final home = Platform.environment['HOME'] ?? '';
    final candidates = <String>[
      '$home/Library/Android/sdk/platform-tools/adb',
      '/usr/local/bin/adb',
      '/opt/homebrew/bin/adb',
    ];

    // 3. Environment variables
    final androidHome = Platform.environment['ANDROID_HOME'];
    if (androidHome != null) {
      candidates.add('$androidHome/platform-tools/adb');
    }
    final androidSdkRoot = Platform.environment['ANDROID_SDK_ROOT'];
    if (androidSdkRoot != null) {
      candidates.add('$androidSdkRoot/platform-tools/adb');
    }

    // 4. Try reading ANDROID_HOME from login shell env
    try {
      final result = await Process.run(
        '/bin/zsh', ['-l', '-c', 'echo \$ANDROID_HOME'],
      );
      if (result.exitCode == 0) {
        final envHome = (result.stdout as String).trim();
        if (envHome.isNotEmpty) {
          candidates.add('$envHome/platform-tools/adb');
        }
      }
    } catch (_) {}

    for (final candidate in candidates) {
      if (await File(candidate).exists()) {
        _adbPath = candidate;
        return _adbPath;
      }
    }

    return null;
  }

  Future<ProcessResult> _run(List<String> args,
      {int timeoutSeconds = 30}) async {
    final adb = await _resolveAdbPath();
    if (adb == null) throw const AdbException('ADB binary not found');

    final fullArgs = <String>[];
    if (_activeDeviceId != null) {
      fullArgs.addAll(['-s', _activeDeviceId!]);
    }
    fullArgs.addAll(args);

    try {
      return await Process.run(
        adb,
        fullArgs,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      ).timeout(Duration(seconds: timeoutSeconds));
    } on TimeoutException {
      throw const AdbException('ADB command timed out');
    }
  }

  Future<Process> _startProcess(List<String> args) async {
    final adb = await _resolveAdbPath();
    if (adb == null) throw const AdbException('ADB binary not found');

    final fullArgs = <String>[];
    if (_activeDeviceId != null) {
      fullArgs.addAll(['-s', _activeDeviceId!]);
    }
    fullArgs.addAll(args);

    return Process.start(adb, fullArgs);
  }

  Future<bool> isAdbAvailable() async {
    try {
      final path = await _resolveAdbPath();
      if (path == null) return false;
      final result = await Process.run(path, ['version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<String?> getAdbVersion() async {
    try {
      final adb = await _resolveAdbPath();
      if (adb == null) return null;
      final result = await Process.run(adb, ['version']);
      if (result.exitCode == 0) {
        final lines = (result.stdout as String).split('\n');
        if (lines.isNotEmpty) {
          final match = RegExp(r'(\d+\.\d+\.\d+)').firstMatch(lines.first);
          return match?.group(1);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<List<AndroidDevice>> listDevices() async {
    final result = await _run(['devices', '-l'], timeoutSeconds: 10);
    if (result.exitCode != 0) return [];

    final output = result.stdout as String;
    final lines = output.split('\n').skip(1);
    final devices = <AndroidDevice>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length < 2) continue;

      final id = parts[0];
      final status = parts[1];

      String model = '';
      for (final part in parts.skip(2)) {
        if (part.startsWith('model:')) {
          model = part.substring(6).replaceAll('_', ' ');
          break;
        }
      }

      String? androidVersion;
      if (status == 'device') {
        try {
          final savedDevice = _activeDeviceId;
          _activeDeviceId = id;
          final vResult = await _run(
            ['shell', 'getprop', 'ro.build.version.release'],
            timeoutSeconds: 5,
          );
          _activeDeviceId = savedDevice;
          if (vResult.exitCode == 0) {
            androidVersion = (vResult.stdout as String).trim();
            if (androidVersion.isEmpty) androidVersion = null;
          }
        } catch (_) {}
      }

      devices.add(AndroidDevice(
        id: id,
        model: model,
        status: status,
        androidVersion: androidVersion,
      ));
    }

    return devices;
  }

  Future<List<AndroidFile>> listFiles(String dirPath) async {
    // Append trailing '/' to follow symlinks (e.g. /sdcard -> /storage/emulated/0)
    final listPath = dirPath == '/' ? '/' : '$dirPath/';
    final result = await _run(['shell', 'ls', '-la', listPath]);

    if (result.exitCode != 0) {
      final stderr = (result.stderr as String).toLowerCase();
      if (stderr.contains('permission denied')) {
        throw AdbException('Permission denied: $dirPath');
      }
      if (stderr.contains('no such file')) {
        throw AdbException('Path not found: $dirPath');
      }
      throw AdbException('Failed to list: ${result.stderr}');
    }

    final output = result.stdout as String;
    final lines = output.split('\n');
    final files = <AndroidFile>[];

    final regex = RegExp(
      r'^([dlcbsp\-][rwxsStT\-]{9})\s+(\d+)\s+(\S+)\s+(\S+)\s+(\d+(?:,\s*\d+)?)\s+(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2})\s+(.+)$',
    );

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('total')) continue;

      AndroidFile? file;
      final match = regex.firstMatch(trimmed);
      if (match != null) {
        final permissions = match.group(1)!;
        final sizeStr = match.group(5)!.replaceAll(',', '').trim();
        final dateStr = match.group(6)!;
        final timeStr = match.group(7)!;
        var name = match.group(8)!;

        if (name == '.' || name == '..') continue;

        bool isSymlink = permissions.startsWith('l');
        if (name.contains(' -> ')) {
          name = name.split(' -> ').first;
        }

        DateTime? modified;
        try {
          modified = DateTime.parse('$dateStr $timeStr:00');
        } catch (_) {}

        int size = 0;
        try {
          size = int.parse(sizeStr);
        } catch (_) {}

        file = AndroidFile(
          name: name,
          path: dirPath == '/' ? '/$name' : '$dirPath/$name',
          isDirectory: permissions.startsWith('d'),
          size: size,
          modified: modified,
          permissions: permissions,
          isSymlink: isSymlink,
        );
      } else {
        file = _fallbackParseLine(trimmed, dirPath);
      }

      if (file != null) files.add(file);
    }

    files.sort((a, b) {
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return files;
  }

  AndroidFile? _fallbackParseLine(String line, String dirPath) {
    final parts = line.split(RegExp(r'\s+'));
    if (parts.length < 8) return null;

    var name = parts.last;
    if (name == '.' || name == '..') return null;

    final arrowIdx = parts.indexOf('->');
    if (arrowIdx > 0 && arrowIdx - 1 < parts.length) {
      name = parts[arrowIdx - 1];
    }

    final permissions = parts.first;
    final isDir = permissions.startsWith('d');
    final isSymlink = permissions.startsWith('l');

    return AndroidFile(
      name: name,
      path: dirPath == '/' ? '/$name' : '$dirPath/$name',
      isDirectory: isDir,
      isSymlink: isSymlink,
      permissions: permissions,
    );
  }

  Future<TransferResult> pullFile(String remotePath, String localPath) async {
    final result =
        await _run(['pull', remotePath, localPath], timeoutSeconds: 600);
    if (result.exitCode == 0) {
      return TransferResult(
        success: true,
        message: (result.stdout as String).trim(),
      );
    }
    return TransferResult(
      success: false,
      message: (result.stderr as String).trim(),
    );
  }

  Future<void> pullFileWithProgress(
    String remotePath,
    String localPath,
    void Function(int transferred, int total) onProgress,
  ) async {
    int totalSize = 0;
    try {
      final statResult = await _run(['shell', 'stat', '-c', '%s', remotePath]);
      if (statResult.exitCode == 0) {
        totalSize = int.tryParse((statResult.stdout as String).trim()) ?? 0;
      }
    } catch (_) {}

    final process = await _startProcess(['pull', remotePath, localPath]);
    _currentTransferProcess = process;
    bool gotAdbProgress = false;

    void parseBytes(List<int> bytes) {
      final data = utf8.decode(bytes, allowMalformed: true);
      for (final segment in data.split(RegExp(r'[\r\n]+'))) {
        final percentMatch = RegExp(r'\[\s*(\d+)%\]').firstMatch(segment);
        if (percentMatch != null && totalSize > 0) {
          gotAdbProgress = true;
          final percent = int.parse(percentMatch.group(1)!);
          onProgress((totalSize * percent / 100).round(), totalSize);
        }
      }
    }

    process.stdout.listen(parseBytes);
    process.stderr.listen(parseBytes);

    // Fallback: poll local file size if adb doesn't report progress
    Timer? pollTimer;
    if (totalSize > 0) {
      pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (gotAdbProgress) return;
        try {
          final localFile = File(localPath);
          if (localFile.existsSync()) {
            final written = localFile.lengthSync();
            onProgress(written, totalSize);
          }
        } catch (_) {}
      });
    }

    final exitCode = await process.exitCode;
    _currentTransferProcess = null;
    pollTimer?.cancel();
    if (exitCode != 0) {
      throw AdbException('Pull failed with exit code $exitCode');
    }
    if (totalSize > 0) onProgress(totalSize, totalSize);
  }

  Future<TransferResult> pushFile(String localPath, String remotePath) async {
    final result =
        await _run(['push', localPath, remotePath], timeoutSeconds: 600);
    if (result.exitCode == 0) {
      return TransferResult(
        success: true,
        message: (result.stdout as String).trim(),
      );
    }
    return TransferResult(
      success: false,
      message: (result.stderr as String).trim(),
    );
  }

  Future<void> pushFileWithProgress(
    String localPath,
    String remotePath,
    void Function(int transferred, int total) onProgress,
  ) async {
    final file = File(localPath);
    final totalSize = await file.length();

    final process = await _startProcess(['push', localPath, remotePath]);
    _currentTransferProcess = process;
    bool gotAdbProgress = false;

    void parseBytes(List<int> bytes) {
      final data = utf8.decode(bytes, allowMalformed: true);
      for (final segment in data.split(RegExp(r'[\r\n]+'))) {
        final percentMatch = RegExp(r'\[\s*(\d+)%\]').firstMatch(segment);
        if (percentMatch != null) {
          gotAdbProgress = true;
          final percent = int.parse(percentMatch.group(1)!);
          onProgress((totalSize * percent / 100).round(), totalSize);
        }
      }
    }

    process.stdout.listen(parseBytes);
    process.stderr.listen(parseBytes);

    // Fallback: poll remote file size if adb doesn't report progress
    Timer? pollTimer;
    if (totalSize > 0) {
      pollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
        if (gotAdbProgress) return;
        try {
          final savedDevice = _activeDeviceId;
          final adb = await _resolveAdbPath();
          if (adb == null) return;
          final args = <String>[];
          if (savedDevice != null) args.addAll(['-s', savedDevice]);
          args.addAll(['shell', 'stat', '-c', '%s', remotePath]);
          final result = await Process.run(adb, args,
              stdoutEncoding: utf8, stderrEncoding: utf8)
              .timeout(const Duration(seconds: 2));
          if (result.exitCode == 0) {
            final remoteSize =
                int.tryParse((result.stdout as String).trim()) ?? 0;
            if (remoteSize > 0) {
              onProgress(remoteSize, totalSize);
            }
          }
        } catch (_) {}
      });
    }

    final exitCode = await process.exitCode;
    _currentTransferProcess = null;
    pollTimer?.cancel();
    if (exitCode != 0) {
      throw AdbException('Push failed with exit code $exitCode');
    }
    onProgress(totalSize, totalSize);
  }

  Future<StorageInfo?> getStorageInfo() async {
    try {
      final result = await _run(['shell', 'df', '/sdcard']);
      if (result.exitCode != 0) return null;

      final lines = (result.stdout as String).split('\n');
      if (lines.length < 2) return null;

      final parts = lines[1].trim().split(RegExp(r'\s+'));
      if (parts.length < 4) return null;

      final totalKB = int.tryParse(parts[1]) ?? 0;
      final usedKB = int.tryParse(parts[2]) ?? 0;
      final availableKB = int.tryParse(parts[3]) ?? 0;

      return StorageInfo(
        totalBytes: totalKB * 1024,
        usedBytes: usedKB * 1024,
        availableBytes: availableKB * 1024,
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> createDirectory(String path) async {
    final result = await _run(['shell', 'mkdir', '-p', path]);
    return result.exitCode == 0;
  }

  Future<bool> delete(String path, {bool recursive = false}) async {
    final args = recursive
        ? ['shell', 'rm', '-rf', path]
        : ['shell', 'rm', path];
    final result = await _run(args);
    return result.exitCode == 0;
  }

  Future<bool> rename(String oldPath, String newPath) async {
    final result = await _run(['shell', 'mv', oldPath, newPath]);
    return result.exitCode == 0;
  }

  Future<bool> exists(String path) async {
    final result = await _run(['shell', 'test', '-e', path]);
    return result.exitCode == 0;
  }

  Future<int> getRemoteFileSize(String remotePath) async {
    try {
      final result = await _run(['shell', 'stat', '-c', '%s', remotePath]);
      if (result.exitCode == 0) {
        return int.tryParse((result.stdout as String).trim()) ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  Future<bool> startServer() async {
    try {
      final adb = await _resolveAdbPath();
      if (adb == null) return false;
      final result = await Process.run(adb, ['start-server']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<void> killServer() async {
    try {
      final adb = await _resolveAdbPath();
      if (adb == null) return;
      await Process.run(adb, ['kill-server']);
    } catch (_) {}
  }
}
