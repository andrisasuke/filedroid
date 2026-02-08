import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:filedroid/providers/device_provider.dart';
import 'package:filedroid/services/adb_service.dart';
import 'package:filedroid/models/android_device.dart';

class MockAdbService extends Mock implements AdbService {}

void main() {
  late MockAdbService mockAdb;
  late DeviceProvider provider;

  setUp(() {
    mockAdb = MockAdbService();
    provider = DeviceProvider(mockAdb);
  });

  // Use a flag to avoid double-dispose in dispose group tests
  bool disposedInTest = false;

  tearDown(() {
    if (!disposedInTest) {
      provider.dispose();
    }
    disposedInTest = false;
  });

  group('DeviceProvider', () {
    group('initial state', () {
      test('has empty devices list', () {
        expect(provider.devices, isEmpty);
      });

      test('has no active device', () {
        expect(provider.activeDevice, isNull);
      });

      test('isLoading is true', () {
        expect(provider.isLoading, isTrue);
      });

      test('adbAvailable is false', () {
        expect(provider.adbAvailable, isFalse);
      });

      test('adbVersion is null', () {
        expect(provider.adbVersion, isNull);
      });

      test('error is null', () {
        expect(provider.error, isNull);
      });

      test('storageInfo is null', () {
        expect(provider.storageInfo, isNull);
      });

      test('hasDevice is false', () {
        expect(provider.hasDevice, isFalse);
      });
    });

    group('initialize', () {
      test('sets adbAvailable to false when adb not found', () async {
        when(() => mockAdb.isAdbAvailable()).thenAnswer((_) async => false);

        await provider.initialize();

        expect(provider.adbAvailable, isFalse);
        expect(provider.isLoading, isFalse);
      });

      test('succeeds when adb is available', () async {
        when(() => mockAdb.isAdbAvailable()).thenAnswer((_) async => true);
        when(() => mockAdb.getAdbVersion()).thenAnswer((_) async => '35.0.2');
        when(() => mockAdb.startServer()).thenAnswer((_) async => true);
        when(() => mockAdb.listDevices()).thenAnswer((_) async => []);

        await provider.initialize();

        expect(provider.adbAvailable, isTrue);
        expect(provider.adbVersion, '35.0.2');
        expect(provider.isLoading, isFalse);
        expect(provider.error, isNull);
      });

      test('sets error on exception', () async {
        when(() => mockAdb.isAdbAvailable()).thenThrow(Exception('crash'));

        await provider.initialize();

        expect(provider.error, isNotNull);
        expect(provider.isLoading, isFalse);
      });

      test('starts polling timer that calls refreshDevices', () {
        fakeAsync((async) {
          when(() => mockAdb.isAdbAvailable()).thenAnswer((_) async => true);
          when(() => mockAdb.getAdbVersion()).thenAnswer((_) async => '35.0.2');
          when(() => mockAdb.startServer()).thenAnswer((_) async => true);
          when(() => mockAdb.listDevices()).thenAnswer((_) async => []);

          provider.initialize();
          async.flushMicrotasks();

          // 1 call from initialize → refreshDevices
          verify(() => mockAdb.listDevices()).called(1);

          // Advance past one poll interval (3 seconds)
          async.elapse(const Duration(seconds: 4));

          // Timer callback fired → refreshDevices called again
          verify(() => mockAdb.listDevices()).called(1);
        });
      });
    });

    group('refreshDevices', () {
      setUp(() {
        // Initialize first
        when(() => mockAdb.isAdbAvailable()).thenAnswer((_) async => true);
        when(() => mockAdb.getAdbVersion()).thenAnswer((_) async => '35.0.2');
        when(() => mockAdb.startServer()).thenAnswer((_) async => true);
      });

      test('does not notify when device list unchanged', () async {
        when(() => mockAdb.listDevices()).thenAnswer((_) async => []);

        await provider.initialize();

        int notifyCount = 0;
        provider.addListener(() => notifyCount++);

        await provider.refreshDevices();

        expect(notifyCount, 0);
      });

      test('auto-selects single online device', () async {
        const device = AndroidDevice(id: 'abc', model: 'Pixel 6', status: 'device');
        when(() => mockAdb.listDevices()).thenAnswer((_) async => [device]);
        when(() => mockAdb.setActiveDevice(any())).thenReturn(null);
        when(() => mockAdb.getStorageInfo()).thenAnswer(
          (_) async => const StorageInfo(totalBytes: 1000, usedBytes: 500, availableBytes: 500),
        );

        await provider.initialize();

        expect(provider.activeDevice, device);
        expect(provider.hasDevice, isTrue);
      });

      test('clears active device when it disconnects', () async {
        const device = AndroidDevice(id: 'abc', model: 'Pixel 6', status: 'device');
        when(() => mockAdb.setActiveDevice(any())).thenReturn(null);
        when(() => mockAdb.getStorageInfo()).thenAnswer(
          (_) async => const StorageInfo(totalBytes: 1000, usedBytes: 500, availableBytes: 500),
        );

        // First call returns device
        when(() => mockAdb.listDevices()).thenAnswer((_) async => [device]);
        await provider.initialize();
        expect(provider.activeDevice, device);

        // Second call returns empty (device disconnected)
        when(() => mockAdb.listDevices()).thenAnswer((_) async => []);
        await provider.refreshDevices();

        expect(provider.activeDevice, isNull);
        expect(provider.storageInfo, isNull);
        expect(provider.hasDevice, isFalse);
      });

      test('detects change when same length but different content', () async {
        const deviceA = AndroidDevice(id: '1', model: 'Pixel', status: 'device');
        const deviceB = AndroidDevice(id: '2', model: 'Galaxy', status: 'device');
        when(() => mockAdb.setActiveDevice(any())).thenReturn(null);
        when(() => mockAdb.getStorageInfo()).thenAnswer((_) async => null);

        // First: two devices
        when(() => mockAdb.listDevices()).thenAnswer((_) async => [deviceA, deviceB]);
        await provider.initialize();
        expect(provider.devices.length, 2);

        // Second: same length but device B changed status
        const deviceBOffline = AndroidDevice(id: '2', model: 'Galaxy', status: 'offline');
        when(() => mockAdb.listDevices()).thenAnswer((_) async => [deviceA, deviceBOffline]);
        await provider.refreshDevices();

        expect(provider.devices[1].status, 'offline');
      });

      test('keeps active device when it remains online', () async {
        const device = AndroidDevice(id: 'abc', model: 'Pixel 6', status: 'device');
        const device2 = AndroidDevice(id: 'xyz', model: 'Galaxy', status: 'device');
        when(() => mockAdb.setActiveDevice(any())).thenReturn(null);
        when(() => mockAdb.getStorageInfo()).thenAnswer(
          (_) async => const StorageInfo(totalBytes: 1000, usedBytes: 500, availableBytes: 500),
        );

        // Single device, auto-selected
        when(() => mockAdb.listDevices()).thenAnswer((_) async => [device]);
        await provider.initialize();
        expect(provider.activeDevice, device);

        // Add another device, active remains
        when(() => mockAdb.listDevices()).thenAnswer((_) async => [device, device2]);
        await provider.refreshDevices();
        expect(provider.activeDevice, device);
      });

      test('does not auto-select when multiple online devices', () async {
        const device1 = AndroidDevice(id: '1', model: 'Pixel 6', status: 'device');
        const device2 = AndroidDevice(id: '2', model: 'Galaxy S24', status: 'device');
        when(() => mockAdb.listDevices()).thenAnswer((_) async => [device1, device2]);

        await provider.initialize();

        expect(provider.activeDevice, isNull);
        expect(provider.devices.length, 2);
      });

      test('sets error on exception', () async {
        when(() => mockAdb.listDevices()).thenAnswer((_) async => []);
        await provider.initialize();

        when(() => mockAdb.listDevices()).thenThrow(Exception('network error'));
        await provider.refreshDevices();

        expect(provider.error, isNotNull);
      });
    });

    group('selectDevice', () {
      test('sets active device and fetches storage info', () async {
        const device = AndroidDevice(id: 'abc', model: 'Pixel 6', status: 'device');
        when(() => mockAdb.setActiveDevice(any())).thenReturn(null);
        when(() => mockAdb.getStorageInfo()).thenAnswer(
          (_) async => const StorageInfo(totalBytes: 64000, usedBytes: 32000, availableBytes: 32000),
        );

        await provider.selectDevice(device);

        expect(provider.activeDevice, device);
        expect(provider.storageInfo, isNotNull);
        expect(provider.storageInfo!.totalBytes, 64000);
        verify(() => mockAdb.setActiveDevice('abc')).called(1);
      });

      test('does not fetch storage for offline device', () async {
        const device = AndroidDevice(id: 'abc', model: 'Pixel 6', status: 'offline');
        when(() => mockAdb.setActiveDevice(any())).thenReturn(null);

        await provider.selectDevice(device);

        expect(provider.activeDevice, device);
        verifyNever(() => mockAdb.getStorageInfo());
      });
    });

    group('hasDevice', () {
      test('returns false when no active device', () {
        expect(provider.hasDevice, isFalse);
      });

      test('returns true when active device is online', () async {
        const device = AndroidDevice(id: '1', model: '', status: 'device');
        when(() => mockAdb.setActiveDevice(any())).thenReturn(null);
        when(() => mockAdb.getStorageInfo()).thenAnswer((_) async => null);

        await provider.selectDevice(device);

        expect(provider.hasDevice, isTrue);
      });

      test('returns false when active device is not online', () async {
        const device = AndroidDevice(id: '1', model: '', status: 'unauthorized');
        when(() => mockAdb.setActiveDevice(any())).thenReturn(null);

        await provider.selectDevice(device);

        expect(provider.hasDevice, isFalse);
      });
    });

    group('retryInitialize', () {
      test('resets all state and re-initializes', () async {
        // First initialize
        when(() => mockAdb.isAdbAvailable()).thenAnswer((_) async => true);
        when(() => mockAdb.getAdbVersion()).thenAnswer((_) async => '35.0.2');
        when(() => mockAdb.startServer()).thenAnswer((_) async => true);
        const device = AndroidDevice(id: '1', model: 'Pixel', status: 'device');
        when(() => mockAdb.listDevices()).thenAnswer((_) async => [device]);
        when(() => mockAdb.setActiveDevice(any())).thenReturn(null);
        when(() => mockAdb.getStorageInfo()).thenAnswer(
          (_) async => const StorageInfo(totalBytes: 1000, usedBytes: 500, availableBytes: 500),
        );

        await provider.initialize();
        expect(provider.adbAvailable, isTrue);
        expect(provider.activeDevice, isNotNull);

        // Now retry but adb not available
        when(() => mockAdb.isAdbAvailable()).thenAnswer((_) async => false);
        await provider.retryInitialize();

        expect(provider.adbAvailable, isFalse);
        expect(provider.adbVersion, isNull);
        expect(provider.devices, isEmpty);
        expect(provider.activeDevice, isNull);
        expect(provider.storageInfo, isNull);
      });
    });

    group('setCustomAdbPath', () {
      test('returns true on success and re-initializes', () async {
        when(() => mockAdb.setCustomAdbPath(any())).thenAnswer((_) async => true);
        when(() => mockAdb.isAdbAvailable()).thenAnswer((_) async => true);
        when(() => mockAdb.getAdbVersion()).thenAnswer((_) async => '35.0.2');
        when(() => mockAdb.startServer()).thenAnswer((_) async => true);
        when(() => mockAdb.listDevices()).thenAnswer((_) async => []);

        final result = await provider.setCustomAdbPath('/usr/bin/adb');

        expect(result, isTrue);
        verify(() => mockAdb.setCustomAdbPath('/usr/bin/adb')).called(1);
        verify(() => mockAdb.isAdbAvailable()).called(1);
      });

      test('returns false when path invalid', () async {
        when(() => mockAdb.setCustomAdbPath(any())).thenAnswer((_) async => false);

        final result = await provider.setCustomAdbPath('/bad/path');

        expect(result, isFalse);
        verifyNever(() => mockAdb.isAdbAvailable());
      });
    });

    group('dispose', () {
      test('cancels poll timer without error', () async {
        when(() => mockAdb.isAdbAvailable()).thenAnswer((_) async => true);
        when(() => mockAdb.getAdbVersion()).thenAnswer((_) async => '35.0.2');
        when(() => mockAdb.startServer()).thenAnswer((_) async => true);
        when(() => mockAdb.listDevices()).thenAnswer((_) async => []);

        await provider.initialize();

        // Should not throw
        provider.dispose();
        disposedInTest = true;
      });

      test('dispose works without initialization', () {
        // Should not throw
        provider.dispose();
        disposedInTest = true;
      });
    });
  });
}
