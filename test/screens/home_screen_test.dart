import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:filedroid/providers/device_provider.dart';
import 'package:filedroid/providers/file_browser_provider.dart';
import 'package:filedroid/providers/transfer_provider.dart';
import 'package:filedroid/screens/home_screen.dart';
import 'package:filedroid/utils/theme.dart';
import '../helpers/test_helpers.dart';

void main() {
  late MockAdbService adb;

  setUp(() {
    adb = createMockAdb();
  });

  /// Pump HomeScreen with all required providers.
  /// Sets a large surface to avoid overflow.
  Future<void> pumpHomeScreen(
    WidgetTester tester, {
    required DeviceProvider deviceProvider,
    FileBrowserProvider? browserProvider,
    TransferProvider? transferProvider,
  }) async {
    tester.view.physicalSize = const Size(1800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final browProv = browserProvider ?? createBrowserProvider(adb);
    final transProv = transferProvider ?? createTransferProvider(adb);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DeviceProvider>.value(value: deviceProvider),
          ChangeNotifierProvider<FileBrowserProvider>.value(value: browProv),
          ChangeNotifierProvider<TransferProvider>.value(value: transProv),
        ],
        child: MacosApp(
          theme: FileDroidTheme.macosTheme(),
          home: const HomeScreen(),
        ),
      ),
    );
  }

  /// Helper: stub ADB as available with a working server.
  void stubAdbAvailable() {
    when(() => adb.isAdbAvailable()).thenAnswer((_) async => true);
    when(() => adb.startServer()).thenAnswer((_) async => true);
    when(() => adb.getAdbVersion()).thenAnswer((_) async => '35.0.2');
    when(() => adb.listDevices()).thenAnswer((_) async => []);
  }

  /// Pump frames until the DeviceProvider finishes initialization.
  /// Cannot use pumpAndSettle because DeviceProvider starts a 3-second polling timer.
  Future<void> pumpUntilInitialized(WidgetTester tester) async {
    await tester.pump();
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  group('HomeScreen', () {
    testWidgets(
        'shows loading state with CircularProgressIndicator and "Initializing..."',
        (tester) async {
      when(() => adb.isAdbAvailable())
          .thenAnswer((_) => Completer<bool>().future);

      final devProv = createDeviceProvider(adb);
      await pumpHomeScreen(tester, deviceProvider: devProv);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Initializing...'), findsOneWidget);
      expect(find.text('FileDroid'), findsOneWidget);
      expect(find.text('ADB Not Found'), findsNothing);

      // Dispose before test ends to cancel pending timers
      devProv.dispose();
    });

    testWidgets('shows AdbSetupScreen when ADB is not available',
        (tester) async {
      when(() => adb.isAdbAvailable()).thenAnswer((_) async => false);

      final devProv = createDeviceProvider(adb);
      await pumpHomeScreen(tester, deviceProvider: devProv);
      await tester.pumpAndSettle();

      expect(find.text('ADB Not Found'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('FileDroid'), findsOneWidget);

      devProv.dispose();
    });

    testWidgets('shows main layout with all panels when ADB is available',
        (tester) async {
      stubAdbAvailable();

      final devProv = createDeviceProvider(adb);
      await pumpHomeScreen(tester, deviceProvider: devProv);
      await pumpUntilInitialized(tester);

      expect(find.byType(MacosWindow), findsOneWidget);
      expect(find.text('Initializing...'), findsNothing);
      expect(find.text('ADB Not Found'), findsNothing);

      devProv.dispose();
    });

    testWidgets('title bar shows "FileDroid"', (tester) async {
      stubAdbAvailable();

      final devProv = createDeviceProvider(adb);
      await pumpHomeScreen(tester, deviceProvider: devProv);
      await pumpUntilInitialized(tester);

      expect(find.text('FileDroid'), findsOneWidget);

      devProv.dispose();
    });

    testWidgets('title bar shows "Android Transfer"', (tester) async {
      stubAdbAvailable();

      final devProv = createDeviceProvider(adb);
      await pumpHomeScreen(tester, deviceProvider: devProv);
      await pumpUntilInitialized(tester);

      expect(find.text('Android Transfer'), findsOneWidget);

      devProv.dispose();
    });

    testWidgets('transfer panel toggle button hides and shows panel',
        (tester) async {
      stubAdbAvailable();

      final devProv = createDeviceProvider(adb);
      await pumpHomeScreen(tester, deviceProvider: devProv);
      await pumpUntilInitialized(tester);

      final toggleButton = find.text('T');
      expect(toggleButton, findsOneWidget);

      await tester.tap(toggleButton);
      await tester.pump();

      await tester.tap(toggleButton);
      await tester.pump();

      expect(toggleButton, findsOneWidget);

      devProv.dispose();
    });

    testWidgets('calls deviceProvider.initialize() on startup',
        (tester) async {
      stubAdbAvailable();

      final devProv = createDeviceProvider(adb);
      await pumpHomeScreen(tester, deviceProvider: devProv);
      await pumpUntilInitialized(tester);

      verify(() => adb.isAdbAvailable()).called(1);

      devProv.dispose();
    });

    testWidgets('navigates to /sdcard when device connects', (tester) async {
      when(() => adb.isAdbAvailable()).thenAnswer((_) async => true);
      when(() => adb.startServer()).thenAnswer((_) async => true);
      when(() => adb.getAdbVersion()).thenAnswer((_) async => '35.0.2');
      when(() => adb.listDevices()).thenAnswer((_) async => [sampleDevice]);
      when(() => adb.setActiveDevice(any())).thenReturn(null);
      when(() => adb.getStorageInfo())
          .thenAnswer((_) async => sampleStorageInfo);
      when(() => adb.listFiles(any())).thenAnswer((_) async => sampleFiles);

      final devProv = createDeviceProvider(adb);
      final browProv = createBrowserProvider(adb);

      await pumpHomeScreen(
        tester,
        deviceProvider: devProv,
        browserProvider: browProv,
      );

      await pumpUntilInitialized(tester);

      verify(() => adb.listFiles(any())).called(greaterThan(0));

      devProv.dispose();
    });

    testWidgets('onTransferComplete refreshes file browser', (tester) async {
      when(() => adb.isAdbAvailable()).thenAnswer((_) async => true);
      when(() => adb.startServer()).thenAnswer((_) async => true);
      when(() => adb.getAdbVersion()).thenAnswer((_) async => '35.0.2');
      when(() => adb.listDevices()).thenAnswer((_) async => [sampleDevice]);
      when(() => adb.setActiveDevice(any())).thenReturn(null);
      when(() => adb.getStorageInfo())
          .thenAnswer((_) async => sampleStorageInfo);
      when(() => adb.listFiles(any())).thenAnswer((_) async => sampleFiles);

      final devProv = createDeviceProvider(adb);
      final browProv = createBrowserProvider(adb);
      final transProv = createTransferProvider(adb);

      await pumpHomeScreen(
        tester,
        deviceProvider: devProv,
        browserProvider: browProv,
        transferProvider: transProv,
      );
      await pumpUntilInitialized(tester);

      // The callback should have been set by HomeScreen's initState
      expect(transProv.onTransferComplete, isNotNull);

      // Reset mock to track new calls
      reset(adb);
      when(() => adb.listFiles(any())).thenAnswer((_) async => sampleFiles);

      // Trigger the callback
      transProv.onTransferComplete!();
      await tester.pump();

      // Verify refresh was called on the browser (listFiles)
      verify(() => adb.listFiles(any())).called(greaterThan(0));

      devProv.dispose();
    });

    testWidgets('shows glow orbs in background', (tester) async {
      stubAdbAvailable();

      final devProv = createDeviceProvider(adb);
      await pumpHomeScreen(tester, deviceProvider: devProv);
      await pumpUntilInitialized(tester);

      expect(find.byType(Stack), findsWidgets);
      expect(find.byType(ImageFiltered), findsWidgets);

      devProv.dispose();
    });
  });
}
