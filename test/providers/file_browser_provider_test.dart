import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:filedroid/providers/file_browser_provider.dart';
import 'package:filedroid/services/adb_service.dart';
import 'package:filedroid/models/android_file.dart';

class MockAdbService extends Mock implements AdbService {}

void main() {
  late MockAdbService mockAdb;
  late FileBrowserProvider provider;

  final sampleFiles = [
    const AndroidFile(name: 'Download', path: '/sdcard/Download', isDirectory: true),
    const AndroidFile(name: 'DCIM', path: '/sdcard/DCIM', isDirectory: true),
    const AndroidFile(name: 'photo.jpg', path: '/sdcard/photo.jpg', isDirectory: false, size: 1024),
    const AndroidFile(name: 'notes.txt', path: '/sdcard/notes.txt', isDirectory: false, size: 200),
  ];

  setUp(() {
    mockAdb = MockAdbService();
    provider = FileBrowserProvider(mockAdb);
  });

  group('FileBrowserProvider', () {
    group('initial state', () {
      test('currentPath is /sdcard', () {
        expect(provider.currentPath, '/sdcard');
      });

      test('files is empty', () {
        expect(provider.files, isEmpty);
      });

      test('showHidden is false', () {
        expect(provider.showHidden, isFalse);
      });

      test('sortMode is name', () {
        expect(provider.sortMode, SortMode.name);
      });

      test('sortAscending is true', () {
        expect(provider.sortAscending, isTrue);
      });

      test('isLoading is false', () {
        expect(provider.isLoading, isFalse);
      });

      test('error is null', () {
        expect(provider.error, isNull);
      });

      test('canGoBack is false', () {
        expect(provider.canGoBack, isFalse);
      });

      test('canGoForward is false', () {
        expect(provider.canGoForward, isFalse);
      });

      test('hasSelection is false', () {
        expect(provider.hasSelection, isFalse);
      });

      test('selectionCount is 0', () {
        expect(provider.selectionCount, 0);
      });
    });

    group('navigateTo', () {
      test('sets path and loads files', () async {
        when(() => mockAdb.listFiles('/sdcard')).thenAnswer((_) async => sampleFiles);

        await provider.navigateTo('/sdcard');

        expect(provider.currentPath, '/sdcard');
        expect(provider.files.length, 4);
        expect(provider.isLoading, isFalse);
        expect(provider.error, isNull);
      });

      test('sets error on exception', () async {
        when(() => mockAdb.listFiles(any())).thenThrow(
          const AdbException('Permission denied'),
        );

        await provider.navigateTo('/sdcard/secret');

        expect(provider.error, isNotNull);
        expect(provider.isLoading, isFalse);
      });

      test('clears selection on navigate', () async {
        when(() => mockAdb.listFiles(any())).thenAnswer((_) async => sampleFiles);

        await provider.navigateTo('/sdcard');
        provider.toggleSelection(sampleFiles[2]); // select photo.jpg
        expect(provider.hasSelection, isTrue);

        await provider.navigateTo('/sdcard/Download');
        expect(provider.hasSelection, isFalse);
      });

      test('updates history', () async {
        when(() => mockAdb.listFiles(any())).thenAnswer((_) async => []);

        await provider.navigateTo('/sdcard');
        await provider.navigateTo('/sdcard/Download');

        expect(provider.canGoBack, isTrue);
        expect(provider.canGoForward, isFalse);
      });
    });

    group('navigateUp', () {
      test('goes to parent directory', () async {
        when(() => mockAdb.listFiles(any())).thenAnswer((_) async => []);

        await provider.navigateTo('/sdcard/Download');
        await provider.navigateUp();

        expect(provider.currentPath, '/sdcard');
      });

      test('goes to root from top-level', () async {
        when(() => mockAdb.listFiles(any())).thenAnswer((_) async => []);

        await provider.navigateTo('/sdcard');
        await provider.navigateUp();

        expect(provider.currentPath, '/');
      });

      test('stays at root when already at root', () async {
        when(() => mockAdb.listFiles(any())).thenAnswer((_) async => []);

        await provider.navigateTo('/');
        await provider.navigateUp();

        expect(provider.currentPath, '/');
      });
    });

    group('goBack / goForward', () {
      test('goBack navigates to previous path', () async {
        when(() => mockAdb.listFiles(any())).thenAnswer((_) async => []);

        await provider.navigateTo('/sdcard');
        await provider.navigateTo('/sdcard/Download');
        await provider.goBack();

        expect(provider.currentPath, '/sdcard');
        expect(provider.canGoForward, isTrue);
      });

      test('goForward navigates to next path', () async {
        when(() => mockAdb.listFiles(any())).thenAnswer((_) async => []);

        await provider.navigateTo('/sdcard');
        await provider.navigateTo('/sdcard/Download');
        await provider.goBack();
        await provider.goForward();

        expect(provider.currentPath, '/sdcard/Download');
      });

      test('goBack does nothing when at start of history', () async {
        when(() => mockAdb.listFiles(any())).thenAnswer((_) async => []);

        // Initial state: history = ['/sdcard'], index = 0 → canGoBack = false
        expect(provider.canGoBack, isFalse);

        await provider.navigateTo('/sdcard');
        // Now history = ['/sdcard', '/sdcard'], index = 1 → canGoBack = true
        // Go back to the initial entry
        await provider.goBack();
        expect(provider.canGoBack, isFalse);

        // Now at start — goBack should be a no-op
        await provider.goBack();
        expect(provider.currentPath, '/sdcard');
      });

      test('goForward does nothing when at end of history', () async {
        when(() => mockAdb.listFiles(any())).thenAnswer((_) async => []);

        await provider.navigateTo('/sdcard');
        expect(provider.canGoForward, isFalse);

        await provider.goForward();
        expect(provider.currentPath, '/sdcard');
      });

      test('goBack sets error on exception', () async {
        when(() => mockAdb.listFiles('/sdcard')).thenAnswer((_) async => []);
        await provider.navigateTo('/sdcard');

        when(() => mockAdb.listFiles('/sdcard/sub')).thenAnswer((_) async => []);
        await provider.navigateTo('/sdcard/sub');

        // Make goBack fail
        when(() => mockAdb.listFiles('/sdcard')).thenThrow(
          const AdbException('read error'),
        );
        await provider.goBack();

        expect(provider.error, isNotNull);
        expect(provider.isLoading, isFalse);
      });

      test('goForward sets error on exception', () async {
        when(() => mockAdb.listFiles(any())).thenAnswer((_) async => []);
        await provider.navigateTo('/sdcard');
        await provider.navigateTo('/sdcard/sub');
        await provider.goBack();

        // Make goForward fail
        when(() => mockAdb.listFiles('/sdcard/sub')).thenThrow(
          const AdbException('read error'),
        );
        await provider.goForward();

        expect(provider.error, isNotNull);
        expect(provider.isLoading, isFalse);
      });

      test('navigating after goBack truncates forward history', () async {
        when(() => mockAdb.listFiles(any())).thenAnswer((_) async => []);

        await provider.navigateTo('/sdcard');
        await provider.navigateTo('/sdcard/Download');
        await provider.navigateTo('/sdcard/DCIM');
        await provider.goBack(); // at Download
        await provider.navigateTo('/sdcard/Music'); // truncates DCIM

        expect(provider.canGoForward, isFalse);
      });
    });

    group('refresh', () {
      test('reloads current path', () async {
        when(() => mockAdb.listFiles('/sdcard')).thenAnswer((_) async => sampleFiles);

        await provider.navigateTo('/sdcard');
        expect(provider.files.length, 4);

        when(() => mockAdb.listFiles('/sdcard')).thenAnswer((_) async => [
          const AndroidFile(name: 'new.txt', path: '/sdcard/new.txt', isDirectory: false),
        ]);
        await provider.refresh();

        expect(provider.files.length, 1);
        expect(provider.files.first.name, 'new.txt');
      });
    });

    group('refresh error', () {
      test('sets error on exception', () async {
        when(() => mockAdb.listFiles(any())).thenAnswer((_) async => sampleFiles);
        await provider.navigateTo('/sdcard');

        when(() => mockAdb.listFiles('/sdcard')).thenThrow(
          const AdbException('device offline'),
        );
        await provider.refresh();

        expect(provider.error, isNotNull);
        expect(provider.isLoading, isFalse);
      });
    });

    group('selection', () {
      setUp(() {
        when(() => mockAdb.listFiles(any())).thenAnswer((_) async => sampleFiles);
      });

      test('toggleSelection adds file', () async {
        await provider.navigateTo('/sdcard');
        provider.toggleSelection(sampleFiles[2]); // photo.jpg

        expect(provider.hasSelection, isTrue);
        expect(provider.selectionCount, 1);
        expect(provider.selectedPaths.contains('/sdcard/photo.jpg'), isTrue);
      });

      test('toggleSelection removes file when already selected', () async {
        await provider.navigateTo('/sdcard');
        provider.toggleSelection(sampleFiles[2]);
        provider.toggleSelection(sampleFiles[2]);

        expect(provider.hasSelection, isFalse);
        expect(provider.selectionCount, 0);
      });

      test('selectAll selects only non-directory files', () async {
        await provider.navigateTo('/sdcard');
        provider.selectAll();

        expect(provider.selectionCount, 2); // photo.jpg and notes.txt only
        expect(provider.selectedPaths.contains('/sdcard/Download'), isFalse);
        expect(provider.selectedPaths.contains('/sdcard/DCIM'), isFalse);
        expect(provider.selectedPaths.contains('/sdcard/photo.jpg'), isTrue);
        expect(provider.selectedPaths.contains('/sdcard/notes.txt'), isTrue);
      });

      test('deselectAll clears all selections', () async {
        await provider.navigateTo('/sdcard');
        provider.selectAll();
        provider.deselectAll();

        expect(provider.hasSelection, isFalse);
        expect(provider.selectionCount, 0);
      });

      test('selectedFiles returns selected AndroidFile objects', () async {
        await provider.navigateTo('/sdcard');
        provider.toggleSelection(sampleFiles[2]); // photo.jpg

        final selected = provider.selectedFiles;
        expect(selected.length, 1);
        expect(selected.first.name, 'photo.jpg');
      });
    });

    group('toggleHidden', () {
      test('shows hidden files when toggled on', () async {
        final filesWithHidden = [
          ...sampleFiles,
          const AndroidFile(name: '.hidden', path: '/sdcard/.hidden', isDirectory: false),
        ];
        when(() => mockAdb.listFiles(any())).thenAnswer((_) async => filesWithHidden);

        await provider.navigateTo('/sdcard');
        expect(provider.files.length, 4); // hidden excluded

        provider.toggleHidden();
        expect(provider.showHidden, isTrue);
        expect(provider.files.length, 5); // hidden included
      });

      test('hides hidden files when toggled off', () async {
        final filesWithHidden = [
          ...sampleFiles,
          const AndroidFile(name: '.config', path: '/sdcard/.config', isDirectory: true),
        ];
        when(() => mockAdb.listFiles(any())).thenAnswer((_) async => filesWithHidden);

        await provider.navigateTo('/sdcard');
        provider.toggleHidden(); // show
        expect(provider.files.length, 5);

        provider.toggleHidden(); // hide again
        expect(provider.showHidden, isFalse);
        expect(provider.files.length, 4);
      });
    });

    group('setSortMode', () {
      test('toggles ascending when same mode', () {
        provider.setSortMode(SortMode.name); // already name, toggles
        expect(provider.sortAscending, isFalse);

        provider.setSortMode(SortMode.name); // toggle again
        expect(provider.sortAscending, isTrue);
      });

      test('resets ascending when different mode', () {
        provider.setSortMode(SortMode.name); // toggle to descending
        expect(provider.sortAscending, isFalse);

        provider.setSortMode(SortMode.size); // new mode, reset to ascending
        expect(provider.sortMode, SortMode.size);
        expect(provider.sortAscending, isTrue);
      });

      test('sorts by size correctly', () async {
        when(() => mockAdb.listFiles(any())).thenAnswer((_) async => [
          const AndroidFile(name: 'big.mp4', path: '/sdcard/big.mp4', isDirectory: false, size: 5000),
          const AndroidFile(name: 'small.txt', path: '/sdcard/small.txt', isDirectory: false, size: 100),
          const AndroidFile(name: 'medium.jpg', path: '/sdcard/medium.jpg', isDirectory: false, size: 1000),
        ]);

        await provider.navigateTo('/sdcard');
        provider.setSortMode(SortMode.size);

        expect(provider.files[0].name, 'small.txt');
        expect(provider.files[2].name, 'big.mp4');
      });

      test('sorts directories first always', () async {
        when(() => mockAdb.listFiles(any())).thenAnswer((_) async => [
          const AndroidFile(name: 'a.txt', path: '/sdcard/a.txt', isDirectory: false),
          const AndroidFile(name: 'ZFolder', path: '/sdcard/ZFolder', isDirectory: true),
        ]);

        await provider.navigateTo('/sdcard');

        expect(provider.files[0].name, 'ZFolder');
        expect(provider.files[1].name, 'a.txt');
      });

      test('sorts by date', () async {
        when(() => mockAdb.listFiles(any())).thenAnswer((_) async => [
          AndroidFile(name: 'old.txt', path: '/sdcard/old.txt', isDirectory: false, modified: DateTime(2020)),
          AndroidFile(name: 'new.txt', path: '/sdcard/new.txt', isDirectory: false, modified: DateTime(2025)),
        ]);

        await provider.navigateTo('/sdcard');
        provider.setSortMode(SortMode.date);

        expect(provider.files[0].name, 'old.txt');
        expect(provider.files[1].name, 'new.txt');
      });

      test('sorts by type (extension)', () async {
        when(() => mockAdb.listFiles(any())).thenAnswer((_) async => [
          const AndroidFile(name: 'photo.png', path: '/sdcard/photo.png', isDirectory: false),
          const AndroidFile(name: 'doc.csv', path: '/sdcard/doc.csv', isDirectory: false),
        ]);

        await provider.navigateTo('/sdcard');
        provider.setSortMode(SortMode.type);

        expect(provider.files[0].name, 'doc.csv'); // csv before png
        expect(provider.files[1].name, 'photo.png');
      });

      test('descending reverses order', () async {
        when(() => mockAdb.listFiles(any())).thenAnswer((_) async => [
          const AndroidFile(name: 'a.txt', path: '/sdcard/a.txt', isDirectory: false),
          const AndroidFile(name: 'z.txt', path: '/sdcard/z.txt', isDirectory: false),
        ]);

        await provider.navigateTo('/sdcard');
        // Default is ascending by name: a, z
        expect(provider.files[0].name, 'a.txt');

        provider.setSortMode(SortMode.name); // toggles to descending
        expect(provider.files[0].name, 'z.txt');
        expect(provider.files[1].name, 'a.txt');
      });
    });

    group('breadcrumbs', () {
      test('root returns single /', () async {
        when(() => mockAdb.listFiles(any())).thenAnswer((_) async => []);

        await provider.navigateTo('/');

        expect(provider.breadcrumbs, ['/']);
      });

      test('sdcard returns / and sdcard', () async {
        when(() => mockAdb.listFiles(any())).thenAnswer((_) async => []);

        await provider.navigateTo('/sdcard');

        expect(provider.breadcrumbs, ['/', 'sdcard']);
      });

      test('nested path returns all parts', () async {
        when(() => mockAdb.listFiles(any())).thenAnswer((_) async => []);

        await provider.navigateTo('/sdcard/Download/test');

        expect(provider.breadcrumbs, ['/', 'sdcard', 'Download', 'test']);
      });
    });

    group('pathForBreadcrumb', () {
      test('index 0 returns /', () async {
        when(() => mockAdb.listFiles(any())).thenAnswer((_) async => []);
        await provider.navigateTo('/sdcard/Download');

        expect(provider.pathForBreadcrumb(0), '/');
      });

      test('index 1 returns /sdcard', () async {
        when(() => mockAdb.listFiles(any())).thenAnswer((_) async => []);
        await provider.navigateTo('/sdcard/Download');

        expect(provider.pathForBreadcrumb(1), '/sdcard');
      });

      test('index 2 returns /sdcard/Download', () async {
        when(() => mockAdb.listFiles(any())).thenAnswer((_) async => []);
        await provider.navigateTo('/sdcard/Download');

        expect(provider.pathForBreadcrumb(2), '/sdcard/Download');
      });
    });

    group('contextLabel', () {
      test('returns Internal Storage for /sdcard', () async {
        when(() => mockAdb.listFiles(any())).thenAnswer((_) async => []);
        await provider.navigateTo('/sdcard');

        expect(provider.contextLabel, 'Internal Storage');
      });

      test('returns joined parts for nested sdcard path', () async {
        when(() => mockAdb.listFiles(any())).thenAnswer((_) async => []);
        await provider.navigateTo('/sdcard/Download/test');

        expect(provider.contextLabel, 'Download / test');
      });

      test('returns joined parts for non-sdcard path', () async {
        when(() => mockAdb.listFiles(any())).thenAnswer((_) async => []);
        await provider.navigateTo('/data/local');

        expect(provider.contextLabel, 'data / local');
      });
    });

    group('isAtRoot', () {
      test('true when at /', () async {
        when(() => mockAdb.listFiles(any())).thenAnswer((_) async => []);
        await provider.navigateTo('/');

        expect(provider.isAtRoot, isTrue);
      });

      test('false when not at /', () async {
        when(() => mockAdb.listFiles(any())).thenAnswer((_) async => []);
        await provider.navigateTo('/sdcard');

        expect(provider.isAtRoot, isFalse);
      });
    });

    group('createFolder', () {
      test('creates directory and refreshes', () async {
        when(() => mockAdb.listFiles(any())).thenAnswer((_) async => sampleFiles);
        when(() => mockAdb.createDirectory('/sdcard/NewFolder')).thenAnswer((_) async => true);

        await provider.navigateTo('/sdcard');
        final ok = await provider.createFolder('NewFolder');

        expect(ok, isTrue);
        verify(() => mockAdb.createDirectory('/sdcard/NewFolder')).called(1);
        // refresh should be called (listFiles called twice - once navigate, once refresh)
        verify(() => mockAdb.listFiles('/sdcard')).called(2);
      });

      test('does not refresh on failure', () async {
        when(() => mockAdb.listFiles(any())).thenAnswer((_) async => sampleFiles);
        when(() => mockAdb.createDirectory(any())).thenAnswer((_) async => false);

        await provider.navigateTo('/sdcard');
        final ok = await provider.createFolder('bad');

        expect(ok, isFalse);
        verify(() => mockAdb.listFiles('/sdcard')).called(1); // only the initial navigate
      });

      test('builds correct path at root', () async {
        when(() => mockAdb.listFiles(any())).thenAnswer((_) async => []);
        when(() => mockAdb.createDirectory('/test')).thenAnswer((_) async => true);

        await provider.navigateTo('/');
        await provider.createFolder('test');

        verify(() => mockAdb.createDirectory('/test')).called(1);
      });
    });

    group('renameItem', () {
      test('renames file and refreshes', () async {
        when(() => mockAdb.listFiles(any())).thenAnswer((_) async => sampleFiles);
        when(() => mockAdb.rename(any(), any())).thenAnswer((_) async => true);

        await provider.navigateTo('/sdcard');
        final file = sampleFiles[2]; // photo.jpg
        final ok = await provider.renameItem(file, 'renamed.jpg');

        expect(ok, isTrue);
        verify(() => mockAdb.rename('/sdcard/photo.jpg', '/sdcard/renamed.jpg')).called(1);
      });

      test('does not refresh on failure', () async {
        when(() => mockAdb.listFiles(any())).thenAnswer((_) async => sampleFiles);
        when(() => mockAdb.rename(any(), any())).thenAnswer((_) async => false);

        await provider.navigateTo('/sdcard');
        final ok = await provider.renameItem(sampleFiles[2], 'new.jpg');

        expect(ok, isFalse);
        verify(() => mockAdb.listFiles('/sdcard')).called(1); // only navigate
      });
    });

    group('deleteItems', () {
      test('deletes each item and refreshes', () async {
        when(() => mockAdb.listFiles(any())).thenAnswer((_) async => sampleFiles);
        when(() => mockAdb.delete(any(), recursive: any(named: 'recursive')))
            .thenAnswer((_) async => true);

        await provider.navigateTo('/sdcard');
        provider.toggleSelection(sampleFiles[2]); // select photo.jpg

        await provider.deleteItems([sampleFiles[0], sampleFiles[2]]);

        // Dir uses recursive, file does not
        verify(() => mockAdb.delete('/sdcard/Download', recursive: true)).called(1);
        verify(() => mockAdb.delete('/sdcard/photo.jpg', recursive: false)).called(1);
        expect(provider.hasSelection, isFalse);
      });
    });

    group('activeQuickAccess', () {
      setUp(() {
        when(() => mockAdb.listFiles(any())).thenAnswer((_) async => []);
      });

      test('returns Internal Storage for /sdcard', () async {
        await provider.navigateTo('/sdcard');
        expect(provider.activeQuickAccess, 'Internal Storage');
      });

      test('returns Downloads for /sdcard/Download', () async {
        await provider.navigateTo('/sdcard/Download');
        expect(provider.activeQuickAccess, 'Downloads');
      });

      test('returns Camera for /sdcard/DCIM', () async {
        await provider.navigateTo('/sdcard/DCIM');
        expect(provider.activeQuickAccess, 'Camera');
      });

      test('returns Pictures for /sdcard/Pictures', () async {
        await provider.navigateTo('/sdcard/Pictures');
        expect(provider.activeQuickAccess, 'Pictures');
      });

      test('returns Documents for /sdcard/Documents', () async {
        await provider.navigateTo('/sdcard/Documents');
        expect(provider.activeQuickAccess, 'Documents');
      });

      test('returns Music for /sdcard/Music', () async {
        await provider.navigateTo('/sdcard/Music');
        expect(provider.activeQuickAccess, 'Music');
      });

      test('returns Movies for /sdcard/Movies', () async {
        await provider.navigateTo('/sdcard/Movies');
        expect(provider.activeQuickAccess, 'Movies');
      });

      test('returns null for non-quick-access path', () async {
        await provider.navigateTo('/data/local');
        expect(provider.activeQuickAccess, isNull);
      });

      test('matches nested paths under quick access', () async {
        await provider.navigateTo('/sdcard/Download/sub/folder');
        expect(provider.activeQuickAccess, 'Downloads');
      });
    });

    group('quick navigation methods', () {
      setUp(() {
        when(() => mockAdb.listFiles(any())).thenAnswer((_) async => []);
      });

      test('goToSdcard navigates to /sdcard', () async {
        await provider.goToSdcard();
        expect(provider.currentPath, '/sdcard');
      });

      test('goToDownloads navigates to /sdcard/Download', () async {
        await provider.goToDownloads();
        expect(provider.currentPath, '/sdcard/Download');
      });

      test('goToDCIM navigates to /sdcard/DCIM', () async {
        await provider.goToDCIM();
        expect(provider.currentPath, '/sdcard/DCIM');
      });

      test('goToDocuments navigates to /sdcard/Documents', () async {
        await provider.goToDocuments();
        expect(provider.currentPath, '/sdcard/Documents');
      });

      test('goToMusic navigates to /sdcard/Music', () async {
        await provider.goToMusic();
        expect(provider.currentPath, '/sdcard/Music');
      });

      test('goToMovies navigates to /sdcard/Movies', () async {
        await provider.goToMovies();
        expect(provider.currentPath, '/sdcard/Movies');
      });

      test('goToPictures navigates to /sdcard/Pictures', () async {
        await provider.goToPictures();
        expect(provider.currentPath, '/sdcard/Pictures');
      });
    });
  });
}
