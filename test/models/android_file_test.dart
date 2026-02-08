import 'package:flutter_test/flutter_test.dart';
import 'package:filedroid/models/android_file.dart';
import 'package:filedroid/utils/theme.dart';

void main() {
  group('AndroidFile', () {
    group('extension', () {
      test('returns extension for regular file', () {
        const file = AndroidFile(name: 'photo.jpg', path: '/sdcard/photo.jpg', isDirectory: false);
        expect(file.extension, 'jpg');
      });

      test('returns lowercase extension', () {
        const file = AndroidFile(name: 'photo.PNG', path: '/p', isDirectory: false);
        expect(file.extension, 'png');
      });

      test('returns empty for directory', () {
        const file = AndroidFile(name: 'Download', path: '/sdcard/Download', isDirectory: true);
        expect(file.extension, '');
      });

      test('returns empty for file without extension', () {
        const file = AndroidFile(name: 'Makefile', path: '/Makefile', isDirectory: false);
        expect(file.extension, '');
      });

      test('returns empty for file ending with dot', () {
        const file = AndroidFile(name: 'file.', path: '/file.', isDirectory: false);
        expect(file.extension, '');
      });

      test('returns last extension for double extension', () {
        const file = AndroidFile(name: 'archive.tar.gz', path: '/a', isDirectory: false);
        expect(file.extension, 'gz');
      });

      test('handles dotfile', () {
        const file = AndroidFile(name: '.gitignore', path: '/.gitignore', isDirectory: false);
        expect(file.extension, 'gitignore');
      });
    });

    group('formattedSize', () {
      test('returns -- for directory', () {
        const file = AndroidFile(name: 'd', path: '/d', isDirectory: true, size: 4096);
        expect(file.formattedSize, '--');
      });

      test('returns bytes for small files', () {
        const file = AndroidFile(name: 'f', path: '/f', isDirectory: false, size: 500);
        expect(file.formattedSize, '500 B');
      });

      test('returns KB for kilobyte range', () {
        const file = AndroidFile(name: 'f', path: '/f', isDirectory: false, size: 2048);
        expect(file.formattedSize, '2 KB');
      });

      test('returns MB with one decimal for small MB', () {
        const file = AndroidFile(name: 'f', path: '/f', isDirectory: false, size: 5 * 1024 * 1024);
        expect(file.formattedSize, '5.0 MB');
      });

      test('returns MB without decimal for large MB', () {
        const file = AndroidFile(name: 'f', path: '/f', isDirectory: false, size: 50 * 1024 * 1024);
        expect(file.formattedSize, '50 MB');
      });

      test('returns GB for gigabyte range', () {
        const file = AndroidFile(name: 'f', path: '/f', isDirectory: false, size: 2 * 1024 * 1024 * 1024);
        expect(file.formattedSize, '2.0 GB');
      });

      test('returns 0 B for zero size file', () {
        const file = AndroidFile(name: 'f', path: '/f', isDirectory: false, size: 0);
        expect(file.formattedSize, '0 B');
      });
    });

    group('formattedDate', () {
      test('returns -- when modified is null', () {
        const file = AndroidFile(name: 'f', path: '/f', isDirectory: false);
        expect(file.formattedDate, '--');
      });

      test('returns formatted date', () {
        final file = AndroidFile(
          name: 'f', path: '/f', isDirectory: false,
          modified: DateTime(2025, 2, 7),
        );
        expect(file.formattedDate, 'Feb 7, 2025');
      });

      test('formats different months', () {
        final file = AndroidFile(
          name: 'f', path: '/f', isDirectory: false,
          modified: DateTime(2024, 12, 25),
        );
        expect(file.formattedDate, 'Dec 25, 2024');
      });
    });

    group('badgeText', () {
      test('returns first 2 chars for directory', () {
        const file = AndroidFile(name: 'Download', path: '/d', isDirectory: true);
        expect(file.badgeText, 'DO');
      });

      test('returns single char for 1-char directory name', () {
        const file = AndroidFile(name: 'D', path: '/D', isDirectory: true);
        expect(file.badgeText, 'D');
      });

      test('returns IM for image files', () {
        const file = AndroidFile(name: 'photo.jpg', path: '/p', isDirectory: false);
        expect(file.badgeText, 'IM');
      });

      test('returns VD for video files', () {
        const file = AndroidFile(name: 'movie.mp4', path: '/m', isDirectory: false);
        expect(file.badgeText, 'VD');
      });

      test('returns AU for audio files', () {
        const file = AndroidFile(name: 'song.mp3', path: '/s', isDirectory: false);
        expect(file.badgeText, 'AU');
      });
    });

    group('badgeColor', () {
      test('returns indigo for directory', () {
        const file = AndroidFile(name: 'Dir', path: '/d', isDirectory: true);
        expect(file.badgeColor, FileDroidTheme.dirBadgeColor);
      });

      test('returns purple for image', () {
        const file = AndroidFile(name: 'a.png', path: '/a', isDirectory: false);
        expect(file.badgeColor, FileDroidTheme.purple);
      });

      test('returns roseError for video', () {
        const file = AndroidFile(name: 'a.mp4', path: '/a', isDirectory: false);
        expect(file.badgeColor, FileDroidTheme.roseError);
      });

      test('returns amberWarning for audio', () {
        const file = AndroidFile(name: 'a.mp3', path: '/a', isDirectory: false);
        expect(file.badgeColor, FileDroidTheme.amberWarning);
      });
    });

    group('constructor defaults', () {
      test('size defaults to 0', () {
        const file = AndroidFile(name: 'f', path: '/f', isDirectory: false);
        expect(file.size, 0);
      });

      test('isSymlink defaults to false', () {
        const file = AndroidFile(name: 'f', path: '/f', isDirectory: false);
        expect(file.isSymlink, isFalse);
      });

      test('modified defaults to null', () {
        const file = AndroidFile(name: 'f', path: '/f', isDirectory: false);
        expect(file.modified, isNull);
      });

      test('permissions defaults to null', () {
        const file = AndroidFile(name: 'f', path: '/f', isDirectory: false);
        expect(file.permissions, isNull);
      });
    });
  });
}
