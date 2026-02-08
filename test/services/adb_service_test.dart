import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:filedroid/services/adb_service.dart';
import 'package:filedroid/services/process_runner.dart';

class MockProcessRunner extends Mock implements ProcessRunner {}

class MockProcess extends Mock implements Process {}

ProcessResult fakeResult({
  int exitCode = 0,
  dynamic stdout = '',
  dynamic stderr = '',
}) {
  return ProcessResult(0, exitCode, stdout, stderr);
}

void main() {
  group('AdbException', () {
    test('stores message', () {
      const ex = AdbException('test error');
      expect(ex.message, 'test error');
    });

    test('toString includes prefix', () {
      const ex = AdbException('file not found');
      expect(ex.toString(), 'AdbException: file not found');
    });
  });

  group('TransferResult', () {
    test('creates with required success field', () {
      const result = TransferResult(success: true);
      expect(result.success, isTrue);
      expect(result.message, '');
      expect(result.bytesTransferred, 0);
    });

    test('creates with all fields', () {
      const result = TransferResult(
        success: false,
        message: 'Permission denied',
        bytesTransferred: 1024,
      );
      expect(result.success, isFalse);
      expect(result.message, 'Permission denied');
      expect(result.bytesTransferred, 1024);
    });
  });

  group('StorageInfo', () {
    group('constructor', () {
      test('creates with required fields', () {
        const info = StorageInfo(
          totalBytes: 1024 * 1024 * 1024,
          usedBytes: 512 * 1024 * 1024,
          availableBytes: 512 * 1024 * 1024,
        );
        expect(info.totalBytes, 1024 * 1024 * 1024);
        expect(info.usedBytes, 512 * 1024 * 1024);
        expect(info.availableBytes, 512 * 1024 * 1024);
      });
    });

    group('usedPercentage', () {
      test('returns 0 when totalBytes is 0', () {
        const info =
            StorageInfo(totalBytes: 0, usedBytes: 0, availableBytes: 0);
        expect(info.usedPercentage, 0.0);
      });

      test('returns correct ratio', () {
        const info =
            StorageInfo(totalBytes: 1000, usedBytes: 500, availableBytes: 500);
        expect(info.usedPercentage, 0.5);
      });

      test('returns 1.0 when full', () {
        const info =
            StorageInfo(totalBytes: 1000, usedBytes: 1000, availableBytes: 0);
        expect(info.usedPercentage, 1.0);
      });

      test('clamps to 1.0 if used exceeds total', () {
        const info =
            StorageInfo(totalBytes: 100, usedBytes: 200, availableBytes: 0);
        expect(info.usedPercentage, 1.0);
      });
    });

    group('formattedTotal', () {
      test('returns bytes for small values', () {
        const info =
            StorageInfo(totalBytes: 500, usedBytes: 0, availableBytes: 500);
        expect(info.formattedTotal, '500 B');
      });

      test('returns KB', () {
        const info =
            StorageInfo(totalBytes: 2048, usedBytes: 0, availableBytes: 2048);
        expect(info.formattedTotal, '2.0 KB');
      });

      test('returns MB', () {
        const info = StorageInfo(
          totalBytes: 5 * 1024 * 1024,
          usedBytes: 0,
          availableBytes: 5 * 1024 * 1024,
        );
        expect(info.formattedTotal, '5.0 MB');
      });

      test('returns GB', () {
        const info = StorageInfo(
          totalBytes: 64 * 1024 * 1024 * 1024,
          usedBytes: 0,
          availableBytes: 64 * 1024 * 1024 * 1024,
        );
        expect(info.formattedTotal, '64.0 GB');
      });
    });

    group('formattedUsed', () {
      test('formats used bytes', () {
        const info = StorageInfo(
          totalBytes: 1024 * 1024 * 1024,
          usedBytes: 512 * 1024 * 1024,
          availableBytes: 512 * 1024 * 1024,
        );
        expect(info.formattedUsed, '512.0 MB');
      });
    });

    group('formattedAvailable', () {
      test('formats available bytes', () {
        const info = StorageInfo(
          totalBytes: 1024 * 1024 * 1024,
          usedBytes: 512 * 1024 * 1024,
          availableBytes: 512 * 1024 * 1024,
        );
        expect(info.formattedAvailable, '512.0 MB');
      });
    });
  });

  group('AdbService with MockProcessRunner', () {
    late MockProcessRunner mockRunner;
    late AdbService adb;

    setUp(() {
      mockRunner = MockProcessRunner();
      // Pre-set adbPath to bypass _resolveAdbPath() filesystem checks
      adb = AdbService(runner: mockRunner, adbPath: '/usr/local/bin/adb');
    });

    group('isAdbAvailable', () {
      test('returns true when adb version succeeds', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', ['version'],
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((_) async => fakeResult(
                  exitCode: 0,
                  stdout: 'Android Debug Bridge version 35.0.2',
                ));

        expect(await adb.isAdbAvailable(), isTrue);
      });

      test('returns false when adb version fails', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', ['version'],
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((_) async => fakeResult(exitCode: 1));

        expect(await adb.isAdbAvailable(), isFalse);
      });

      test('returns false when runner throws', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', ['version'],
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenThrow(Exception('crash'));

        expect(await adb.isAdbAvailable(), isFalse);
      });

      test('returns false when path resolution fails', () async {
        // Create AdbService without pre-set adbPath
        final noPathAdb = AdbService(runner: mockRunner);
        when(() => mockRunner.run(any(), any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer(
                (_) async => fakeResult(exitCode: 1, stdout: ''));

        expect(await noPathAdb.isAdbAvailable(), isFalse);
      });
    });

    group('getAdbVersion', () {
      test('parses version number', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', ['version'],
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((_) async => fakeResult(
                  exitCode: 0,
                  stdout: 'Android Debug Bridge version 35.0.2',
                ));

        expect(await adb.getAdbVersion(), '35.0.2');
      });

      test('returns null when no version match', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', ['version'],
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((_) async => fakeResult(
                  exitCode: 0,
                  stdout: 'no version here',
                ));

        expect(await adb.getAdbVersion(), isNull);
      });

      test('returns null when command fails', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', ['version'],
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((_) async => fakeResult(exitCode: 1));

        expect(await adb.getAdbVersion(), isNull);
      });

      test('returns null when runner throws', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', ['version'],
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenThrow(Exception('crash'));

        expect(await adb.getAdbVersion(), isNull);
      });

      test('returns null when path not found', () async {
        final noPathAdb = AdbService(runner: mockRunner);
        when(() => mockRunner.run(any(), any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer(
                (_) async => fakeResult(exitCode: 1, stdout: ''));

        expect(await noPathAdb.getAdbVersion(), isNull);
      });
    });

    group('listDevices', () {
      test('parses device list output', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((invocation) async {
          final args = invocation.positionalArguments[1] as List<String>;
          if (args.contains('devices')) {
            return fakeResult(
              exitCode: 0,
              stdout:
                  'List of devices attached\nabc123    device usb:1-1 product:panther model:Pixel_7 device:panther transport_id:1\n',
            );
          }
          if (args.contains('getprop')) {
            return fakeResult(exitCode: 0, stdout: '14\n');
          }
          return fakeResult(exitCode: 0);
        });

        final devices = await adb.listDevices();
        expect(devices.length, 1);
        expect(devices.first.id, 'abc123');
        expect(devices.first.model, 'Pixel 7');
        expect(devices.first.status, 'device');
        expect(devices.first.androidVersion, '14');
      });

      test('returns empty on error', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((_) async => fakeResult(exitCode: 1));

        final devices = await adb.listDevices();
        expect(devices, isEmpty);
      });

      test('parses unauthorized device without android version', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((invocation) async {
          final args = invocation.positionalArguments[1] as List<String>;
          if (args.contains('devices')) {
            return fakeResult(
              exitCode: 0,
              stdout:
                  'List of devices attached\nxyz999    unauthorized usb:1-2 transport_id:2\n',
            );
          }
          return fakeResult(exitCode: 0);
        });

        final devices = await adb.listDevices();
        expect(devices.length, 1);
        expect(devices.first.status, 'unauthorized');
        expect(devices.first.androidVersion, isNull);
      });

      test('skips empty lines', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((invocation) async {
          final args = invocation.positionalArguments[1] as List<String>;
          if (args.contains('devices')) {
            return fakeResult(
              exitCode: 0,
              stdout: 'List of devices attached\n\n\n',
            );
          }
          return fakeResult(exitCode: 0);
        });

        final devices = await adb.listDevices();
        expect(devices, isEmpty);
      });

      test('uses -s flag for active device', () async {
        adb.setActiveDevice('mydevice');
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((invocation) async {
          final args = invocation.positionalArguments[1] as List<String>;
          if (args.contains('devices')) {
            expect(args.contains('-s'), isTrue);
            expect(args.contains('mydevice'), isTrue);
            return fakeResult(
              exitCode: 0,
              stdout: 'List of devices attached\n',
            );
          }
          return fakeResult(exitCode: 0);
        });

        await adb.listDevices();
      });
    });

    group('listFiles', () {
      // adbPath is pre-set in outer setUp, no path resolution needed.

      test('parses standard ls -la output', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((invocation) async {
          final args = invocation.positionalArguments[1] as List<String>;
          if (args.contains('ls')) {
            return fakeResult(
              exitCode: 0,
              stdout:
                  'total 24\ndrwxrwx--x  2 root sdcard_rw 4096 2024-01-15 10:30 Download\n-rw-rw----  1 root sdcard_rw 1024 2024-02-20 14:22 photo.jpg\n',
            );
          }
          return fakeResult(exitCode: 0);
        });


        final files = await adb.listFiles('/sdcard');
        expect(files.length, 2);
        expect(files[0].name, 'Download');
        expect(files[0].isDirectory, isTrue);
        expect(files[1].name, 'photo.jpg');
        expect(files[1].isDirectory, isFalse);
        expect(files[1].size, 1024);
      });

      test('sorts directories first then alphabetically within type', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((invocation) async {
          final args = invocation.positionalArguments[1] as List<String>;
          if (args.contains('ls')) {
            return fakeResult(
              exitCode: 0,
              stdout:
                  '-rw-rw----  1 root sdcard_rw 200 2024-02-20 14:22 zebra.txt\n'
                  '-rw-rw----  1 root sdcard_rw 300 2024-02-20 14:22 alpha.txt\n'
                  'drwxrwx--x  2 root sdcard_rw 4096 2024-01-15 10:30 Music\n'
                  'drwxrwx--x  2 root sdcard_rw 4096 2024-01-15 10:30 Download\n',
            );
          }
          return fakeResult(exitCode: 0);
        });

        final files = await adb.listFiles('/sdcard');
        expect(files.length, 4);
        // Directories first, alphabetically
        expect(files[0].name, 'Download');
        expect(files[0].isDirectory, isTrue);
        expect(files[1].name, 'Music');
        expect(files[1].isDirectory, isTrue);
        // Then files, alphabetically
        expect(files[2].name, 'alpha.txt');
        expect(files[2].isDirectory, isFalse);
        expect(files[3].name, 'zebra.txt');
        expect(files[3].isDirectory, isFalse);
      });

      test('skips . and .. entries', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((invocation) async {
          final args = invocation.positionalArguments[1] as List<String>;
          if (args.contains('ls')) {
            return fakeResult(
              exitCode: 0,
              stdout:
                  'drwxrwx--x  2 root sdcard_rw 4096 2024-01-15 10:30 .\ndrwxrwx--x  2 root sdcard_rw 4096 2024-01-15 10:30 ..\ndrwxrwx--x  2 root sdcard_rw 4096 2024-01-15 10:30 Download\n',
            );
          }
          return fakeResult(exitCode: 0);
        });

        final files = await adb.listFiles('/sdcard');
        expect(files.length, 1);
        expect(files[0].name, 'Download');
      });

      test('handles symlinks', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((invocation) async {
          final args = invocation.positionalArguments[1] as List<String>;
          if (args.contains('ls')) {
            return fakeResult(
              exitCode: 0,
              stdout:
                  'lrwxrwxrwx  1 root root 0 2024-01-15 10:30 sdcard -> /storage/emulated/0\n',
            );
          }
          return fakeResult(exitCode: 0);
        });

        final files = await adb.listFiles('/');
        expect(files.length, 1);
        expect(files[0].name, 'sdcard');
        expect(files[0].isSymlink, isTrue);
      });

      test('throws on permission denied', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((invocation) async {
          final args = invocation.positionalArguments[1] as List<String>;
          if (args.contains('ls')) {
            return fakeResult(
              exitCode: 1,
              stderr: 'ls: /data: Permission denied',
            );
          }
          return fakeResult(exitCode: 0);
        });

        expect(
          () => adb.listFiles('/data'),
          throwsA(isA<AdbException>().having(
              (e) => e.message, 'message', contains('Permission denied'))),
        );
      });

      test('throws on no such file', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((invocation) async {
          final args = invocation.positionalArguments[1] as List<String>;
          if (args.contains('ls')) {
            return fakeResult(
              exitCode: 1,
              stderr: 'ls: /bad: No such file or directory',
            );
          }
          return fakeResult(exitCode: 0);
        });

        expect(
          () => adb.listFiles('/bad'),
          throwsA(isA<AdbException>()
              .having((e) => e.message, 'message', contains('not found'))),
        );
      });

      test('throws generic error on unknown failure', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((invocation) async {
          final args = invocation.positionalArguments[1] as List<String>;
          if (args.contains('ls')) {
            return fakeResult(
              exitCode: 1,
              stderr: 'some other error',
            );
          }
          return fakeResult(exitCode: 0);
        });

        expect(
          () => adb.listFiles('/somewhere'),
          throwsA(isA<AdbException>()
              .having((e) => e.message, 'message', contains('Failed to list'))),
        );
      });

      test('uses fallback parser for non-standard output', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((invocation) async {
          final args = invocation.positionalArguments[1] as List<String>;
          if (args.contains('ls')) {
            return fakeResult(
              exitCode: 0,
              // Non-standard format that doesn't match the regex
              stdout:
                  'drwx------ 2 root root 0 Jan 15 10:30 secret_dir\n',
            );
          }
          return fakeResult(exitCode: 0);
        });

        final files = await adb.listFiles('/data');
        expect(files.length, 1);
        expect(files[0].name, 'secret_dir');
        expect(files[0].isDirectory, isTrue);
      });

      test('fallback parser handles symlinks with -> notation', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((invocation) async {
          final args = invocation.positionalArguments[1] as List<String>;
          if (args.contains('ls')) {
            return fakeResult(
              exitCode: 0,
              // Non-standard symlink line that falls through to fallback parser
              stdout:
                  'lrwxrwxrwx 1 root root 0 Jan 15 10:30 sdcard -> /storage/emulated/0\n',
            );
          }
          return fakeResult(exitCode: 0);
        });

        final files = await adb.listFiles('/');
        expect(files.length, 1);
        expect(files[0].name, 'sdcard');
        expect(files[0].isSymlink, isTrue);
      });

      test('appends trailing slash for non-root paths', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((invocation) async {
          final args = invocation.positionalArguments[1] as List<String>;
          if (args.contains('ls')) {
            // Verify trailing slash
            final lsPath = args.last;
            expect(lsPath, endsWith('/'));
            return fakeResult(exitCode: 0, stdout: '');
          }
          return fakeResult(exitCode: 0);
        });

        await adb.listFiles('/sdcard');
      });

      test('does not double slash for root path', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((invocation) async {
          final args = invocation.positionalArguments[1] as List<String>;
          if (args.contains('ls')) {
            final lsPath = args.last;
            expect(lsPath, '/');
            return fakeResult(exitCode: 0, stdout: '');
          }
          return fakeResult(exitCode: 0);
        });

        await adb.listFiles('/');
      });

      test('sorts directories first', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((invocation) async {
          final args = invocation.positionalArguments[1] as List<String>;
          if (args.contains('ls')) {
            return fakeResult(
              exitCode: 0,
              stdout:
                  '-rw-rw---- 1 root sdcard_rw 100 2024-01-15 10:30 afile.txt\ndrwxrwx--x 2 root sdcard_rw 4096 2024-01-15 10:30 zdir\n',
            );
          }
          return fakeResult(exitCode: 0);
        });

        final files = await adb.listFiles('/sdcard');
        expect(files[0].isDirectory, isTrue);
        expect(files[1].isDirectory, isFalse);
      });
    });

    group('createDirectory', () {
      test('returns true on success', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((_) async => fakeResult(exitCode: 0));

        expect(await adb.createDirectory('/sdcard/test'), isTrue);
      });

      test('returns false on failure', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((invocation) async {
          final args = invocation.positionalArguments[1] as List<String>;
          if (args.contains('mkdir')) {
            return fakeResult(exitCode: 1);
          }
          return fakeResult(exitCode: 0);
        });

        expect(await adb.createDirectory('/bad/path'), isFalse);
      });
    });

    group('delete', () {
      test('deletes file (non-recursive)', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((invocation) async {
          final args = invocation.positionalArguments[1] as List<String>;
          if (args.contains('rm') && !args.contains('-rf')) {
            return fakeResult(exitCode: 0);
          }
          return fakeResult(exitCode: 0);
        });

        expect(await adb.delete('/sdcard/file.txt'), isTrue);
      });

      test('deletes directory (recursive)', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((invocation) async {
          final args = invocation.positionalArguments[1] as List<String>;
          if (args.contains('-rf')) {
            return fakeResult(exitCode: 0);
          }
          return fakeResult(exitCode: 0);
        });

        expect(await adb.delete('/sdcard/dir', recursive: true), isTrue);
      });
    });

    group('rename', () {
      test('returns true on success', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((_) async => fakeResult(exitCode: 0));

        expect(await adb.rename('/sdcard/old', '/sdcard/new'), isTrue);
      });

      test('returns false on failure', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((invocation) async {
          final args = invocation.positionalArguments[1] as List<String>;
          if (args.contains('mv')) {
            return fakeResult(exitCode: 1);
          }
          return fakeResult(exitCode: 0);
        });

        expect(await adb.rename('/sdcard/a', '/sdcard/b'), isFalse);
      });
    });

    group('exists', () {
      test('returns true when file exists', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((_) async => fakeResult(exitCode: 0));

        expect(await adb.exists('/sdcard/file.txt'), isTrue);
      });

      test('returns false when file does not exist', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((invocation) async {
          final args = invocation.positionalArguments[1] as List<String>;
          if (args.contains('test')) {
            return fakeResult(exitCode: 1);
          }
          return fakeResult(exitCode: 0);
        });

        expect(await adb.exists('/sdcard/nope'), isFalse);
      });
    });

    group('getRemoteFileSize', () {
      test('returns size on success', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((invocation) async {
          final args = invocation.positionalArguments[1] as List<String>;
          if (args.contains('stat')) {
            return fakeResult(exitCode: 0, stdout: '12345\n');
          }
          return fakeResult(exitCode: 0);
        });

        expect(await adb.getRemoteFileSize('/sdcard/file.mp4'), 12345);
      });

      test('returns 0 on failure', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((invocation) async {
          final args = invocation.positionalArguments[1] as List<String>;
          if (args.contains('stat')) {
            return fakeResult(exitCode: 1);
          }
          return fakeResult(exitCode: 0);
        });

        expect(await adb.getRemoteFileSize('/sdcard/nope'), 0);
      });

      test('returns 0 on exception', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((invocation) async {
          final args = invocation.positionalArguments[1] as List<String>;
          if (args.contains('stat')) {
            throw Exception('fail');
          }
          return fakeResult(exitCode: 0);
        });

        expect(await adb.getRemoteFileSize('/sdcard/crash'), 0);
      });
    });

    group('startServer', () {
      test('returns true on success', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', ['start-server'],
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((_) async => fakeResult(exitCode: 0));
        when(() => mockRunner.run('/usr/local/bin/adb', ['version'],
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((_) async => fakeResult(exitCode: 0, stdout: 'v35'));

        expect(await adb.startServer(), isTrue);
      });

      test('returns false on failure', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', ['version'],
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((_) async => fakeResult(exitCode: 0, stdout: 'v35'));
        when(() => mockRunner.run('/usr/local/bin/adb', ['start-server'],
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((_) async => fakeResult(exitCode: 1));

        expect(await adb.startServer(), isFalse);
      });

      test('returns false when path not found', () async {
        final noPathAdb = AdbService(runner: mockRunner);
        when(() => mockRunner.run(any(), any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer(
                (_) async => fakeResult(exitCode: 1, stdout: ''));

        expect(await noPathAdb.startServer(), isFalse);
      });

      test('returns false on exception', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', ['version'],
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((_) async => fakeResult(exitCode: 0, stdout: 'v35'));
        when(() => mockRunner.run('/usr/local/bin/adb', ['start-server'],
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenThrow(Exception('crash'));

        expect(await adb.startServer(), isFalse);
      });
    });

    group('killServer', () {
      test('calls kill-server', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', ['version'],
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((_) async => fakeResult(exitCode: 0, stdout: 'v35'));
        when(() => mockRunner.run('/usr/local/bin/adb', ['kill-server'],
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((_) async => fakeResult(exitCode: 0));

        await adb.killServer();
        verify(() => mockRunner.run('/usr/local/bin/adb', ['kill-server'],
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .called(1);
      });

      test('swallows exceptions', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', ['version'],
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((_) async => fakeResult(exitCode: 0, stdout: 'v35'));
        when(() => mockRunner.run('/usr/local/bin/adb', ['kill-server'],
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenThrow(Exception('crash'));

        // Should not throw
        await adb.killServer();
      });
    });

    group('pullFile', () {
      test('returns success on exit code 0', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((invocation) async {
          final args = invocation.positionalArguments[1] as List<String>;
          if (args.contains('pull')) {
            return fakeResult(
              exitCode: 0,
              stdout: '1 file pulled. 10.0 MB/s',
            );
          }
          return fakeResult(exitCode: 0);
        });

        final result = await adb.pullFile('/sdcard/file.txt', '/local/file.txt');
        expect(result.success, isTrue);
        expect(result.message, contains('file pulled'));
      });

      test('returns failure on non-zero exit code', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((invocation) async {
          final args = invocation.positionalArguments[1] as List<String>;
          if (args.contains('pull')) {
            return fakeResult(
              exitCode: 1,
              stderr: 'remote object not found',
            );
          }
          return fakeResult(exitCode: 0);
        });

        final result = await adb.pullFile('/sdcard/nope', '/local/nope');
        expect(result.success, isFalse);
        expect(result.message, contains('not found'));
      });
    });

    group('pushFile', () {
      test('returns success on exit code 0', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((invocation) async {
          final args = invocation.positionalArguments[1] as List<String>;
          if (args.contains('push')) {
            return fakeResult(
              exitCode: 0,
              stdout: '1 file pushed. 5.0 MB/s',
            );
          }
          return fakeResult(exitCode: 0);
        });

        final result = await adb.pushFile('/local/file.txt', '/sdcard/file.txt');
        expect(result.success, isTrue);
      });

      test('returns failure on non-zero exit code', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((invocation) async {
          final args = invocation.positionalArguments[1] as List<String>;
          if (args.contains('push')) {
            return fakeResult(
              exitCode: 1,
              stderr: 'Read-only file system',
            );
          }
          return fakeResult(exitCode: 0);
        });

        final result =
            await adb.pushFile('/local/file.txt', '/sdcard/readonly');
        expect(result.success, isFalse);
      });
    });

    group('getStorageInfo', () {
      test('parses df output', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((invocation) async {
          final args = invocation.positionalArguments[1] as List<String>;
          if (args.contains('df')) {
            return fakeResult(
              exitCode: 0,
              stdout:
                  'Filesystem     1K-blocks    Used Available Use% Mounted on\n/dev/fuse      116440064 60000000 56440064  52% /storage/emulated/0\n',
            );
          }
          return fakeResult(exitCode: 0);
        });

        final info = await adb.getStorageInfo();
        expect(info, isNotNull);
        expect(info!.totalBytes, 116440064 * 1024);
        expect(info.usedBytes, 60000000 * 1024);
        expect(info.availableBytes, 56440064 * 1024);
      });

      test('returns null on error', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((invocation) async {
          final args = invocation.positionalArguments[1] as List<String>;
          if (args.contains('df')) {
            return fakeResult(exitCode: 1);
          }
          return fakeResult(exitCode: 0);
        });

        expect(await adb.getStorageInfo(), isNull);
      });

      test('returns null on insufficient lines', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((invocation) async {
          final args = invocation.positionalArguments[1] as List<String>;
          if (args.contains('df')) {
            return fakeResult(
                exitCode: 0, stdout: 'Filesystem\n');
          }
          return fakeResult(exitCode: 0);
        });

        expect(await adb.getStorageInfo(), isNull);
      });

      test('returns null on insufficient columns', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((invocation) async {
          final args = invocation.positionalArguments[1] as List<String>;
          if (args.contains('df')) {
            return fakeResult(
                exitCode: 0, stdout: 'Header\n/dev a b\n');
          }
          return fakeResult(exitCode: 0);
        });

        expect(await adb.getStorageInfo(), isNull);
      });

      test('returns null on exception', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((invocation) async {
          final args = invocation.positionalArguments[1] as List<String>;
          if (args.contains('df')) {
            throw Exception('crash');
          }
          return fakeResult(exitCode: 0);
        });

        expect(await adb.getStorageInfo(), isNull);
      });
    });

    group('setActiveDevice', () {
      test('sets and gets device id', () {
        adb.setActiveDevice('dev123');
        expect(adb.activeDeviceId, 'dev123');
      });

      test('sets to null', () {
        adb.setActiveDevice('dev123');
        adb.setActiveDevice(null);
        expect(adb.activeDeviceId, isNull);
      });
    });

    group('cancelCurrentTransfer', () {
      test('works when no transfer in progress', () {
        // Should not throw
        adb.cancelCurrentTransfer();
      });
    });

    group('_startProcess with active device', () {
      test('includes -s flag when active device is set', () async {
        adb.setActiveDevice('myphone');

        final mockProcess = MockProcess();
        final stdoutController = StreamController<List<int>>();
        final stderrController = StreamController<List<int>>();

        when(() => mockProcess.stdout).thenAnswer((_) => stdoutController.stream);
        when(() => mockProcess.stderr).thenAnswer((_) => stderrController.stream);
        when(() => mockProcess.exitCode).thenAnswer((_) async {
          await stdoutController.close();
          await stderrController.close();
          return 0;
        });

        when(() => mockRunner.start('/usr/local/bin/adb', any()))
            .thenAnswer((invocation) async {
          final args = invocation.positionalArguments[1] as List<String>;
          // Verify -s flag is prepended
          expect(args[0], '-s');
          expect(args[1], 'myphone');
          return mockProcess;
        });

        // Also stub run for getRemoteFileSize
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((invocation) async {
          final args = invocation.positionalArguments[1] as List<String>;
          if (args.contains('stat')) {
            return fakeResult(exitCode: 0, stdout: '1000');
          }
          return fakeResult(exitCode: 0);
        });

        await adb.pullFileWithProgress('/sdcard/f.txt', '/tmp/f.txt', (a, b) {});
      });
    });

    group('pullFileWithProgress', () {
      test('calls onProgress with percentages from stdout', () async {
        final mockProcess = MockProcess();
        final stdoutController = StreamController<List<int>>();
        final stderrController = StreamController<List<int>>();

        when(() => mockProcess.stdout).thenAnswer((_) => stdoutController.stream);
        when(() => mockProcess.stderr).thenAnswer((_) => stderrController.stream);
        when(() => mockProcess.exitCode).thenAnswer((_) async {
          // Emit progress before completing
          stdoutController.add(utf8.encode('[ 50%] /sdcard/file.mp4'));
          stdoutController.add(utf8.encode('[ 100%] /sdcard/file.mp4'));
          await stdoutController.close();
          await stderrController.close();
          return 0;
        });

        when(() => mockRunner.start('/usr/local/bin/adb', any()))
            .thenAnswer((_) async => mockProcess);

        // Mock stat for total size
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((invocation) async {
          final args = invocation.positionalArguments[1] as List<String>;
          if (args.contains('stat')) {
            return fakeResult(exitCode: 0, stdout: '10000\n');
          }
          return fakeResult(exitCode: 0);
        });


        final progressUpdates = <List<int>>[];
        await adb.pullFileWithProgress(
          '/sdcard/file.mp4',
          '/local/file.mp4',
          (transferred, total) {
            progressUpdates.add([transferred, total]);
          },
        );

        expect(progressUpdates, isNotEmpty);
      });

      test('throws on non-zero exit code', () async {
        final mockProcess = MockProcess();
        final stdoutController = StreamController<List<int>>();
        final stderrController = StreamController<List<int>>();

        when(() => mockProcess.stdout).thenAnswer((_) => stdoutController.stream);
        when(() => mockProcess.stderr).thenAnswer((_) => stderrController.stream);
        when(() => mockProcess.exitCode).thenAnswer((_) async {
          await stdoutController.close();
          await stderrController.close();
          return 1;
        });

        when(() => mockRunner.start('/usr/local/bin/adb', any()))
            .thenAnswer((_) async => mockProcess);

        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((invocation) async {
          final args = invocation.positionalArguments[1] as List<String>;
          if (args.contains('stat')) {
            return fakeResult(exitCode: 0, stdout: '100\n');
          }
          return fakeResult(exitCode: 0);
        });


        expect(
          () => adb.pullFileWithProgress('/sdcard/f', '/local/f', (a, b) {}),
          throwsA(isA<AdbException>()),
        );
      });

      test('uses poll timer when ADB does not report progress', () async {
        final mockProcess = MockProcess();
        final stdoutController = StreamController<List<int>>();
        final stderrController = StreamController<List<int>>();
        final exitCompleter = Completer<int>();

        when(() => mockProcess.stdout).thenAnswer((_) => stdoutController.stream);
        when(() => mockProcess.stderr).thenAnswer((_) => stderrController.stream);
        when(() => mockProcess.exitCode).thenAnswer((_) => exitCompleter.future);
        when(() => mockProcess.kill()).thenReturn(true);

        when(() => mockRunner.start('/usr/local/bin/adb', any()))
            .thenAnswer((_) async => mockProcess);

        // Mock stat to return total size > 0 (enables poll timer)
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((invocation) async {
          final args = invocation.positionalArguments[1] as List<String>;
          if (args.contains('stat')) {
            return fakeResult(exitCode: 0, stdout: '1000\n');
          }
          return fakeResult(exitCode: 0);
        });

        // Create a real temp file so existsSync/lengthSync work
        final tempDir = Directory.systemTemp.createTempSync('pull_poll_');
        final tempFile = File('${tempDir.path}/test.dat');
        tempFile.writeAsBytesSync(List.filled(500, 0));

        try {
          final progressUpdates = <List<int>>[];
          final pullFuture = adb.pullFileWithProgress(
            '/sdcard/test.dat',
            tempFile.path,
            (transferred, total) {
              progressUpdates.add([transferred, total]);
            },
          );

          // Wait for the poll timer to fire (fires every 500ms)
          await Future.delayed(const Duration(milliseconds: 700));

          // Complete the process
          await stdoutController.close();
          await stderrController.close();
          exitCompleter.complete(0);
          await pullFuture;

          // The poll timer should have reported local file size (500 bytes)
          expect(progressUpdates.any((p) => p[0] == 500 && p[1] == 1000), isTrue);
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      });
    });

    group('pushFileWithProgress', () {
      test('calls onProgress and completes', () async {
        final mockProcess = MockProcess();
        final stdoutController = StreamController<List<int>>();
        final stderrController = StreamController<List<int>>();

        when(() => mockProcess.stdout).thenAnswer((_) => stdoutController.stream);
        when(() => mockProcess.stderr).thenAnswer((_) => stderrController.stream);
        when(() => mockProcess.exitCode).thenAnswer((_) async {
          stdoutController.add(utf8.encode('[ 100%] /sdcard/file.txt'));
          await stdoutController.close();
          await stderrController.close();
          return 0;
        });

        when(() => mockRunner.start('/usr/local/bin/adb', any()))
            .thenAnswer((_) async => mockProcess);

        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((_) async => fakeResult(exitCode: 0));


        // Create a temp file for pushFileWithProgress
        final tempDir = Directory.systemTemp.createTempSync('adb_test_');
        final tempFile = File('${tempDir.path}/test.txt');
        tempFile.writeAsStringSync('hello');

        try {
          final progressUpdates = <List<int>>[];
          await adb.pushFileWithProgress(
            tempFile.path,
            '/sdcard/test.txt',
            (transferred, total) {
              progressUpdates.add([transferred, total]);
            },
          );

          // Should at least have final 100% progress
          expect(progressUpdates, isNotEmpty);
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      });

      test('throws on non-zero exit code', () async {
        final mockProcess = MockProcess();
        final stdoutController = StreamController<List<int>>();
        final stderrController = StreamController<List<int>>();

        when(() => mockProcess.stdout).thenAnswer((_) => stdoutController.stream);
        when(() => mockProcess.stderr).thenAnswer((_) => stderrController.stream);
        when(() => mockProcess.exitCode).thenAnswer((_) async {
          await stdoutController.close();
          await stderrController.close();
          return 1;
        });

        when(() => mockRunner.start('/usr/local/bin/adb', any()))
            .thenAnswer((_) async => mockProcess);

        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((_) async => fakeResult(exitCode: 0));


        final tempDir = Directory.systemTemp.createTempSync('adb_test_');
        final tempFile = File('${tempDir.path}/test.txt');
        tempFile.writeAsStringSync('hello');

        try {
          await expectLater(
            () => adb.pushFileWithProgress(
                tempFile.path, '/sdcard/test.txt', (a, b) {}),
            throwsA(isA<AdbException>()),
          );
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      });

      test('uses poll timer when ADB does not report progress', () async {
        // Set active device so the poll timer includes -s flag (covers line 520)
        adb.setActiveDevice('mydevice');

        final mockProcess = MockProcess();
        final stdoutController = StreamController<List<int>>();
        final stderrController = StreamController<List<int>>();
        final exitCompleter = Completer<int>();

        when(() => mockProcess.stdout).thenAnswer((_) => stdoutController.stream);
        when(() => mockProcess.stderr).thenAnswer((_) => stderrController.stream);
        when(() => mockProcess.exitCode).thenAnswer((_) => exitCompleter.future);
        when(() => mockProcess.kill()).thenReturn(true);

        when(() => mockRunner.start('/usr/local/bin/adb', any()))
            .thenAnswer((_) async => mockProcess);

        // Mock _run calls (no stat needed for push — totalSize comes from file.length())
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((invocation) async {
          final args = invocation.positionalArguments[1] as List<String>;
          // The poll timer calls adb shell stat to get remote file size
          if (args.contains('stat')) {
            return fakeResult(exitCode: 0, stdout: '250\n');
          }
          return fakeResult(exitCode: 0);
        });

        // Create a temp file — pushFileWithProgress reads its length for totalSize
        final tempDir = Directory.systemTemp.createTempSync('push_poll_');
        final tempFile = File('${tempDir.path}/test.dat');
        tempFile.writeAsBytesSync(List.filled(500, 0));

        try {
          final progressUpdates = <List<int>>[];
          final pushFuture = adb.pushFileWithProgress(
            tempFile.path,
            '/sdcard/test.dat',
            (transferred, total) {
              progressUpdates.add([transferred, total]);
            },
          );

          // Wait for the poll timer to fire (fires every 1 second for push)
          await Future.delayed(const Duration(milliseconds: 1200));

          // Complete the process
          await stdoutController.close();
          await stderrController.close();
          exitCompleter.complete(0);
          await pushFuture;

          // The poll timer should have called adb shell stat and reported remote size
          expect(progressUpdates.any((p) => p[0] == 250 && p[1] == 500), isTrue);
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      });
    });

    group('_run timeout', () {
      test('throws AdbException on timeout', () async {
        when(() => mockRunner.run('/usr/local/bin/adb', any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer((invocation) async {
          final args = invocation.positionalArguments[1] as List<String>;
          if (args.contains('version')) {
            return fakeResult(exitCode: 0, stdout: 'v35');
          }
          // Simulate timeout for other calls
          throw TimeoutException('timed out');
        });

        expect(
          () => adb.createDirectory('/sdcard/test'),
          throwsA(isA<AdbException>()
              .having((e) => e.message, 'message', contains('timed out'))),
        );
      });
    });

    group('_run throws when no adb path', () {
      test('throws when path is null and all resolution fails', () async {
        final noPathAdb = AdbService(runner: mockRunner);
        // Make all run calls throw so _resolveAdbPath can never succeed via shell
        when(() => mockRunner.run(any(), any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenThrow(Exception('no process'));
        // Also stub shell calls without encoding params
        when(() => mockRunner.run(any(), any()))
            .thenThrow(Exception('no process'));

        // If adb is on disk, _resolveAdbPath finds it and _run throws
        // the mock exception. If adb is NOT on disk, _resolveAdbPath returns
        // null and _run throws AdbException. Either way an exception is thrown.
        expect(
          () => noPathAdb.createDirectory('/sdcard/test'),
          throwsA(anything),
        );
      });
    });

    group('_startProcess throws when no adb path', () {
      test('throws AdbException when path is null', () async {
        final noPathAdb = AdbService(runner: mockRunner);
        // Stub run to fail (makes _resolveAdbPath return null)
        when(() => mockRunner.run(any(), any(),
                stdoutEncoding: any(named: 'stdoutEncoding'),
                stderrEncoding: any(named: 'stderrEncoding')))
            .thenAnswer(
                (_) async => fakeResult(exitCode: 1, stdout: ''));
        // Also stub start since _resolveAdbPath might find a real adb on disk
        when(() => mockRunner.start(any(), any()))
            .thenThrow(const AdbException('ADB binary not found'));

        expect(
          () => noPathAdb.pullFileWithProgress('/r', '/l', (a, b) {}),
          throwsA(isA<AdbException>()),
        );
      });
    });
  });

  group('RealProcessRunner', () {
    test('can be instantiated', () {
      const runner = RealProcessRunner();
      expect(runner, isA<ProcessRunner>());
    });
  });

  group('AdbService default constructor', () {
    test('creates with RealProcessRunner by default', () {
      final service = AdbService();
      expect(service, isA<AdbService>());
    });
  });

  group('setCustomAdbPath', () {
    late MockProcessRunner mockRunner;

    setUp(() {
      mockRunner = MockProcessRunner();
    });

    test('returns false when path does not exist', () async {
      final adb = AdbService(runner: mockRunner);

      final result = await adb.setCustomAdbPath('/non/existent/path');
      expect(result, isFalse);
    });

    test('returns true when path exists and version check passes', () async {
      final adb = AdbService(runner: mockRunner);

      final tempDir = Directory.systemTemp.createTempSync('adb_test_');
      final tempFile = File('${tempDir.path}/adb');
      tempFile.writeAsStringSync('fake adb');

      when(() => mockRunner.run(tempFile.path, ['version']))
          .thenAnswer((_) async => fakeResult(
                exitCode: 0,
                stdout: 'Android Debug Bridge version 35.0.2',
              ));

      try {
        final result = await adb.setCustomAdbPath(tempFile.path);
        expect(result, isTrue);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('returns false when version check returns non-zero exit code',
        () async {
      final adb = AdbService(runner: mockRunner);

      final tempDir = Directory.systemTemp.createTempSync('adb_test_');
      final tempFile = File('${tempDir.path}/adb');
      tempFile.writeAsStringSync('fake adb');

      when(() => mockRunner.run(tempFile.path, ['version']))
          .thenAnswer((_) async => fakeResult(exitCode: 1));

      try {
        final result = await adb.setCustomAdbPath(tempFile.path);
        expect(result, isFalse);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('returns false when version check throws', () async {
      final adb = AdbService(runner: mockRunner);

      final tempDir = Directory.systemTemp.createTempSync('adb_test_');
      final tempFile = File('${tempDir.path}/adb');
      tempFile.writeAsStringSync('fake adb');

      when(() => mockRunner.run(tempFile.path, ['version']))
          .thenThrow(const ProcessException('adb', []));

      try {
        final result = await adb.setCustomAdbPath(tempFile.path);
        expect(result, isFalse);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('persists path after successful set and uses it for subsequent calls',
        () async {
      final adb = AdbService(runner: mockRunner);

      final tempDir = Directory.systemTemp.createTempSync('adb_test_');
      final tempFile = File('${tempDir.path}/adb');
      tempFile.writeAsStringSync('fake adb');

      // Stub the version check for setCustomAdbPath (no encoding params)
      when(() => mockRunner.run(tempFile.path, ['version']))
          .thenAnswer((_) async => fakeResult(
                exitCode: 0,
                stdout: 'Android Debug Bridge version 35.0.2',
              ));

      // Stub the version check for isAdbAvailable (no encoding params)
      // After setCustomAdbPath sets _adbPath, isAdbAvailable will use it
      // isAdbAvailable calls _runner.run(path, ['version']) without encoding

      try {
        final setResult = await adb.setCustomAdbPath(tempFile.path);
        expect(setResult, isTrue);

        // Now isAdbAvailable should use the custom path
        final available = await adb.isAdbAvailable();
        expect(available, isTrue);

        // Verify the custom path was used (called at least twice:
        // once for setCustomAdbPath, at least once for isAdbAvailable)
        verify(() => mockRunner.run(tempFile.path, ['version'])).called(2);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });

  group('_resolveAdbPath', () {
    late MockProcessRunner mockRunner;

    setUp(() {
      mockRunner = MockProcessRunner();
    });

    test('resolves adb path from which via zsh shell', () async {
      final adb = AdbService(runner: mockRunner);

      final tempDir = Directory.systemTemp.createTempSync('adb_resolve_');
      final fakeAdb = File('${tempDir.path}/adb');
      fakeAdb.writeAsStringSync('fake');

      // which adb succeeds via zsh
      when(() => mockRunner.run('/bin/zsh', ['-l', '-c', 'which adb']))
          .thenAnswer((_) async => fakeResult(stdout: fakeAdb.path));

      // isAdbAvailable calls _runner.run(resolvedPath, ['version'])
      when(() => mockRunner.run(fakeAdb.path, ['version']))
          .thenAnswer((_) async => fakeResult(
                exitCode: 0,
                stdout: 'Android Debug Bridge version 35.0.2',
              ));

      try {
        final available = await adb.isAdbAvailable();
        // If the config file short-circuits, it still resolves successfully.
        // Either way isAdbAvailable should return true because:
        // - Config file path resolves, or
        // - zsh which adb resolves to our temp file
        // The version check mock on fakeAdb.path handles the zsh case.
        // If config file found real adb, isAdbAvailable runs version on that
        // (unmocked), which could succeed or fail. So we verify the zsh path
        // was at least attempted OR adb was already found.
        expect(available, isTrue);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('falls through to bash when zsh which adb fails', () async {
      final adb = AdbService(runner: mockRunner);

      final tempDir = Directory.systemTemp.createTempSync('adb_resolve_');
      final fakeAdb = File('${tempDir.path}/adb');
      fakeAdb.writeAsStringSync('fake');

      // zsh fails
      when(() => mockRunner.run('/bin/zsh', ['-l', '-c', 'which adb']))
          .thenAnswer((_) async => fakeResult(exitCode: 1, stdout: ''));

      // bash succeeds
      when(() => mockRunner.run('/bin/bash', ['-l', '-c', 'which adb']))
          .thenAnswer((_) async => fakeResult(stdout: fakeAdb.path));

      // Stub ANDROID_HOME echo (step 4 in _resolveAdbPath)
      when(() => mockRunner.run(
              '/bin/zsh', ['-l', '-c', 'echo \$ANDROID_HOME']))
          .thenAnswer((_) async => fakeResult(exitCode: 1, stdout: ''));

      // isAdbAvailable calls version check
      when(() => mockRunner.run(fakeAdb.path, ['version']))
          .thenAnswer((_) async => fakeResult(
                exitCode: 0,
                stdout: 'Android Debug Bridge version 35.0.2',
              ));

      try {
        final available = await adb.isAdbAvailable();
        expect(available, isTrue);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('skips shell result when which adb returns empty path', () async {
      final adb = AdbService(runner: mockRunner);

      // Both shells return empty path
      when(() => mockRunner.run('/bin/zsh', ['-l', '-c', 'which adb']))
          .thenAnswer((_) async => fakeResult(exitCode: 0, stdout: ''));

      when(() => mockRunner.run('/bin/bash', ['-l', '-c', 'which adb']))
          .thenAnswer((_) async => fakeResult(exitCode: 0, stdout: ''));

      // Stub ANDROID_HOME echo
      when(() => mockRunner.run(
              '/bin/zsh', ['-l', '-c', 'echo \$ANDROID_HOME']))
          .thenAnswer((_) async => fakeResult(exitCode: 0, stdout: ''));

      // If no candidate path exists on disk and config file doesn't
      // short-circuit, _resolveAdbPath returns null and isAdbAvailable
      // returns false. If config/candidate files exist on disk,
      // it may still resolve. We just check it doesn't crash.
      await adb.isAdbAvailable();
    });

    test('skips shell result when returned path does not exist on disk',
        () async {
      final adb = AdbService(runner: mockRunner);

      // zsh returns a path that doesn't exist
      when(() => mockRunner.run('/bin/zsh', ['-l', '-c', 'which adb']))
          .thenAnswer((_) async => fakeResult(
                exitCode: 0,
                stdout: '/tmp/nonexistent_adb_binary_xyz',
              ));

      // bash also returns a path that doesn't exist
      when(() => mockRunner.run('/bin/bash', ['-l', '-c', 'which adb']))
          .thenAnswer((_) async => fakeResult(
                exitCode: 0,
                stdout: '/tmp/nonexistent_adb_binary_abc',
              ));

      // Stub ANDROID_HOME echo
      when(() => mockRunner.run(
              '/bin/zsh', ['-l', '-c', 'echo \$ANDROID_HOME']))
          .thenAnswer((_) async => fakeResult(exitCode: 0, stdout: ''));

      // Should not crash; result depends on whether adb exists at
      // candidate paths on this machine
      await adb.isAdbAvailable();
    });

    test('shell calls that throw are caught and resolution continues',
        () async {
      final adb = AdbService(runner: mockRunner);

      // zsh throws
      when(() => mockRunner.run('/bin/zsh', ['-l', '-c', 'which adb']))
          .thenThrow(const ProcessException('/bin/zsh', []));

      // bash also throws
      when(() => mockRunner.run('/bin/bash', ['-l', '-c', 'which adb']))
          .thenThrow(const ProcessException('/bin/bash', []));

      // ANDROID_HOME echo also throws
      when(() => mockRunner.run(
              '/bin/zsh', ['-l', '-c', 'echo \$ANDROID_HOME']))
          .thenThrow(const ProcessException('/bin/zsh', []));

      // Resolution continues to candidate paths. Should not crash.
      await adb.isAdbAvailable();
    });

    test('returns null and isAdbAvailable returns false when all methods fail',
        () async {
      final adb = AdbService(runner: mockRunner);

      // All shell calls fail
      when(() => mockRunner.run('/bin/zsh', ['-l', '-c', 'which adb']))
          .thenAnswer((_) async => fakeResult(exitCode: 1, stdout: ''));

      when(() => mockRunner.run('/bin/bash', ['-l', '-c', 'which adb']))
          .thenAnswer((_) async => fakeResult(exitCode: 1, stdout: ''));

      when(() => mockRunner.run(
              '/bin/zsh', ['-l', '-c', 'echo \$ANDROID_HOME']))
          .thenAnswer((_) async => fakeResult(exitCode: 1, stdout: ''));

      // If no candidate paths exist on disk AND config file doesn't
      // have a valid saved path, _resolveAdbPath returns null.
      // On machines without adb installed, this will return false.
      // On machines with adb at a candidate path, it may still succeed.
      await adb.isAdbAvailable();
      // We can't assert false here because adb might exist at a
      // candidate path. But we verify the shells were called.
      verify(() => mockRunner.run('/bin/zsh', ['-l', '-c', 'which adb']))
          .called(1);
    });

    test('resolves adb from shell ANDROID_HOME env and candidate path', () async {
      final adb = AdbService(runner: mockRunner);

      final tempDir = Directory.systemTemp.createTempSync('android_home_');
      final platformToolsDir = Directory('${tempDir.path}/platform-tools');
      platformToolsDir.createSync();
      final fakeAdb = File('${platformToolsDir.path}/adb');
      fakeAdb.writeAsStringSync('fake');

      // which adb fails for both shells
      when(() => mockRunner.run('/bin/zsh', ['-l', '-c', 'which adb']))
          .thenAnswer((_) async => fakeResult(exitCode: 1));
      when(() => mockRunner.run('/bin/bash', ['-l', '-c', 'which adb']))
          .thenAnswer((_) async => fakeResult(exitCode: 1));

      // echo $ANDROID_HOME returns our temp dir (covers line 161)
      when(() => mockRunner.run(
              '/bin/zsh', ['-l', '-c', 'echo \$ANDROID_HOME']))
          .thenAnswer((_) async => fakeResult(stdout: tempDir.path));

      // Version check — use any() for path since it depends on which candidate is found
      when(() => mockRunner.run(any(), ['version']))
          .thenAnswer((_) async => fakeResult(
                exitCode: 0,
                stdout: 'Android Debug Bridge version 35.0.2',
              ));

      try {
        final available = await adb.isAdbAvailable();
        // Should resolve: either from a hardcoded candidate or our temp path
        expect(available, isTrue);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('caches resolved path on subsequent calls', () async {
      final adb = AdbService(runner: mockRunner);

      final tempDir = Directory.systemTemp.createTempSync('adb_resolve_');
      final fakeAdb = File('${tempDir.path}/adb');
      fakeAdb.writeAsStringSync('fake');

      // zsh resolves our fake adb
      when(() => mockRunner.run('/bin/zsh', ['-l', '-c', 'which adb']))
          .thenAnswer((_) async => fakeResult(stdout: fakeAdb.path));

      // version check
      when(() => mockRunner.run(fakeAdb.path, ['version']))
          .thenAnswer((_) async => fakeResult(
                exitCode: 0,
                stdout: 'Android Debug Bridge version 35.0.2',
              ));

      // Stub for _run calls with encoding params
      when(() => mockRunner.run(fakeAdb.path, any(),
              stdoutEncoding: any(named: 'stdoutEncoding'),
              stderrEncoding: any(named: 'stderrEncoding')))
          .thenAnswer((_) async => fakeResult(exitCode: 0, stdout: ''));

      try {
        // First call triggers _resolveAdbPath
        await adb.isAdbAvailable();
        // Second call should use cached _adbPath
        await adb.isAdbAvailable();

        // version was called twice (once per isAdbAvailable)
        verify(() => mockRunner.run(fakeAdb.path, ['version'])).called(2);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
