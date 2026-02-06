import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/android_device.dart';
import '../services/adb_service.dart';

class DeviceProvider extends ChangeNotifier {
  final AdbService _adb;
  Timer? _pollTimer;

  List<AndroidDevice> _devices = [];
  AndroidDevice? _activeDevice;
  bool _isLoading = true;
  bool _adbAvailable = false;
  String? _adbVersion;
  String? _error;
  StorageInfo? _storageInfo;

  DeviceProvider(this._adb);

  List<AndroidDevice> get devices => _devices;
  AndroidDevice? get activeDevice => _activeDevice;
  bool get isLoading => _isLoading;
  bool get adbAvailable => _adbAvailable;
  String? get adbVersion => _adbVersion;
  String? get error => _error;
  StorageInfo? get storageInfo => _storageInfo;
  bool get hasDevice => _activeDevice != null && _activeDevice!.isOnline;

  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _adbAvailable = await _adb.isAdbAvailable();
      if (!_adbAvailable) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      _adbVersion = await _adb.getAdbVersion();
      await _adb.startServer();
      await refreshDevices();

      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => refreshDevices(),
      );
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshDevices() async {
    try {
      final newDevices = await _adb.listDevices();

      // Check if list actually changed
      bool changed = newDevices.length != _devices.length;
      if (!changed) {
        for (int i = 0; i < newDevices.length; i++) {
          if (newDevices[i] != _devices[i]) {
            changed = true;
            break;
          }
        }
      }

      if (!changed) return;

      _devices = newDevices;

      // Auto-select if exactly 1 online device
      final onlineDevices = _devices.where((d) => d.isOnline).toList();
      if (onlineDevices.length == 1 && _activeDevice == null) {
        await selectDevice(onlineDevices.first);
        return;
      }

      // Clear active device if it disconnected
      if (_activeDevice != null) {
        final stillPresent = _devices.any(
            (d) => d.id == _activeDevice!.id && d.isOnline);
        if (!stillPresent) {
          _activeDevice = null;
          _storageInfo = null;
          _adb.setActiveDevice(null);
        }
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> selectDevice(AndroidDevice device) async {
    _activeDevice = device;
    _adb.setActiveDevice(device.id);
    notifyListeners();

    if (device.isOnline) {
      _storageInfo = await _adb.getStorageInfo();
      notifyListeners();
    }
  }

  Future<void> retryInitialize() async {
    _adbAvailable = false;
    _adbVersion = null;
    _devices = [];
    _activeDevice = null;
    _storageInfo = null;
    _error = null;
    await initialize();
  }

  /// Set a user-chosen adb path, then re-initialize.
  Future<bool> setCustomAdbPath(String path) async {
    final ok = await _adb.setCustomAdbPath(path);
    if (ok) {
      await retryInitialize();
    }
    return ok;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
