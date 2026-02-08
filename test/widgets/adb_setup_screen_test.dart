import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:filedroid/providers/device_provider.dart';
import 'package:filedroid/widgets/adb_setup_screen.dart';
import 'package:filedroid/utils/theme.dart';
import '../helpers/test_helpers.dart';

class MockFilePicker extends Mock
    with MockPlatformInterfaceMixin
    implements FilePicker {}

class MockUrlLauncher extends Mock
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {}

void main() {
  group('AdbSetupScreen', () {
    // AdbSetupScreen is tall — increase the test surface to avoid overflow.
    setUpAll(() {
      registerFallbackValue(FileType.any);
      registerFallbackValue(const LaunchOptions());
    });

    Future<void> pumpSetupScreen(
      WidgetTester tester, {
      VoidCallback? onRetry,
      MockAdbService? adb,
      DeviceProvider? deviceProvider,
    }) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await pumpApp(
        tester,
        AdbSetupScreen(onRetry: onRetry ?? () {}),
        adb: adb,
        deviceProvider: deviceProvider,
      );
    }

    testWidgets('renders "ADB Not Found" title', (tester) async {
      await pumpSetupScreen(tester);
      expect(find.text('ADB Not Found'), findsOneWidget);
    });

    testWidgets('shows warning icon with "!!"', (tester) async {
      await pumpSetupScreen(tester);
      expect(find.text('!!'), findsOneWidget);
    });

    testWidgets('shows 3 option cards with correct titles', (tester) async {
      await pumpSetupScreen(tester);
      expect(find.text('Homebrew (Recommended)'), findsOneWidget);
      expect(find.text('Android SDK Platform Tools'), findsOneWidget);
      expect(find.text('Browse for ADB'), findsOneWidget);
    });

    testWidgets('shows "Homebrew (Recommended)" subtitle', (tester) async {
      await pumpSetupScreen(tester);
      expect(find.text('brew install android-platform-tools'), findsOneWidget);
    });

    testWidgets('shows "Android SDK Platform Tools" card', (tester) async {
      await pumpSetupScreen(tester);
      expect(find.text('Android SDK Platform Tools'), findsOneWidget);
      expect(find.text('developer.android.com/tools'), findsOneWidget);
    });

    testWidgets('shows "Browse for ADB" card', (tester) async {
      await pumpSetupScreen(tester);
      expect(find.text('Browse for ADB'), findsOneWidget);
      expect(find.text('Locate adb binary manually'), findsOneWidget);
    });

    testWidgets('retry button is rendered', (tester) async {
      await pumpSetupScreen(tester);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('retry button calls onRetry callback when tapped',
        (tester) async {
      var retryCallCount = 0;
      await pumpSetupScreen(tester, onRetry: () => retryCallCount++);

      expect(retryCallCount, 0);

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(retryCallCount, 1);
    });

    testWidgets('shows description text about installing ADB',
        (tester) async {
      await pumpSetupScreen(tester);
      expect(
        find.text(
          'Android Debug Bridge is required to communicate\nwith your device. Install it using one of these methods:',
        ),
        findsOneWidget,
      );
    });

    testWidgets('all 3 option cards render with their descriptions',
        (tester) async {
      await pumpSetupScreen(tester);

      // Homebrew card
      expect(find.text('Homebrew (Recommended)'), findsOneWidget);
      expect(find.text('brew install android-platform-tools'), findsOneWidget);

      // SDK card
      expect(find.text('Android SDK Platform Tools'), findsOneWidget);
      expect(find.text('developer.android.com/tools'), findsOneWidget);

      // Browse card
      expect(find.text('Browse for ADB'), findsOneWidget);
      expect(find.text('Locate adb binary manually'), findsOneWidget);
    });

    testWidgets('subtitle instruction text renders', (tester) async {
      await pumpSetupScreen(tester);
      expect(
        find.text(
          'Android Debug Bridge is required to communicate\nwith your device. Install it using one of these methods:',
        ),
        findsOneWidget,
      );
    });

    testWidgets('hover on option card changes background color',
        (tester) async {
      await pumpSetupScreen(tester);

      // Find the AnimatedContainer ancestor of the Homebrew option card
      final homebrewCard = find.ancestor(
        of: find.text('Homebrew (Recommended)'),
        matching: find.byType(AnimatedContainer),
      ).first;

      // Before hover: background should be bgSurface
      final beforeWidget = tester.widget<AnimatedContainer>(homebrewCard);
      final beforeDecoration = beforeWidget.decoration as BoxDecoration;
      expect(beforeDecoration.color, equals(FileDroidTheme.bgSurface));

      // Hover over the card
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.text('Homebrew (Recommended)')));
      await tester.pump();

      // After hover: background should be bgElevated
      final afterWidget = tester.widget<AnimatedContainer>(homebrewCard);
      final afterDecoration = afterWidget.decoration as BoxDecoration;
      expect(afterDecoration.color, equals(FileDroidTheme.bgElevated));
    });

    testWidgets('hover exit on option card restores background color',
        (tester) async {
      await pumpSetupScreen(tester);

      final homebrewCard = find.ancestor(
        of: find.text('Homebrew (Recommended)'),
        matching: find.byType(AnimatedContainer),
      ).first;

      // Hover into the card
      final gesture =
          await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(
          tester.getCenter(find.text('Homebrew (Recommended)')));
      await tester.pump();

      // Verify hover state
      final hoveredWidget = tester.widget<AnimatedContainer>(homebrewCard);
      final hoveredDecoration = hoveredWidget.decoration as BoxDecoration;
      expect(hoveredDecoration.color, equals(FileDroidTheme.bgElevated));

      // Move pointer away from the card to trigger onExit
      await gesture.moveTo(const Offset(0, 0));
      await tester.pump();

      // After exit: background should revert to bgSurface
      final exitedWidget = tester.widget<AnimatedContainer>(homebrewCard);
      final exitedDecoration = exitedWidget.decoration as BoxDecoration;
      expect(exitedDecoration.color, equals(FileDroidTheme.bgSurface));
    });

    testWidgets('tapping Homebrew card does not throw', (tester) async {
      await pumpSetupScreen(tester);

      // Tap the Homebrew card — its onTap is a no-op
      await tester.tap(find.text('Homebrew (Recommended)'));
      await tester.pump();

      // Verify screen is still rendered without errors
      expect(find.text('ADB Not Found'), findsOneWidget);
    });

    testWidgets(
        'tapping SDK Platform Tools card launches URL',
        (tester) async {
      final mockUrlLauncher = MockUrlLauncher();
      UrlLauncherPlatform.instance = mockUrlLauncher;
      when(() => mockUrlLauncher.launchUrl(any(), any()))
          .thenAnswer((_) async => true);

      await pumpSetupScreen(tester);

      await tester.tap(find.text('Android SDK Platform Tools'));
      await tester.pumpAndSettle();

      verify(() => mockUrlLauncher.launchUrl(
            'https://developer.android.com/tools/releases/platform-tools',
            any(),
          )).called(1);
    });

    testWidgets(
        'tapping Browse card when user cancels file picker does nothing',
        (tester) async {
      final mockPicker = MockFilePicker();
      FilePicker.platform = mockPicker;


      when(() => mockPicker.pickFiles(
            dialogTitle: any(named: 'dialogTitle'),
            type: any(named: 'type'),
          )).thenAnswer((_) async => null);

      final mockAdb = createMockAdb();
      await pumpSetupScreen(tester, adb: mockAdb);

      await tester.tap(find.text('Browse for ADB'));
      await tester.pumpAndSettle();

      // No error should be shown, no call to setCustomAdbPath
      expect(
          find.text('Selected file is not a valid adb binary'), findsNothing);
      verifyNever(() => mockAdb.setCustomAdbPath(any()));
    });

    testWidgets(
        'tapping Browse card when setCustomAdbPath returns false shows error',
        (tester) async {
      final mockPicker = MockFilePicker();
      FilePicker.platform = mockPicker;


      when(() => mockPicker.pickFiles(
            dialogTitle: any(named: 'dialogTitle'),
            type: any(named: 'type'),
          )).thenAnswer((_) async => FilePickerResult([
            PlatformFile(
                name: 'adb', size: 100, path: '/usr/local/bin/adb'),
          ]));

      final mockAdb = createMockAdb();
      // setCustomAdbPath already returns false by default from createMockAdb()
      await pumpSetupScreen(tester, adb: mockAdb);

      await tester.tap(find.text('Browse for ADB'));
      await tester.pumpAndSettle();

      // Error should be displayed
      expect(find.text('Selected file is not a valid adb binary'),
          findsOneWidget);
      verify(() => mockAdb.setCustomAdbPath('/usr/local/bin/adb')).called(1);
    });

    testWidgets(
        'tapping Browse card when setCustomAdbPath returns true clears error',
        (tester) async {
      final mockPicker = MockFilePicker();
      FilePicker.platform = mockPicker;

      final mockAdb = createMockAdb();
      // Make isAdbAvailable return false so retryInitialize() doesn't start
      // the periodic polling timer (which would cause a pending timer error).
      when(() => mockAdb.isAdbAvailable()).thenAnswer((_) async => false);

      // First call returns false to set the error
      when(() => mockPicker.pickFiles(
            dialogTitle: any(named: 'dialogTitle'),
            type: any(named: 'type'),
          )).thenAnswer((_) async => FilePickerResult([
            PlatformFile(
                name: 'adb', size: 100, path: '/usr/local/bin/adb'),
          ]));
      when(() => mockAdb.setCustomAdbPath(any()))
          .thenAnswer((_) async => false);

      await pumpSetupScreen(tester, adb: mockAdb);

      // Tap Browse — setCustomAdbPath returns false, error appears
      await tester.tap(find.text('Browse for ADB'));
      await tester.pumpAndSettle();
      expect(find.text('Selected file is not a valid adb binary'),
          findsOneWidget);

      // Now make setCustomAdbPath return true
      when(() => mockAdb.setCustomAdbPath(any()))
          .thenAnswer((_) async => true);

      // Tap Browse again — setCustomAdbPath returns true, error clears
      await tester.tap(find.text('Browse for ADB'));
      await tester.pumpAndSettle();
      expect(
          find.text('Selected file is not a valid adb binary'), findsNothing);
    });
  });
}
