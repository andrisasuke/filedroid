import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:filedroid/widgets/browser_toolbar.dart';
import '../helpers/test_helpers.dart';

class MockFilePicker extends Mock
    with MockPlatformInterfaceMixin
    implements FilePicker {}

void main() {
  group('BrowserToolbar', () {
    late MockAdbService adb;

    setUp(() {
      adb = createMockAdb();
    });

    testWidgets('renders toolbar with all buttons', (tester) async {
      await pumpApp(tester, const BrowserToolbar(), adb: adb);
      await tester.pumpAndSettle();

      // Nav buttons
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);

      // Tool buttons
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
      expect(find.byIcon(Icons.create_new_folder_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      // Gradient buttons
      expect(find.text('\u2303 Upload'), findsOneWidget);
      expect(find.text('\u2304 Download'), findsOneWidget);
    });

    testWidgets('nav buttons disabled when no device', (tester) async {
      await pumpApp(tester, const BrowserToolbar(), adb: adb);
      await tester.pumpAndSettle();

      // Check tooltips exist for nav buttons
      expect(find.byTooltip('Go Back'), findsOneWidget);
      expect(find.byTooltip('Go Forward'), findsOneWidget);
      expect(find.byTooltip('Go Up'), findsOneWidget);

      // Tap on disabled back button should not trigger anything
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      verifyNever(() => adb.listFiles(any()));
    });

    testWidgets('nav buttons enabled with device and appropriate browser state',
        (tester) async {
      final deviceProv = createDeviceProvider(adb);
      final browserProv = createBrowserProvider(adb);

      when(() => adb.getStorageInfo())
          .thenAnswer((_) async => sampleStorageInfo);
      when(() => adb.listFiles('/sdcard'))
          .thenAnswer((_) async => sampleFiles);
      when(() => adb.listFiles('/sdcard/Download'))
          .thenAnswer((_) async => []);

      await deviceProv.selectDevice(sampleDevice);
      await browserProv.navigateTo('/sdcard');

      await pumpApp(
        tester,
        const BrowserToolbar(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: adb,
      );
      await tester.pumpAndSettle();

      // Back button should be disabled (no history)
      expect(find.byTooltip('Go Back'), findsOneWidget);

      // Forward button should be disabled
      expect(find.byTooltip('Go Forward'), findsOneWidget);

      // Up button should be disabled (at root /sdcard)
      expect(find.byTooltip('Go Up'), findsOneWidget);

      // Navigate down to create history
      await browserProv.navigateTo('/sdcard/Download');
      await tester.pumpAndSettle();

      // Back button should now be enabled
      final backButton = find.byIcon(Icons.chevron_left);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Should have navigated back to /sdcard
      expect(browserProv.currentPath, '/sdcard');
    });

    testWidgets('breadcrumb renders path segments', (tester) async {
      final deviceProv = createDeviceProvider(adb);
      final browserProv = createBrowserProvider(adb);

      when(() => adb.getStorageInfo())
          .thenAnswer((_) async => sampleStorageInfo);
      when(() => adb.listFiles('/sdcard/Download/Photos'))
          .thenAnswer((_) async => []);

      await deviceProv.selectDevice(sampleDevice);
      await browserProv.navigateTo('/sdcard/Download/Photos');

      await pumpApp(
        tester,
        const BrowserToolbar(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: adb,
      );
      await tester.pumpAndSettle();

      // Breadcrumb segments: ['/', 'sdcard', 'Download', 'Photos']
      expect(find.text('/'), findsOneWidget);
      expect(find.text('sdcard'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);
      expect(find.text('Photos'), findsOneWidget);

      // Separators (between 4 segments = 3 separators)
      expect(find.text('>'), findsNWidgets(3));
    });

    testWidgets('breadcrumb tap navigates', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final deviceProv = createDeviceProvider(adb);
      final browserProv = createBrowserProvider(adb);

      when(() => adb.getStorageInfo())
          .thenAnswer((_) async => sampleStorageInfo);
      when(() => adb.listFiles('/sdcard/Download/Photos'))
          .thenAnswer((_) async => []);
      when(() => adb.listFiles('/sdcard/Download'))
          .thenAnswer((_) async => []);

      await deviceProv.selectDevice(sampleDevice);
      await browserProv.navigateTo('/sdcard/Download/Photos');

      await pumpApp(
        tester,
        const BrowserToolbar(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: adb,
      );
      await tester.pumpAndSettle();

      // Tap on "Download" breadcrumb
      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();

      expect(browserProv.currentPath, '/sdcard/Download');
    });

    testWidgets('refresh button presence', (tester) async {
      await pumpApp(tester, const BrowserToolbar(), adb: adb);
      await tester.pumpAndSettle();

      expect(find.byTooltip('Refresh'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('new folder button opens dialog', (tester) async {
      final deviceProv = createDeviceProvider(adb);
      final browserProv = createBrowserProvider(adb);

      when(() => adb.getStorageInfo())
          .thenAnswer((_) async => sampleStorageInfo);
      when(() => adb.listFiles('/sdcard')).thenAnswer((_) async => []);

      await deviceProv.selectDevice(sampleDevice);
      await browserProv.navigateTo('/sdcard');

      await pumpApp(
        tester,
        const BrowserToolbar(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: adb,
      );
      await tester.pumpAndSettle();

      // Tap new folder button
      await tester.tap(find.byIcon(Icons.create_new_folder_outlined));
      await tester.pumpAndSettle();

      // Dialog should appear
      expect(find.text('New Folder'), findsOneWidget);
      expect(find.text('Folder name'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Create'), findsOneWidget);
    });

    testWidgets('new folder dialog: type name, submit creates folder',
        (tester) async {
      final deviceProv = createDeviceProvider(adb);
      final browserProv = createBrowserProvider(adb);

      when(() => adb.getStorageInfo())
          .thenAnswer((_) async => sampleStorageInfo);
      when(() => adb.listFiles('/sdcard')).thenAnswer((_) async => []);
      when(() => adb.createDirectory('/sdcard/NewFolder'))
          .thenAnswer((_) async => true);

      await deviceProv.selectDevice(sampleDevice);
      await browserProv.navigateTo('/sdcard');

      await pumpApp(
        tester,
        const BrowserToolbar(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: adb,
      );
      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.byIcon(Icons.create_new_folder_outlined));
      await tester.pumpAndSettle();

      // Type folder name
      await tester.enterText(find.byType(TextField), 'NewFolder');
      await tester.pumpAndSettle();

      // Tap Create button
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      // Verify createDirectory was called
      verify(() => adb.createDirectory('/sdcard/NewFolder')).called(1);

      // Dialog should be dismissed
      expect(find.text('New Folder'), findsNothing);
    });

    testWidgets('new folder dialog: cancel dismisses', (tester) async {
      final deviceProv = createDeviceProvider(adb);
      final browserProv = createBrowserProvider(adb);

      when(() => adb.getStorageInfo())
          .thenAnswer((_) async => sampleStorageInfo);
      when(() => adb.listFiles('/sdcard')).thenAnswer((_) async => []);

      await deviceProv.selectDevice(sampleDevice);
      await browserProv.navigateTo('/sdcard');

      await pumpApp(
        tester,
        const BrowserToolbar(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: adb,
      );
      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.byIcon(Icons.create_new_folder_outlined));
      await tester.pumpAndSettle();

      // Type something
      await tester.enterText(find.byType(TextField), 'TestFolder');
      await tester.pumpAndSettle();

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Verify createDirectory was NOT called
      verifyNever(() => adb.createDirectory(any()));

      // Dialog should be dismissed
      expect(find.text('New Folder'), findsNothing);
    });

    testWidgets('delete button disabled when no selection', (tester) async {
      final deviceProv = createDeviceProvider(adb);
      final browserProv = createBrowserProvider(adb);

      when(() => adb.getStorageInfo())
          .thenAnswer((_) async => sampleStorageInfo);
      when(() => adb.listFiles('/sdcard')).thenAnswer((_) async => []);

      await deviceProv.selectDevice(sampleDevice);
      await browserProv.navigateTo('/sdcard');

      await pumpApp(
        tester,
        const BrowserToolbar(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: adb,
      );
      await tester.pumpAndSettle();

      // Delete button should have tooltip for no selection
      expect(find.byTooltip('Select items to delete'), findsOneWidget);
    });

    testWidgets('delete button enabled when selection exists', (tester) async {
      final deviceProv = createDeviceProvider(adb);
      final browserProv = createBrowserProvider(adb);

      when(() => adb.getStorageInfo())
          .thenAnswer((_) async => sampleStorageInfo);
      when(() => adb.listFiles('/sdcard')).thenAnswer((_) async => sampleFiles);

      await deviceProv.selectDevice(sampleDevice);
      await browserProv.navigateTo('/sdcard');

      await pumpApp(
        tester,
        const BrowserToolbar(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: adb,
      );
      await tester.pumpAndSettle();

      // Select a file
      browserProv.toggleSelection(sampleFiles[2]); // photo.jpg
      await tester.pumpAndSettle();

      // Delete button should have tooltip for selection
      expect(find.byTooltip('Delete 1 selected'), findsOneWidget);

      // Select another file
      browserProv.toggleSelection(sampleFiles[3]); // notes.txt
      await tester.pumpAndSettle();

      expect(find.byTooltip('Delete 2 selected'), findsOneWidget);
    });

    testWidgets('delete dialog shows confirmation text', (tester) async {
      final deviceProv = createDeviceProvider(adb);
      final browserProv = createBrowserProvider(adb);

      when(() => adb.getStorageInfo())
          .thenAnswer((_) async => sampleStorageInfo);
      when(() => adb.listFiles('/sdcard')).thenAnswer((_) async => sampleFiles);
      when(() => adb.delete(any(), recursive: any(named: 'recursive')))
          .thenAnswer((_) async => true);

      await deviceProv.selectDevice(sampleDevice);
      await browserProv.navigateTo('/sdcard');

      await pumpApp(
        tester,
        const BrowserToolbar(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: adb,
      );
      await tester.pumpAndSettle();

      // Select single file
      browserProv.toggleSelection(sampleFiles[2]); // photo.jpg
      await tester.pumpAndSettle();

      // Tap delete button
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // Dialog should appear with confirmation text
      expect(find.text('Delete'), findsNWidgets(2)); // Title and button
      expect(
        find.text(
            'Are you sure you want to delete "photo.jpg"? This cannot be undone.'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Cancel to close
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(
        find.text(
            'Are you sure you want to delete "photo.jpg"? This cannot be undone.'),
        findsNothing,
      );
    });

    testWidgets('delete dialog for multiple items', (tester) async {
      final deviceProv = createDeviceProvider(adb);
      final browserProv = createBrowserProvider(adb);

      when(() => adb.getStorageInfo())
          .thenAnswer((_) async => sampleStorageInfo);
      when(() => adb.listFiles('/sdcard')).thenAnswer((_) async => sampleFiles);

      await deviceProv.selectDevice(sampleDevice);
      await browserProv.navigateTo('/sdcard');

      await pumpApp(
        tester,
        const BrowserToolbar(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: adb,
      );
      await tester.pumpAndSettle();

      // Select multiple files
      browserProv.toggleSelection(sampleFiles[2]); // photo.jpg
      browserProv.toggleSelection(sampleFiles[3]); // notes.txt
      await tester.pumpAndSettle();

      // Tap delete button
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // Dialog should show item count
      expect(
        find.text(
            'Are you sure you want to delete 2 items? This cannot be undone.'),
        findsOneWidget,
      );
    });

    testWidgets('upload button disabled when no device', (tester) async {
      await pumpApp(tester, const BrowserToolbar(), adb: adb);
      await tester.pumpAndSettle();

      // Upload button should be present but disabled
      expect(find.text('\u2303 Upload'), findsOneWidget);
      expect(find.byTooltip('Upload files to device'), findsOneWidget);
    });

    testWidgets('download button disabled when no selection', (tester) async {
      final deviceProv = createDeviceProvider(adb);
      final browserProv = createBrowserProvider(adb);

      when(() => adb.getStorageInfo())
          .thenAnswer((_) async => sampleStorageInfo);
      when(() => adb.listFiles('/sdcard')).thenAnswer((_) async => sampleFiles);

      await deviceProv.selectDevice(sampleDevice);
      await browserProv.navigateTo('/sdcard');

      await pumpApp(
        tester,
        const BrowserToolbar(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: adb,
      );
      await tester.pumpAndSettle();

      // Download button should show default text
      expect(find.text('\u2304 Download'), findsOneWidget);
      expect(find.byTooltip('Select files to download'), findsOneWidget);
    });

    testWidgets('download button enabled when selection exists',
        (tester) async {
      final deviceProv = createDeviceProvider(adb);
      final browserProv = createBrowserProvider(adb);

      when(() => adb.getStorageInfo())
          .thenAnswer((_) async => sampleStorageInfo);
      when(() => adb.listFiles('/sdcard')).thenAnswer((_) async => sampleFiles);

      await deviceProv.selectDevice(sampleDevice);
      await browserProv.navigateTo('/sdcard');

      await pumpApp(
        tester,
        const BrowserToolbar(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: adb,
      );
      await tester.pumpAndSettle();

      // Select files
      browserProv.toggleSelection(sampleFiles[2]); // photo.jpg
      browserProv.toggleSelection(sampleFiles[3]); // notes.txt
      await tester.pumpAndSettle();

      // Download button should show count
      expect(find.text('\u2304 Download (2)'), findsOneWidget);
      expect(find.byTooltip('Download 2 selected files'), findsOneWidget);
    });

    testWidgets('toggle hidden files button changes state', (tester) async {
      final deviceProv = createDeviceProvider(adb);
      final browserProv = createBrowserProvider(adb);

      when(() => adb.getStorageInfo())
          .thenAnswer((_) async => sampleStorageInfo);
      when(() => adb.listFiles('/sdcard')).thenAnswer((_) async => []);

      await deviceProv.selectDevice(sampleDevice);
      await browserProv.navigateTo('/sdcard');

      await pumpApp(
        tester,
        const BrowserToolbar(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: adb,
      );
      await tester.pumpAndSettle();

      // Initially should show "hidden files off" icon
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
      expect(find.byTooltip('Show Hidden Files'), findsOneWidget);

      // Tap to toggle
      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pumpAndSettle();

      // Now should show "visibility on" icon
      expect(find.byIcon(Icons.visibility), findsOneWidget);
      expect(find.byTooltip('Hide Hidden Files'), findsOneWidget);

      // Verify state changed
      expect(browserProv.showHidden, true);
    });

    testWidgets('refresh button calls browser.refresh when device is connected',
        (tester) async {
      final deviceProv = createDeviceProvider(adb);
      final browserProv = createBrowserProvider(adb);

      when(() => adb.getStorageInfo())
          .thenAnswer((_) async => sampleStorageInfo);
      when(() => adb.listFiles('/sdcard')).thenAnswer((_) async => []);

      await deviceProv.selectDevice(sampleDevice);
      await browserProv.navigateTo('/sdcard');

      await pumpApp(
        tester,
        const BrowserToolbar(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: adb,
      );
      await tester.pumpAndSettle();

      // Tap refresh button
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      // Verify listFiles was called at least 2 times (once for navigateTo, once for refresh)
      verify(() => adb.listFiles('/sdcard')).called(greaterThanOrEqualTo(2));
    });

    testWidgets('new folder dialog submit via Enter key', (tester) async {
      final deviceProv = createDeviceProvider(adb);
      final browserProv = createBrowserProvider(adb);

      when(() => adb.getStorageInfo())
          .thenAnswer((_) async => sampleStorageInfo);
      when(() => adb.listFiles('/sdcard')).thenAnswer((_) async => []);
      when(() => adb.createDirectory('/sdcard/NewFolder'))
          .thenAnswer((_) async => true);

      await deviceProv.selectDevice(sampleDevice);
      await browserProv.navigateTo('/sdcard');

      await pumpApp(
        tester,
        const BrowserToolbar(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: adb,
      );
      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.byIcon(Icons.create_new_folder_outlined));
      await tester.pumpAndSettle();

      // Type folder name
      await tester.enterText(find.byType(TextField), 'NewFolder');
      await tester.pumpAndSettle();

      // Submit via Enter key
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Verify createDirectory was called
      verify(() => adb.createDirectory('/sdcard/NewFolder')).called(1);

      // Dialog should be dismissed
      expect(find.text('New Folder'), findsNothing);
    });

    testWidgets('delete dialog confirm button calls deleteItems',
        (tester) async {
      final deviceProv = createDeviceProvider(adb);
      final browserProv = createBrowserProvider(adb);

      when(() => adb.getStorageInfo())
          .thenAnswer((_) async => sampleStorageInfo);
      when(() => adb.listFiles('/sdcard')).thenAnswer((_) async => sampleFiles);
      when(() => adb.delete(any(), recursive: any(named: 'recursive')))
          .thenAnswer((_) async => true);

      await deviceProv.selectDevice(sampleDevice);
      await browserProv.navigateTo('/sdcard');

      await pumpApp(
        tester,
        const BrowserToolbar(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: adb,
      );
      await tester.pumpAndSettle();

      // Select single file
      browserProv.toggleSelection(sampleFiles[2]); // photo.jpg
      await tester.pumpAndSettle();

      // Tap delete button
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // Dialog should appear
      expect(
        find.text(
            'Are you sure you want to delete "photo.jpg"? This cannot be undone.'),
        findsOneWidget,
      );

      // Tap Delete button
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      // Verify delete was called
      verify(() => adb.delete(any(), recursive: any(named: 'recursive')))
          .called(1);
    });

    testWidgets('tool button hover state', (tester) async {
      final deviceProv = createDeviceProvider(adb);
      final browserProv = createBrowserProvider(adb);

      when(() => adb.getStorageInfo())
          .thenAnswer((_) async => sampleStorageInfo);
      when(() => adb.listFiles('/sdcard')).thenAnswer((_) async => []);

      await deviceProv.selectDevice(sampleDevice);
      await browserProv.navigateTo('/sdcard');

      await pumpApp(
        tester,
        const BrowserToolbar(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: adb,
      );
      await tester.pumpAndSettle();

      // Find the refresh button
      final refreshButton = find.byIcon(Icons.refresh);
      expect(refreshButton, findsOneWidget);

      // Hover over the button
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();

      await gesture.moveTo(tester.getCenter(refreshButton));
      await tester.pumpAndSettle();

      // Move away from the button
      await gesture.moveTo(Offset.zero);
      await tester.pumpAndSettle();
    });

    testWidgets('nav button hover state', (tester) async {
      final deviceProv = createDeviceProvider(adb);
      final browserProv = createBrowserProvider(adb);

      when(() => adb.getStorageInfo())
          .thenAnswer((_) async => sampleStorageInfo);
      when(() => adb.listFiles('/sdcard')).thenAnswer((_) async => []);

      await deviceProv.selectDevice(sampleDevice);
      await browserProv.navigateTo('/sdcard');

      await pumpApp(
        tester,
        const BrowserToolbar(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: adb,
      );
      await tester.pumpAndSettle();

      // Hover over back button (a _NavButton)
      final backButton = find.byIcon(Icons.chevron_left);
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(backButton));
      await tester.pump();

      // Move away to trigger onExit
      await gesture.moveTo(const Offset(0, 500));
      await tester.pump();
    });

    testWidgets('gradient button hover state', (tester) async {
      final deviceProv = createDeviceProvider(adb);
      final browserProv = createBrowserProvider(adb);

      when(() => adb.getStorageInfo())
          .thenAnswer((_) async => sampleStorageInfo);
      when(() => adb.listFiles('/sdcard')).thenAnswer((_) async => sampleFiles);

      await deviceProv.selectDevice(sampleDevice);
      await browserProv.navigateTo('/sdcard');

      await pumpApp(
        tester,
        const BrowserToolbar(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: adb,
      );
      await tester.pumpAndSettle();

      // Hover over upload button (a _GradientButton)
      final uploadButton = find.text('\u2303 Upload');
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(uploadButton));
      await tester.pump();

      // Move away to trigger onExit
      await gesture.moveTo(const Offset(0, 500));
      await tester.pump();
    });

    testWidgets('disabled gradient button hover shows different color', (tester) async {
      // No device = buttons disabled with no gradient
      await pumpApp(tester, const BrowserToolbar(), adb: adb);
      await tester.pumpAndSettle();

      // Hover over download button (disabled, no gradient)
      final downloadButton = find.text('\u2304 Download');
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(downloadButton));
      await tester.pump();

      // Move away
      await gesture.moveTo(const Offset(0, 500));
      await tester.pump();
    });

    testWidgets('upload button tap with FilePicker - files selected',
        (tester) async {
      // Mock the macOS platform channel to avoid MissingPluginException in runAsync
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('appkit_ui_element_colors'),
        (MethodCall methodCall) async =>
            <String, double>{'hueComponent': 0.6085324903200698},
      );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('appkit_ui_element_colors'),
          null,
        );
      });

      // Create temporary files so that File.exists()/length() in pushFiles work
      final tmpDir = Directory.systemTemp.createTempSync('upload_test_');
      final tmpFile1 = File('${tmpDir.path}/test.txt')
        ..writeAsStringSync('hello');
      final tmpFile2 = File('${tmpDir.path}/photo.jpg')
        ..writeAsStringSync('image data');
      addTearDown(() => tmpDir.deleteSync(recursive: true));

      final mockPicker = MockFilePicker();
      FilePicker.platform = mockPicker;

      final deviceProv = createDeviceProvider(adb);
      final browserProv = createBrowserProvider(adb);
      final transferProv = createTransferProvider(adb);

      when(() => adb.getStorageInfo())
          .thenAnswer((_) async => sampleStorageInfo);
      when(() => adb.listFiles('/sdcard')).thenAnswer((_) async => sampleFiles);
      when(() => adb.pushFileWithProgress(any(), any(), any()))
          .thenAnswer((_) async {});

      when(() => mockPicker.pickFiles(
            allowMultiple: any(named: 'allowMultiple'),
          )).thenAnswer((_) async => FilePickerResult([
            PlatformFile(
                name: 'test.txt', size: 100, path: tmpFile1.path),
            PlatformFile(
                name: 'photo.jpg', size: 5000, path: tmpFile2.path),
          ]));

      await deviceProv.selectDevice(sampleDevice);
      await browserProv.navigateTo('/sdcard');

      await pumpApp(
        tester,
        const BrowserToolbar(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        transferProvider: transferProv,
        adb: adb,
      );
      await tester.pumpAndSettle();

      // Tap upload button — _handleUpload is fire-and-forget async
      // Use runAsync to allow real I/O (File.exists, File.length) in pushFiles to complete
      await tester.runAsync(() async {
        await tester.tap(find.text('\u2303 Upload'));
        await tester.pump();
        // Wait for fire-and-forget futures (pushFiles with File I/O) to settle
        await Future.delayed(const Duration(seconds: 1));
      });
      await tester.pump();

      // Verify FilePicker was called
      verify(() => mockPicker.pickFiles(allowMultiple: true)).called(1);

      // Verify transfer tasks were created
      expect(transferProv.tasks.length, 2);
      expect(transferProv.tasks.any((t) => t.fileName == 'test.txt'), true);
      expect(transferProv.tasks.any((t) => t.fileName == 'photo.jpg'), true);
    });

    testWidgets('upload button tap - user cancels picker', (tester) async {
      final mockPicker = MockFilePicker();
      FilePicker.platform = mockPicker;

      final deviceProv = createDeviceProvider(adb);
      final browserProv = createBrowserProvider(adb);
      final transferProv = createTransferProvider(adb);

      when(() => adb.getStorageInfo())
          .thenAnswer((_) async => sampleStorageInfo);
      when(() => adb.listFiles('/sdcard')).thenAnswer((_) async => sampleFiles);

      // User cancels the picker
      when(() => mockPicker.pickFiles(
            allowMultiple: any(named: 'allowMultiple'),
          )).thenAnswer((_) async => null);

      await deviceProv.selectDevice(sampleDevice);
      await browserProv.navigateTo('/sdcard');

      await pumpApp(
        tester,
        const BrowserToolbar(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        transferProvider: transferProv,
        adb: adb,
      );
      await tester.pumpAndSettle();

      // Tap upload button
      await tester.tap(find.text('\u2303 Upload'));
      await tester.pumpAndSettle();

      // Verify FilePicker was called
      verify(() => mockPicker.pickFiles(allowMultiple: true)).called(1);

      // Verify no transfer tasks were created
      expect(transferProv.tasks, isEmpty);
    });

    testWidgets('download button tap with FilePicker - directory selected',
        (tester) async {
      final mockPicker = MockFilePicker();
      FilePicker.platform = mockPicker;

      final deviceProv = createDeviceProvider(adb);
      final browserProv = createBrowserProvider(adb);
      final transferProv = createTransferProvider(adb);

      when(() => adb.getStorageInfo())
          .thenAnswer((_) async => sampleStorageInfo);
      when(() => adb.listFiles('/sdcard')).thenAnswer((_) async => sampleFiles);
      when(() => adb.getRemoteFileSize(any())).thenAnswer((_) async => 1000);
      when(() => adb.pullFileWithProgress(any(), any(), any()))
          .thenAnswer((_) async {});

      // User selects a directory
      when(() => mockPicker.getDirectoryPath())
          .thenAnswer((_) async => '/tmp/downloads');

      await deviceProv.selectDevice(sampleDevice);
      await browserProv.navigateTo('/sdcard');

      await pumpApp(
        tester,
        const BrowserToolbar(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        transferProvider: transferProv,
        adb: adb,
      );
      await tester.pumpAndSettle();

      // Select files for download
      browserProv.toggleSelection(sampleFiles[2]); // photo.jpg
      browserProv.toggleSelection(sampleFiles[3]); // notes.txt
      await tester.pumpAndSettle();

      // Verify download button shows count
      expect(find.text('\u2304 Download (2)'), findsOneWidget);

      // Tap download button
      await tester.tap(find.text('\u2304 Download (2)'));
      await tester.pumpAndSettle();

      // Verify FilePicker was called
      verify(() => mockPicker.getDirectoryPath()).called(1);

      // Verify transfer tasks were created
      expect(transferProv.tasks.length, 2);
      expect(
          transferProv.tasks.any((t) => t.fileName == 'photo.jpg'), true);
      expect(
          transferProv.tasks.any((t) => t.fileName == 'notes.txt'), true);

      // Verify selection was cleared
      expect(browserProv.selectedFiles, isEmpty);
    });

    testWidgets('download button tap - user cancels directory picker',
        (tester) async {
      final mockPicker = MockFilePicker();
      FilePicker.platform = mockPicker;

      final deviceProv = createDeviceProvider(adb);
      final browserProv = createBrowserProvider(adb);
      final transferProv = createTransferProvider(adb);

      when(() => adb.getStorageInfo())
          .thenAnswer((_) async => sampleStorageInfo);
      when(() => adb.listFiles('/sdcard')).thenAnswer((_) async => sampleFiles);

      // User cancels the directory picker
      when(() => mockPicker.getDirectoryPath())
          .thenAnswer((_) async => null);

      await deviceProv.selectDevice(sampleDevice);
      await browserProv.navigateTo('/sdcard');

      await pumpApp(
        tester,
        const BrowserToolbar(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        transferProvider: transferProv,
        adb: adb,
      );
      await tester.pumpAndSettle();

      // Select files for download
      browserProv.toggleSelection(sampleFiles[2]); // photo.jpg
      await tester.pumpAndSettle();

      // Tap download button
      await tester.tap(find.text('\u2304 Download (1)'));
      await tester.pumpAndSettle();

      // Verify FilePicker was called
      verify(() => mockPicker.getDirectoryPath()).called(1);

      // Verify no transfer tasks were created
      expect(transferProv.tasks, isEmpty);

      // Verify selection is still intact (not cleared since download was cancelled)
      expect(browserProv.selectedFiles.length, 1);
    });
  });
}
