import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:filedroid/models/android_device.dart';
import 'package:filedroid/models/android_file.dart';
import 'package:filedroid/providers/device_provider.dart';
import 'package:filedroid/providers/file_browser_provider.dart';
import 'package:filedroid/providers/transfer_provider.dart';
import 'package:filedroid/services/adb_service.dart';
import 'package:filedroid/utils/theme.dart';

class MockAdbService extends Mock implements AdbService {}

/// Configures a MockAdbService with sensible defaults for widget tests.
MockAdbService createMockAdb() {
  final mock = MockAdbService();

  // Defaults that prevent errors
  when(() => mock.isAdbAvailable()).thenAnswer((_) async => true);
  when(() => mock.getAdbVersion()).thenAnswer((_) async => '35.0.2');
  when(() => mock.startServer()).thenAnswer((_) async => true);
  when(() => mock.listDevices()).thenAnswer((_) async => []);
  when(() => mock.listFiles(any())).thenAnswer((_) async => []);
  when(() => mock.setActiveDevice(any())).thenReturn(null);
  when(() => mock.getStorageInfo()).thenAnswer((_) async => null);
  when(() => mock.createDirectory(any())).thenAnswer((_) async => true);
  when(() => mock.delete(any(), recursive: any(named: 'recursive')))
      .thenAnswer((_) async => true);
  when(() => mock.rename(any(), any())).thenAnswer((_) async => true);
  when(() => mock.cancelCurrentTransfer()).thenReturn(null);
  when(() => mock.getRemoteFileSize(any())).thenAnswer((_) async => 0);
  when(() => mock.setCustomAdbPath(any())).thenAnswer((_) async => false);

  return mock;
}

/// Creates a DeviceProvider from a mock. Call initialize() separately if needed.
DeviceProvider createDeviceProvider(MockAdbService adb) {
  return DeviceProvider(adb);
}

/// Creates a FileBrowserProvider from a mock.
FileBrowserProvider createBrowserProvider(MockAdbService adb) {
  return FileBrowserProvider(adb);
}

/// Creates a TransferProvider from a mock.
TransferProvider createTransferProvider(MockAdbService adb) {
  return TransferProvider(adb);
}

/// Pump a widget wrapped in providers and MacosApp/MaterialApp.
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  DeviceProvider? deviceProvider,
  FileBrowserProvider? browserProvider,
  TransferProvider? transferProvider,
  MockAdbService? adb,
}) async {
  final mockAdb = adb ?? createMockAdb();
  final devProv = deviceProvider ?? createDeviceProvider(mockAdb);
  final browProv = browserProvider ?? createBrowserProvider(mockAdb);
  final transProv = transferProvider ?? createTransferProvider(mockAdb);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<DeviceProvider>.value(value: devProv),
        ChangeNotifierProvider<FileBrowserProvider>.value(value: browProv),
        ChangeNotifierProvider<TransferProvider>.value(value: transProv),
      ],
      child: MacosApp(
        theme: FileDroidTheme.macosTheme(),
        darkTheme: FileDroidTheme.macosTheme(),
        themeMode: ThemeMode.dark,
        debugShowCheckedModeBanner: false,
        home: Material(child: child),
      ),
    ),
  );
}

/// Sample files used across tests.
const sampleFiles = [
  AndroidFile(name: 'Download', path: '/sdcard/Download', isDirectory: true),
  AndroidFile(name: 'DCIM', path: '/sdcard/DCIM', isDirectory: true),
  AndroidFile(
    name: 'photo.jpg',
    path: '/sdcard/photo.jpg',
    isDirectory: false,
    size: 1024000,
    modified: null,
  ),
  AndroidFile(
    name: 'notes.txt',
    path: '/sdcard/notes.txt',
    isDirectory: false,
    size: 200,
    modified: null,
  ),
];

/// A sample online device.
const sampleDevice = AndroidDevice(
  id: 'abc123',
  model: 'Pixel 8',
  status: 'device',
  androidVersion: '14',
);

/// A sample unauthorized device.
const unauthorizedDevice = AndroidDevice(
  id: 'xyz999',
  model: 'Galaxy S24',
  status: 'unauthorized',
);

/// Sample storage info.
const sampleStorageInfo = StorageInfo(
  totalBytes: 64 * 1024 * 1024 * 1024, // 64 GB
  usedBytes: 32 * 1024 * 1024 * 1024, // 32 GB
  availableBytes: 32 * 1024 * 1024 * 1024, // 32 GB
);
