import 'dart:async';
import 'package:filedroid/models/android_file.dart';
import 'package:filedroid/providers/file_browser_provider.dart';
import 'package:filedroid/services/adb_service.dart';
import 'package:filedroid/widgets/file_browser.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../helpers/test_helpers.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(const AndroidFile(
      name: 'test',
      path: '/sdcard/test',
      isDirectory: false,
    ));
  });

  group('FileBrowser Widget Tests', () {
    testWidgets('shows "Connect Your Android Device" when no device connected',
        (tester) async {
      final mockAdb = createMockAdb();
      final deviceProv = createDeviceProvider(mockAdb);
      final browserProv = createBrowserProvider(mockAdb);

      await pumpApp(
        tester,
        const FileBrowser(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: mockAdb,
      );

      expect(find.text('Connect Your Android Device'), findsOneWidget);
      expect(find.text('1. Enable USB Debugging on your phone'), findsOneWidget);
      expect(find.text('2. Connect via USB cable'), findsOneWidget);
      expect(find.text('3. Accept the connection prompt'), findsOneWidget);
    });

    testWidgets('shows "Authorization Required" for unauthorized device',
        (tester) async {
      final mockAdb = createMockAdb();
      final deviceProv = createDeviceProvider(mockAdb);
      final browserProv = createBrowserProvider(mockAdb);

      await deviceProv.selectDevice(unauthorizedDevice);

      await pumpApp(
        tester,
        const FileBrowser(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: mockAdb,
      );

      expect(find.text('Authorization Required'), findsOneWidget);
      expect(
        find.textContaining('Your device needs to authorize this computer'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Check your phone for the USB debugging prompt'),
        findsOneWidget,
      );
    });

    testWidgets('shows CircularProgressIndicator when loading',
        (tester) async {
      final mockAdb = createMockAdb();
      final deviceProv = createDeviceProvider(mockAdb);
      final browserProv = createBrowserProvider(mockAdb);

      await deviceProv.selectDevice(sampleDevice);

      // Use a Completer so we can complete it in tearDown
      final completer = Completer<List<AndroidFile>>();
      when(() => mockAdb.listFiles(any()))
          .thenAnswer((_) => completer.future);

      await pumpApp(
        tester,
        const FileBrowser(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: mockAdb,
      );

      // Trigger navigation to start loading (don't await)
      browserProv.navigateTo('/sdcard');
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the future to avoid pending timer warnings
      completer.complete([]);
      await tester.pumpAndSettle();
    });

    testWidgets('shows error message when listFiles fails', (tester) async {
      final mockAdb = createMockAdb();
      final deviceProv = createDeviceProvider(mockAdb);
      final browserProv = createBrowserProvider(mockAdb);

      await deviceProv.selectDevice(sampleDevice);

      when(() => mockAdb.listFiles(any())).thenThrow(
        const AdbException('Failed to list files'),
      );

      await pumpApp(
        tester,
        const FileBrowser(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: mockAdb,
      );

      await browserProv.navigateTo('/sdcard');
      await tester.pumpAndSettle();

      // AdbException.toString() returns "AdbException: ..."
      expect(find.textContaining('Failed to list files'), findsOneWidget);
    });

    testWidgets('shows "This folder is empty" for empty directory',
        (tester) async {
      final mockAdb = createMockAdb();
      final deviceProv = createDeviceProvider(mockAdb);
      final browserProv = createBrowserProvider(mockAdb);

      await deviceProv.selectDevice(sampleDevice);
      when(() => mockAdb.listFiles(any())).thenAnswer((_) async => []);

      await pumpApp(
        tester,
        const FileBrowser(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: mockAdb,
      );

      await browserProv.navigateTo('/sdcard/empty');
      await tester.pumpAndSettle();

      expect(find.text('This folder is empty'), findsOneWidget);
      expect(find.text('Drag files here to upload'), findsOneWidget);
    });

    testWidgets('renders file list with file names', (tester) async {
      final mockAdb = createMockAdb();
      final deviceProv = createDeviceProvider(mockAdb);
      final browserProv = createBrowserProvider(mockAdb);

      await deviceProv.selectDevice(sampleDevice);
      when(() => mockAdb.listFiles(any()))
          .thenAnswer((_) async => sampleFiles);

      await pumpApp(
        tester,
        const FileBrowser(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: mockAdb,
      );

      await browserProv.navigateTo('/sdcard');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // File names in _FileRow use Text.rich with TextSpan; directories
      // append " >" so need textContaining for directory names
      expect(find.textContaining('Download'), findsOneWidget);
      expect(find.textContaining('DCIM'), findsOneWidget);
      expect(find.textContaining('photo.jpg'), findsOneWidget);
      expect(find.textContaining('notes.txt'), findsOneWidget);
    });

    testWidgets('shows sort headers: Name, Size, Modified', (tester) async {
      final mockAdb = createMockAdb();
      final deviceProv = createDeviceProvider(mockAdb);
      final browserProv = createBrowserProvider(mockAdb);

      await deviceProv.selectDevice(sampleDevice);
      when(() => mockAdb.listFiles(any()))
          .thenAnswer((_) async => sampleFiles);

      await pumpApp(
        tester,
        const FileBrowser(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: mockAdb,
      );

      await browserProv.navigateTo('/sdcard');
      await tester.pumpAndSettle();

      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Size'), findsOneWidget);
      expect(find.text('Modified'), findsOneWidget);
    });

    testWidgets('tapping sort header changes sort mode', (tester) async {
      final mockAdb = createMockAdb();
      final deviceProv = createDeviceProvider(mockAdb);
      final browserProv = createBrowserProvider(mockAdb);

      await deviceProv.selectDevice(sampleDevice);
      when(() => mockAdb.listFiles(any()))
          .thenAnswer((_) async => sampleFiles);

      await pumpApp(
        tester,
        const FileBrowser(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: mockAdb,
      );

      await browserProv.navigateTo('/sdcard');
      await tester.pumpAndSettle();

      expect(browserProv.sortMode, SortMode.name);
      expect(browserProv.sortAscending, true);

      await tester.tap(find.text('Size'));
      await tester.pumpAndSettle();

      expect(browserProv.sortMode, SortMode.size);
      expect(browserProv.sortAscending, true);

      await tester.tap(find.text('Size'));
      await tester.pumpAndSettle();

      expect(browserProv.sortMode, SortMode.size);
      expect(browserProv.sortAscending, false);

      await tester.tap(find.text('Modified'));
      await tester.pumpAndSettle();

      expect(browserProv.sortMode, SortMode.date);
      expect(browserProv.sortAscending, true);
    });

    testWidgets('status bar shows item count', (tester) async {
      final mockAdb = createMockAdb();
      final deviceProv = createDeviceProvider(mockAdb);
      final browserProv = createBrowserProvider(mockAdb);

      await deviceProv.selectDevice(sampleDevice);
      when(() => mockAdb.listFiles(any()))
          .thenAnswer((_) async => sampleFiles);

      await pumpApp(
        tester,
        const FileBrowser(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: mockAdb,
      );

      await browserProv.navigateTo('/sdcard');
      await tester.pumpAndSettle();

      expect(find.text('4 items'), findsOneWidget);
    });

    testWidgets('tapping directory navigates to it', (tester) async {
      final mockAdb = createMockAdb();
      final deviceProv = createDeviceProvider(mockAdb);
      final browserProv = createBrowserProvider(mockAdb);

      await deviceProv.selectDevice(sampleDevice);

      // Use any() for all listFiles calls
      when(() => mockAdb.listFiles(any()))
          .thenAnswer((_) async => sampleFiles);

      await pumpApp(
        tester,
        const FileBrowser(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: mockAdb,
      );

      await browserProv.navigateTo('/sdcard');
      await tester.pumpAndSettle();

      // Mock for the next navigation
      when(() => mockAdb.listFiles(any()))
          .thenAnswer((_) async => []);

      // Directory names use Text.rich with " >" appended
      await tester.tap(find.textContaining('Download'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(browserProv.currentPath, '/sdcard/Download');
    });

    testWidgets('tapping file toggles selection', (tester) async {
      final mockAdb = createMockAdb();
      final deviceProv = createDeviceProvider(mockAdb);
      final browserProv = createBrowserProvider(mockAdb);

      await deviceProv.selectDevice(sampleDevice);
      when(() => mockAdb.listFiles(any()))
          .thenAnswer((_) async => sampleFiles);

      await pumpApp(
        tester,
        const FileBrowser(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: mockAdb,
      );

      await browserProv.navigateTo('/sdcard');
      await tester.pumpAndSettle();

      expect(browserProv.hasSelection, false);

      await tester.tap(find.text('photo.jpg'));
      await tester.pumpAndSettle();

      expect(browserProv.hasSelection, true);
      expect(browserProv.selectionCount, 1);
      expect(browserProv.selectedPaths.contains('/sdcard/photo.jpg'), true);

      await tester.tap(find.text('photo.jpg'));
      await tester.pumpAndSettle();

      expect(browserProv.hasSelection, false);
      expect(browserProv.selectionCount, 0);
    });

    testWidgets('status bar shows selection badge when items selected',
        (tester) async {
      final mockAdb = createMockAdb();
      final deviceProv = createDeviceProvider(mockAdb);
      final browserProv = createBrowserProvider(mockAdb);

      await deviceProv.selectDevice(sampleDevice);
      when(() => mockAdb.listFiles(any()))
          .thenAnswer((_) async => sampleFiles);

      await pumpApp(
        tester,
        const FileBrowser(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: mockAdb,
      );

      await browserProv.navigateTo('/sdcard');
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsNothing);

      await tester.tap(find.text('photo.jpg'));
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(find.text('notes.txt'));
      await tester.pumpAndSettle();

      expect(find.text('2 selected'), findsOneWidget);
    });

    testWidgets('right-click on file row shows context menu with Rename, Delete, New Folder',
        (tester) async {
      final mockAdb = createMockAdb();
      final deviceProv = createDeviceProvider(mockAdb);
      final browserProv = createBrowserProvider(mockAdb);

      await deviceProv.selectDevice(sampleDevice);
      when(() => mockAdb.listFiles(any()))
          .thenAnswer((_) async => sampleFiles);

      await pumpApp(
        tester,
        const FileBrowser(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: mockAdb,
      );

      await browserProv.navigateTo('/sdcard');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Right-click on the file row for photo.jpg
      await tester.tap(
        find.textContaining('photo.jpg'),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      expect(find.text('Rename'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('New Folder'), findsOneWidget);

      // Dismiss the menu by tapping outside
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
    });

    testWidgets('context menu Rename pre-fills file name and calls renameItem on submit',
        (tester) async {
      final mockAdb = createMockAdb();
      final deviceProv = createDeviceProvider(mockAdb);
      final browserProv = createBrowserProvider(mockAdb);

      await deviceProv.selectDevice(sampleDevice);
      when(() => mockAdb.listFiles(any()))
          .thenAnswer((_) async => sampleFiles);

      await pumpApp(
        tester,
        const FileBrowser(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: mockAdb,
      );

      await browserProv.navigateTo('/sdcard');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Right-click on photo.jpg
      await tester.tap(
        find.textContaining('photo.jpg'),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      // Tap Rename in the context menu
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      // The rename dialog should appear with "Rename File" title
      expect(find.text('Rename File'), findsOneWidget);

      // The text field should be pre-filled with the file name
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, 'photo.jpg');

      // Clear the field and type a new name
      await tester.enterText(find.byType(TextField), 'renamed_photo.jpg');
      await tester.pumpAndSettle();

      // Tap the Rename button in the dialog
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      // Verify renameItem was called via AdbService.rename
      verify(() => mockAdb.rename('/sdcard/photo.jpg', '/sdcard/renamed_photo.jpg')).called(1);
    });

    testWidgets('context menu Delete shows confirmation and calls deleteItems on confirm',
        (tester) async {
      final mockAdb = createMockAdb();
      final deviceProv = createDeviceProvider(mockAdb);
      final browserProv = createBrowserProvider(mockAdb);

      await deviceProv.selectDevice(sampleDevice);
      when(() => mockAdb.listFiles(any()))
          .thenAnswer((_) async => sampleFiles);

      await pumpApp(
        tester,
        const FileBrowser(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: mockAdb,
      );

      await browserProv.navigateTo('/sdcard');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Right-click on notes.txt
      await tester.tap(
        find.textContaining('notes.txt'),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      // Tap Delete in the context menu
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // The delete confirmation dialog should appear
      expect(find.textContaining('Are you sure you want to delete'), findsOneWidget);
      expect(find.textContaining('"notes.txt"'), findsOneWidget);

      // Tap the Delete button in the confirmation dialog
      // There are two Delete texts: title and button. The button is a TextButton child.
      final deleteButtons = find.widgetWithText(TextButton, 'Delete');
      await tester.tap(deleteButtons.last);
      await tester.pumpAndSettle();

      // Verify delete was called via AdbService
      verify(() => mockAdb.delete('/sdcard/notes.txt', recursive: false)).called(1);
    });

    testWidgets('context menu New Folder shows dialog and calls createFolder on submit',
        (tester) async {
      final mockAdb = createMockAdb();
      final deviceProv = createDeviceProvider(mockAdb);
      final browserProv = createBrowserProvider(mockAdb);

      await deviceProv.selectDevice(sampleDevice);
      when(() => mockAdb.listFiles(any()))
          .thenAnswer((_) async => sampleFiles);

      await pumpApp(
        tester,
        const FileBrowser(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: mockAdb,
      );

      await browserProv.navigateTo('/sdcard');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Right-click on photo.jpg to open context menu
      await tester.tap(
        find.textContaining('photo.jpg'),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      // Tap New Folder in the context menu
      await tester.tap(find.text('New Folder'));
      await tester.pumpAndSettle();

      // The New Folder dialog should appear
      // The dialog title is "New Folder" - there are now two: the menu item
      // just dismissed and the dialog title. The menu was dismissed so only
      // the dialog title remains.
      expect(find.text('New Folder'), findsOneWidget);

      // Type a folder name
      await tester.enterText(find.byType(TextField), 'MyNewFolder');
      await tester.pumpAndSettle();

      // Tap the Create button
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      // Verify createDirectory was called via AdbService
      verify(() => mockAdb.createDirectory('/sdcard/MyNewFolder')).called(1);
    });

    testWidgets('right-click on empty area shows context menu with New Folder only',
        (tester) async {
      final mockAdb = createMockAdb();
      final deviceProv = createDeviceProvider(mockAdb);
      final browserProv = createBrowserProvider(mockAdb);

      await deviceProv.selectDevice(sampleDevice);
      when(() => mockAdb.listFiles(any()))
          .thenAnswer((_) async => sampleFiles);

      await pumpApp(
        tester,
        const SizedBox(
          width: 800,
          height: 600,
          child: FileBrowser(),
        ),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: mockAdb,
      );

      await browserProv.navigateTo('/sdcard');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Find the ListView and get its render box to calculate an empty area
      // The file list has items but there is empty space below them.
      // Right-click at the bottom of the list area to hit the GestureDetector
      // wrapping the ListView (which catches secondary taps on empty areas).
      // We need to right-click on an area within the GestureDetector but not
      // on any file row. The GestureDetector has HitTestBehavior.translucent
      // so tapping the empty area below the last row should trigger it.
      final listFinder = find.byType(ListView);
      expect(listFinder, findsOneWidget);

      // Get the render box for the ListView to find coordinates below the rows
      final listBox = tester.getRect(listFinder);

      // Tap at the bottom portion of the list area where no file rows exist
      // Each file row is 36px high, with 4 files that is 144px from the top of the list
      // Tap somewhere well below that
      final emptyAreaPosition = Offset(
        listBox.center.dx,
        listBox.top + 300,
      );

      await tester.tapAt(emptyAreaPosition, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      // The empty area context menu should show only New Folder
      expect(find.text('New Folder'), findsOneWidget);
      expect(find.text('Rename'), findsNothing);
      expect(find.text('Delete'), findsNothing);

      // Tap New Folder to open the dialog
      await tester.tap(find.text('New Folder'));
      await tester.pumpAndSettle();

      // Type a folder name and create it
      await tester.enterText(find.byType(TextField), 'EmptyAreaFolder');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      verify(() => mockAdb.createDirectory('/sdcard/EmptyAreaFolder')).called(1);
    });

    testWidgets('tapping checkbox on file row toggles selection', (tester) async {
      final mockAdb = createMockAdb();
      final deviceProv = createDeviceProvider(mockAdb);
      final browserProv = createBrowserProvider(mockAdb);

      await deviceProv.selectDevice(sampleDevice);
      when(() => mockAdb.listFiles(any()))
          .thenAnswer((_) async => sampleFiles);

      await pumpApp(
        tester,
        const FileBrowser(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: mockAdb,
      );

      await browserProv.navigateTo('/sdcard');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(browserProv.hasSelection, false);

      // Hover over photo.jpg to reveal the checkbox using MouseRegion
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);

      // Find the row containing photo.jpg by finding the AnimatedContainer
      final photoText = find.textContaining('photo.jpg');
      await gesture.addPointer(location: tester.getCenter(photoText));
      await tester.pumpAndSettle();

      // After hovering, the checkbox should be visible
      // Find the checkbox container (it's a Container with width 18, height 18)
      // and tap it. The checkbox is wrapped in a GestureDetector with onTap: onSelect
      final checkboxFinder = find.descendant(
        of: find.ancestor(
          of: photoText,
          matching: find.byType(Row),
        ).first,
        matching: find.byWidgetPredicate(
          (widget) => widget is Container &&
                     (widget.decoration is BoxDecoration) &&
                     widget.constraints?.maxWidth == 18.0,
        ),
      );

      // The checkbox container should exist when hovering
      expect(checkboxFinder, findsOneWidget);

      // Tap on the checkbox
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();

      expect(browserProv.hasSelection, true);
      expect(browserProv.selectionCount, 1);
      expect(browserProv.selectedPaths.contains('/sdcard/photo.jpg'), true);

      await gesture.removePointer();
    });

    testWidgets('rename dialog Enter key submit renames file', (tester) async {
      final mockAdb = createMockAdb();
      final deviceProv = createDeviceProvider(mockAdb);
      final browserProv = createBrowserProvider(mockAdb);

      await deviceProv.selectDevice(sampleDevice);
      when(() => mockAdb.listFiles(any()))
          .thenAnswer((_) async => sampleFiles);

      await pumpApp(
        tester,
        const FileBrowser(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: mockAdb,
      );

      await browserProv.navigateTo('/sdcard');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Right-click on photo.jpg
      await tester.tap(
        find.textContaining('photo.jpg'),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      // Tap Rename in the context menu
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      // Enter new name
      await tester.enterText(find.byType(TextField), 'new_photo.jpg');
      await tester.pumpAndSettle();

      // Submit via Enter key
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Verify rename was called
      verify(() => mockAdb.rename('/sdcard/photo.jpg', '/sdcard/new_photo.jpg')).called(1);
    });

    testWidgets('rename dialog Cancel button dismisses without renaming', (tester) async {
      final mockAdb = createMockAdb();
      final deviceProv = createDeviceProvider(mockAdb);
      final browserProv = createBrowserProvider(mockAdb);

      await deviceProv.selectDevice(sampleDevice);
      when(() => mockAdb.listFiles(any()))
          .thenAnswer((_) async => sampleFiles);

      await pumpApp(
        tester,
        const FileBrowser(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: mockAdb,
      );

      await browserProv.navigateTo('/sdcard');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Right-click on photo.jpg
      await tester.tap(
        find.textContaining('photo.jpg'),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      // Tap Rename in the context menu
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      // Enter new name
      await tester.enterText(find.byType(TextField), 'new_photo.jpg');
      await tester.pumpAndSettle();

      // Tap Cancel button
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Verify rename was NOT called
      verifyNever(() => mockAdb.rename(any(), any()));
    });

    testWidgets('rename dialog for directory selects full name', (tester) async {
      final mockAdb = createMockAdb();
      final deviceProv = createDeviceProvider(mockAdb);
      final browserProv = createBrowserProvider(mockAdb);

      await deviceProv.selectDevice(sampleDevice);
      when(() => mockAdb.listFiles(any()))
          .thenAnswer((_) async => sampleFiles);

      await pumpApp(
        tester,
        const FileBrowser(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: mockAdb,
      );

      await browserProv.navigateTo('/sdcard');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Right-click on Download directory
      await tester.tap(
        find.textContaining('Download'),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      // Tap Rename in the context menu
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      // Check that the text field has the full name selected
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, 'Download');
      expect(textField.controller!.selection.baseOffset, 0);
      expect(textField.controller!.selection.extentOffset, 'Download'.length);

      // Dismiss the dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('rename dialog for file without extension selects full name', (tester) async {
      final mockAdb = createMockAdb();
      final deviceProv = createDeviceProvider(mockAdb);
      final browserProv = createBrowserProvider(mockAdb);

      await deviceProv.selectDevice(sampleDevice);

      // Create a file without extension
      const fileWithoutExtension = AndroidFile(
        name: 'README',
        path: '/sdcard/README',
        isDirectory: false,
        size: 1000,
      );

      when(() => mockAdb.listFiles(any()))
          .thenAnswer((_) async => [fileWithoutExtension]);

      await pumpApp(
        tester,
        const FileBrowser(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: mockAdb,
      );

      await browserProv.navigateTo('/sdcard');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Right-click on README
      await tester.tap(
        find.textContaining('README'),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      // Tap Rename in the context menu
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      // Check that the text field has the full name selected
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, 'README');
      expect(textField.controller!.selection.baseOffset, 0);
      expect(textField.controller!.selection.extentOffset, 'README'.length);

      // Dismiss the dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('new folder dialog Enter key submit creates folder', (tester) async {
      final mockAdb = createMockAdb();
      final deviceProv = createDeviceProvider(mockAdb);
      final browserProv = createBrowserProvider(mockAdb);

      await deviceProv.selectDevice(sampleDevice);
      when(() => mockAdb.listFiles(any()))
          .thenAnswer((_) async => sampleFiles);

      await pumpApp(
        tester,
        const FileBrowser(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: mockAdb,
      );

      await browserProv.navigateTo('/sdcard');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Right-click on photo.jpg to open context menu
      await tester.tap(
        find.textContaining('photo.jpg'),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      // Tap New Folder in the context menu
      await tester.tap(find.text('New Folder'));
      await tester.pumpAndSettle();

      // Type a folder name
      await tester.enterText(find.byType(TextField), 'NewFolderViaEnter');
      await tester.pumpAndSettle();

      // Submit via Enter key
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Verify createDirectory was called
      verify(() => mockAdb.createDirectory('/sdcard/NewFolderViaEnter')).called(1);
    });

    testWidgets('new folder dialog Cancel button dismisses without creating', (tester) async {
      final mockAdb = createMockAdb();
      final deviceProv = createDeviceProvider(mockAdb);
      final browserProv = createBrowserProvider(mockAdb);

      await deviceProv.selectDevice(sampleDevice);
      when(() => mockAdb.listFiles(any()))
          .thenAnswer((_) async => sampleFiles);

      await pumpApp(
        tester,
        const FileBrowser(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: mockAdb,
      );

      await browserProv.navigateTo('/sdcard');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Right-click to open context menu
      await tester.tap(
        find.textContaining('photo.jpg'),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      // Tap New Folder in the context menu
      await tester.tap(find.text('New Folder'));
      await tester.pumpAndSettle();

      // Type a folder name
      await tester.enterText(find.byType(TextField), 'ShouldNotCreate');
      await tester.pumpAndSettle();

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Verify createDirectory was NOT called
      verifyNever(() => mockAdb.createDirectory('/sdcard/ShouldNotCreate'));
    });

    testWidgets('context menu Delete Cancel dismisses without deleting', (tester) async {
      final mockAdb = createMockAdb();
      final deviceProv = createDeviceProvider(mockAdb);
      final browserProv = createBrowserProvider(mockAdb);

      await deviceProv.selectDevice(sampleDevice);
      when(() => mockAdb.listFiles(any()))
          .thenAnswer((_) async => sampleFiles);

      await pumpApp(
        tester,
        const FileBrowser(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: mockAdb,
      );

      await browserProv.navigateTo('/sdcard');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Right-click on notes.txt
      await tester.tap(
        find.textContaining('notes.txt'),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      // Tap Delete in the context menu
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // The delete confirmation dialog should appear
      expect(find.textContaining('Are you sure you want to delete'), findsOneWidget);

      // Tap Cancel in the confirmation dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Verify delete was NOT called
      verifyNever(() => mockAdb.delete(any(), recursive: any(named: 'recursive')));
    });

    testWidgets('file row hover changes background color', (tester) async {
      final mockAdb = createMockAdb();
      final deviceProv = createDeviceProvider(mockAdb);
      final browserProv = createBrowserProvider(mockAdb);

      await deviceProv.selectDevice(sampleDevice);
      when(() => mockAdb.listFiles(any()))
          .thenAnswer((_) async => sampleFiles);

      await pumpApp(
        tester,
        const FileBrowser(),
        deviceProvider: deviceProv,
        browserProvider: browserProv,
        adb: mockAdb,
      );

      await browserProv.navigateTo('/sdcard');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Find the file row container for photo.jpg
      final photoRow = find.textContaining('photo.jpg');
      expect(photoRow, findsOneWidget);

      // Find the AnimatedContainer that changes background on hover
      // It's the parent of the Row containing the file info
      final animatedContainer = find.ancestor(
        of: find.textContaining('photo.jpg'),
        matching: find.byType(AnimatedContainer),
      ).first;

      // Get initial background color (should be transparent)
      var container = tester.widget<AnimatedContainer>(animatedContainer);
      var decoration = container.decoration as BoxDecoration?;
      expect(decoration?.color, Colors.transparent);

      // Hover over the row using mouse gesture
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: tester.getCenter(photoRow));
      await tester.pumpAndSettle();

      // Check that background changed
      container = tester.widget<AnimatedContainer>(animatedContainer);
      decoration = container.decoration as BoxDecoration?;
      expect(decoration?.color, isNot(Colors.transparent));

      // Move mouse away
      await gesture.moveTo(Offset.zero);
      await tester.pumpAndSettle();

      // Check that background is transparent again
      container = tester.widget<AnimatedContainer>(animatedContainer);
      decoration = container.decoration as BoxDecoration?;
      expect(decoration?.color, Colors.transparent);

      await gesture.removePointer();
    });
  });
}
