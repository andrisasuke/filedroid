import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:filedroid/widgets/device_panel.dart';
import 'package:mocktail/mocktail.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('DevicePanel', () {
    late MockAdbService mockAdb;

    setUp(() {
      mockAdb = createMockAdb();
    });

    testWidgets('shows no device state with placeholder text', (tester) async {
      final deviceProv = createDeviceProvider(mockAdb);
      await pumpApp(tester, const DevicePanel(), deviceProvider: deviceProv, adb: mockAdb);
      await tester.pumpAndSettle();

      expect(find.text('[phone]'), findsOneWidget);
      expect(find.text('No Device Connected'), findsOneWidget);
      expect(find.text('Connect via USB cable'), findsOneWidget);
    });

    testWidgets('shows online device with model name and Android version', (tester) async {
      when(() => mockAdb.getStorageInfo()).thenAnswer((_) async => null);

      final deviceProv = createDeviceProvider(mockAdb);
      await deviceProv.selectDevice(sampleDevice);
      await pumpApp(tester, const DevicePanel(), deviceProvider: deviceProv, adb: mockAdb);
      await tester.pumpAndSettle();

      expect(find.text('Pixel 8'), findsOneWidget);
      expect(find.textContaining('Android 14'), findsOneWidget);
      expect(find.text('abc123'), findsOneWidget);
    });

    testWidgets('shows unauthorized device with warning text', (tester) async {
      final deviceProv = createDeviceProvider(mockAdb);
      await deviceProv.selectDevice(unauthorizedDevice);
      await pumpApp(tester, const DevicePanel(), deviceProvider: deviceProv, adb: mockAdb);
      await tester.pumpAndSettle();

      expect(find.text('Galaxy S24'), findsOneWidget);
      expect(find.text('Unauthorized'), findsOneWidget);
      expect(find.text('Check phone for prompt'), findsOneWidget);
    });

    testWidgets('displays storage bar when device has storage info', (tester) async {
      when(() => mockAdb.getStorageInfo()).thenAnswer((_) async => sampleStorageInfo);

      final deviceProv = createDeviceProvider(mockAdb);
      await deviceProv.selectDevice(sampleDevice);
      await pumpApp(tester, const DevicePanel(), deviceProvider: deviceProv, adb: mockAdb);
      await tester.pumpAndSettle();

      expect(find.text('STORAGE'), findsOneWidget);
      expect(find.textContaining('32.0 GB / 64.0 GB'), findsOneWidget);
      expect(find.textContaining('32.0 GB available'), findsOneWidget);
    });

    testWidgets('does not show storage bar when no storage info', (tester) async {
      when(() => mockAdb.getStorageInfo()).thenAnswer((_) async => null);

      final deviceProv = createDeviceProvider(mockAdb);
      await deviceProv.selectDevice(sampleDevice);
      await pumpApp(tester, const DevicePanel(), deviceProvider: deviceProv, adb: mockAdb);
      await tester.pumpAndSettle();

      expect(find.text('STORAGE'), findsNothing);
    });

    testWidgets('renders all 7 quick access items', (tester) async {
      final deviceProv = createDeviceProvider(mockAdb);
      await pumpApp(tester, const DevicePanel(), deviceProvider: deviceProv, adb: mockAdb);
      await tester.pumpAndSettle();

      expect(find.text('QUICK ACCESS'), findsOneWidget);
      expect(find.text('Internal Storage'), findsOneWidget);
      expect(find.text('Downloads'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Pictures'), findsOneWidget);
      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('Music'), findsOneWidget);
      expect(find.text('Movies'), findsOneWidget);
    });

    testWidgets('quick access tap triggers navigation', (tester) async {
      when(() => mockAdb.listFiles(any())).thenAnswer((_) async => []);

      final deviceProv = createDeviceProvider(mockAdb);
      final browserProv = createBrowserProvider(mockAdb);

      await pumpApp(
        tester,
        const DevicePanel(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: mockAdb,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Downloads'));
      await tester.pumpAndSettle();

      verify(() => mockAdb.listFiles('/sdcard/Download')).called(1);
    });

    testWidgets('displays ADB version in footer', (tester) async {
      when(() => mockAdb.getAdbVersion()).thenAnswer((_) async => '35.0.2');

      final deviceProv = createDeviceProvider(mockAdb);
      deviceProv.initialize();

      // Pump until initialize completes (don't use pumpAndSettle — polling timer)
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      await pumpApp(tester, const DevicePanel(), deviceProvider: deviceProv, adb: mockAdb);
      await tester.pump();

      expect(find.text('adb 35.0.2 \u2022 Platform Tools'), findsOneWidget);

      deviceProv.dispose();
    });

    testWidgets('shows empty ADB version when not available', (tester) async {
      final deviceProv = createDeviceProvider(mockAdb);
      await pumpApp(tester, const DevicePanel(), deviceProvider: deviceProv, adb: mockAdb);
      await tester.pumpAndSettle();

      expect(find.text('adb 35.0.2 • Platform Tools'), findsNothing);
    });

    testWidgets('highlights active quick access item', (tester) async {
      when(() => mockAdb.listFiles(any())).thenAnswer((_) async => []);

      final deviceProv = createDeviceProvider(mockAdb);
      final browserProv = createBrowserProvider(mockAdb);
      await browserProv.navigateTo('/sdcard/Download/');

      await pumpApp(
        tester,
        const DevicePanel(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: mockAdb,
      );
      await tester.pumpAndSettle();

      // Find the Downloads quick access item container
      final downloadsItem = find.ancestor(
        of: find.text('Downloads'),
        matching: find.byType(AnimatedContainer),
      ).first;

      final container = tester.widget<AnimatedContainer>(downloadsItem);
      final decoration = container.decoration as BoxDecoration;

      // Active item should have indigo-tinted background and left border
      expect(decoration.color, isNotNull);
      expect(decoration.border, isNotNull);
      final border = decoration.border as Border;
      expect(border.left.width, equals(3));
    });

    testWidgets('inactive quick access items have no border', (tester) async {
      when(() => mockAdb.listFiles(any())).thenAnswer((_) async => []);

      final deviceProv = createDeviceProvider(mockAdb);
      final browserProv = createBrowserProvider(mockAdb);
      await browserProv.navigateTo('/sdcard/Download/');

      await pumpApp(
        tester,
        const DevicePanel(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: mockAdb,
      );
      await tester.pumpAndSettle();

      // Find the Music quick access item (inactive)
      final musicItem = find.ancestor(
        of: find.text('Music'),
        matching: find.byType(AnimatedContainer),
      ).first;

      final container = tester.widget<AnimatedContainer>(musicItem);
      final decoration = container.decoration as BoxDecoration;

      // Inactive item should have transparent background and transparent border
      expect(decoration.color, equals(Colors.transparent));
      final border = decoration.border as Border;
      expect(border.left.color, equals(Colors.transparent));
    });

    testWidgets('quick access item changes background on hover', (tester) async {
      final deviceProv = createDeviceProvider(mockAdb);
      final browserProv = createBrowserProvider(mockAdb);

      await pumpApp(
        tester,
        const DevicePanel(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: mockAdb,
      );
      await tester.pumpAndSettle();

      // Find the Music quick access AnimatedContainer (inactive, not hovered)
      final musicContainer = find.ancestor(
        of: find.text('Music'),
        matching: find.byType(AnimatedContainer),
      ).first;

      // Verify initial state is transparent
      final beforeWidget = tester.widget<AnimatedContainer>(musicContainer);
      final beforeDecoration = beforeWidget.decoration as BoxDecoration;
      expect(beforeDecoration.color, equals(Colors.transparent));

      // Hover over the Music item
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.text('Music')));
      await tester.pump();

      // After hover, the AnimatedContainer decoration should have a non-transparent color
      final afterWidget = tester.widget<AnimatedContainer>(musicContainer);
      final afterDecoration = afterWidget.decoration as BoxDecoration;
      expect(afterDecoration.color, isNot(equals(Colors.transparent)));
    });

    testWidgets('quick access item removes hover on exit', (tester) async {
      final deviceProv = createDeviceProvider(mockAdb);
      final browserProv = createBrowserProvider(mockAdb);

      await pumpApp(
        tester,
        const DevicePanel(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: mockAdb,
      );
      await tester.pumpAndSettle();

      // Hover over the Music item
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.text('Music')));
      await tester.pump();

      final musicContainer = find.ancestor(
        of: find.text('Music'),
        matching: find.byType(AnimatedContainer),
      ).first;

      // Verify hovered state is non-transparent
      final hoveredWidget = tester.widget<AnimatedContainer>(musicContainer);
      final hoveredDecoration = hoveredWidget.decoration as BoxDecoration;
      expect(hoveredDecoration.color, isNot(equals(Colors.transparent)));

      // Move mouse away to trigger onExit
      await gesture.moveTo(const Offset(500, 500));
      await tester.pump();

      // After exit, should return to transparent
      final afterExitWidget = tester.widget<AnimatedContainer>(musicContainer);
      final afterExitDecoration = afterExitWidget.decoration as BoxDecoration;
      expect(afterExitDecoration.color, equals(Colors.transparent));
    });

    group('quick access navigation for all items', () {
      final testCases = [
        ('Internal Storage', '/sdcard'),
        ('Camera', '/sdcard/DCIM'),
        ('Pictures', '/sdcard/Pictures'),
        ('Documents', '/sdcard/Documents'),
        ('Music', '/sdcard/Music'),
        ('Movies', '/sdcard/Movies'),
      ];

      for (final testCase in testCases) {
        final label = testCase.$1;
        final expectedPath = testCase.$2;

        testWidgets('tapping "$label" navigates to $expectedPath', (tester) async {
          when(() => mockAdb.listFiles(any())).thenAnswer((_) async => []);

          final deviceProv = createDeviceProvider(mockAdb);
          final browserProv = createBrowserProvider(mockAdb);

          await pumpApp(
            tester,
            const DevicePanel(),
            deviceProvider: deviceProv,
            browserProvider: browserProv,
            adb: mockAdb,
          );
          await tester.pumpAndSettle();

          await tester.tap(find.text(label));
          await tester.pumpAndSettle();

          verify(() => mockAdb.listFiles(expectedPath)).called(1);
        });
      }
    });
  });
}
