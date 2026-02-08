import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:filedroid/providers/transfer_provider.dart';
import 'package:filedroid/services/adb_service.dart';
import 'package:filedroid/models/transfer_task.dart';

class MockAdbService extends Mock implements AdbService {}

void main() {
  late MockAdbService mockAdb;
  late TransferProvider provider;

  setUp(() {
    mockAdb = MockAdbService();
    provider = TransferProvider(mockAdb);
  });

  group('TransferProvider', () {
    group('initial state', () {
      test('tasks is empty', () {
        expect(provider.tasks, isEmpty);
      });

      test('isTransferring is false', () {
        expect(provider.isTransferring, isFalse);
      });

      test('activeTasks is empty', () {
        expect(provider.activeTasks, isEmpty);
      });

      test('queuedTasks is empty', () {
        expect(provider.queuedTasks, isEmpty);
      });

      test('completedTasks is empty', () {
        expect(provider.completedTasks, isEmpty);
      });

      test('failedTasks is empty', () {
        expect(provider.failedTasks, isEmpty);
      });

      test('totalActive is 0', () {
        expect(provider.totalActive, 0);
      });

      test('overallSpeed is empty', () {
        expect(provider.overallSpeed, '');
      });
    });

    group('pullFiles', () {
      test('creates tasks with correct properties', () async {
        when(() => mockAdb.getRemoteFileSize(any())).thenAnswer((_) async => 1024);
        when(() => mockAdb.pullFileWithProgress(any(), any(), any()))
            .thenAnswer((invocation) async {
          // Simulate instant completion
          final callback = invocation.positionalArguments[2]
              as void Function(int, int);
          callback(1024, 1024);
        });

        await provider.pullFiles(['/sdcard/photo.jpg'], '/local/downloads');

        expect(provider.tasks.length, 1);
        final task = provider.tasks.first;
        expect(task.fileName, 'photo.jpg');
        expect(task.sourcePath, '/sdcard/photo.jpg');
        expect(task.destPath, '/local/downloads/photo.jpg');
        expect(task.direction, TransferDirection.toMac);
      });

      test('creates multiple tasks for multiple files', () async {
        when(() => mockAdb.getRemoteFileSize(any())).thenAnswer((_) async => 0);
        when(() => mockAdb.pullFileWithProgress(any(), any(), any()))
            .thenAnswer((_) async {});

        await provider.pullFiles(
          ['/sdcard/a.jpg', '/sdcard/b.mp4'],
          '/local',
        );

        expect(provider.tasks.length, 2);
        expect(provider.tasks[0].fileName, 'b.mp4'); // inserted at 0
        expect(provider.tasks[1].fileName, 'a.jpg');
      });

      test('fetches remote file size', () async {
        when(() => mockAdb.getRemoteFileSize('/sdcard/big.mp4'))
            .thenAnswer((_) async => 50000);
        when(() => mockAdb.pullFileWithProgress(any(), any(), any()))
            .thenAnswer((_) async {});

        await provider.pullFiles(['/sdcard/big.mp4'], '/local');

        verify(() => mockAdb.getRemoteFileSize('/sdcard/big.mp4')).called(1);
      });

      test('handles getRemoteFileSize failure gracefully', () async {
        when(() => mockAdb.getRemoteFileSize(any())).thenThrow(Exception('fail'));
        when(() => mockAdb.pullFileWithProgress(any(), any(), any()))
            .thenAnswer((_) async {});

        await provider.pullFiles(['/sdcard/a.txt'], '/local');

        expect(provider.tasks.length, 1);
      });

      test('task becomes completed on success', () async {
        when(() => mockAdb.getRemoteFileSize(any())).thenAnswer((_) async => 100);
        when(() => mockAdb.pullFileWithProgress(any(), any(), any()))
            .thenAnswer((_) async {});

        await provider.pullFiles(['/sdcard/file.txt'], '/local');

        // Wait for queue processing to finish
        await Future.delayed(Duration.zero);

        expect(provider.completedTasks.length, 1);
        expect(provider.completedTasks.first.status, TransferStatus.completed);
      });

      test('task becomes failed on error', () async {
        when(() => mockAdb.getRemoteFileSize(any())).thenAnswer((_) async => 0);
        when(() => mockAdb.pullFileWithProgress(any(), any(), any()))
            .thenThrow(const AdbException('Pull failed'));

        await provider.pullFiles(['/sdcard/file.txt'], '/local');

        await Future.delayed(Duration.zero);

        expect(provider.failedTasks.length, 1);
        expect(provider.failedTasks.first.errorMessage, contains('Pull failed'));
      });

      test('calls onTransferComplete callback', () async {
        bool callbackCalled = false;
        provider.onTransferComplete = () => callbackCalled = true;

        when(() => mockAdb.getRemoteFileSize(any())).thenAnswer((_) async => 0);
        when(() => mockAdb.pullFileWithProgress(any(), any(), any()))
            .thenAnswer((_) async {});

        await provider.pullFiles(['/sdcard/f.txt'], '/local');

        await Future.delayed(Duration.zero);

        expect(callbackCalled, isTrue);
      });
    });

    group('pushFiles', () {
      late Directory tempDir;

      setUp(() {
        tempDir = Directory.systemTemp.createTempSync('transfer_test_');
      });

      tearDown(() {
        tempDir.deleteSync(recursive: true);
      });

      test('creates tasks with correct properties', () async {
        final tempFile = File('${tempDir.path}/test.txt');
        tempFile.writeAsStringSync('hello world');

        when(() => mockAdb.pushFileWithProgress(any(), any(), any()))
            .thenAnswer((_) async {});

        await provider.pushFiles([tempFile.path], '/sdcard/Download');

        expect(provider.tasks.length, 1);
        final task = provider.tasks.first;
        expect(task.fileName, 'test.txt');
        expect(task.sourcePath, tempFile.path);
        expect(task.destPath, '/sdcard/Download/test.txt');
        expect(task.direction, TransferDirection.toAndroid);
        expect(task.totalBytes, 11); // 'hello world' = 11 bytes
      });

      test('handles nonexistent file (size 0)', () async {
        when(() => mockAdb.pushFileWithProgress(any(), any(), any()))
            .thenAnswer((_) async {});

        await provider.pushFiles(['${tempDir.path}/nonexistent.txt'], '/sdcard');

        expect(provider.tasks.length, 1);
        expect(provider.tasks.first.totalBytes, 0);
      });

      test('pushes via pushFileWithProgress', () async {
        final tempFile = File('${tempDir.path}/data.bin');
        tempFile.writeAsBytesSync(List.filled(100, 0));

        when(() => mockAdb.pushFileWithProgress(any(), any(), any()))
            .thenAnswer((invocation) async {
          final callback = invocation.positionalArguments[2]
              as void Function(int, int);
          callback(50, 100);
          callback(100, 100);
        });

        await provider.pushFiles([tempFile.path], '/sdcard');
        await Future.delayed(Duration.zero);

        expect(provider.completedTasks.length, 1);
      });
    });

    group('task filtering', () {
      test('activeTasks returns inProgress tasks', () async {
        when(() => mockAdb.getRemoteFileSize(any())).thenAnswer((_) async => 0);
        // Never complete - simulate a long-running transfer
        final completer = Future<void>.delayed(const Duration(hours: 1));
        when(() => mockAdb.pullFileWithProgress(any(), any(), any()))
            .thenAnswer((_) => completer);

        // Start pull but don't await queue completion
        provider.pullFiles(['/sdcard/f.txt'], '/local');
        await Future.delayed(const Duration(milliseconds: 50));

        // The task should be inProgress by now
        expect(provider.activeTasks.length + provider.queuedTasks.length, greaterThanOrEqualTo(1));
      });
    });

    group('cancelTask', () {
      test('cancels queued task', () async {
        when(() => mockAdb.getRemoteFileSize(any())).thenAnswer((_) async => 0);
        // First task blocks, second stays queued
        final completer = Future<void>.delayed(const Duration(hours: 1));
        when(() => mockAdb.pullFileWithProgress(any(), any(), any()))
            .thenAnswer((_) => completer);

        provider.pullFiles(['/sdcard/a.txt', '/sdcard/b.txt'], '/local');
        await Future.delayed(const Duration(milliseconds: 50));

        // Find a queued task
        final queuedTask = provider.tasks.firstWhere(
          (t) => t.status == TransferStatus.queued,
          orElse: () => provider.tasks.last,
        );
        provider.cancelTask(queuedTask.id);

        expect(queuedTask.status, TransferStatus.cancelled);
        expect(queuedTask.completedAt, isNotNull);
      });

      test('cancels inProgress task and calls adb cancel', () async {
        when(() => mockAdb.getRemoteFileSize(any())).thenAnswer((_) async => 0);
        when(() => mockAdb.cancelCurrentTransfer()).thenReturn(null);
        final completer = Future<void>.delayed(const Duration(hours: 1));
        when(() => mockAdb.pullFileWithProgress(any(), any(), any()))
            .thenAnswer((_) => completer);

        provider.pullFiles(['/sdcard/a.txt'], '/local');
        await Future.delayed(const Duration(milliseconds: 50));

        final task = provider.tasks.first;
        if (task.status == TransferStatus.inProgress) {
          provider.cancelTask(task.id);
          expect(task.status, TransferStatus.cancelled);
          verify(() => mockAdb.cancelCurrentTransfer()).called(1);
        }
      });

      test('does nothing for nonexistent task', () {
        provider.cancelTask('nonexistent');
        // No error thrown
      });
    });

    group('retryTask', () {
      test('resets failed task to queued', () async {
        when(() => mockAdb.getRemoteFileSize(any())).thenAnswer((_) async => 0);

        // First call fails, retry succeeds
        int callCount = 0;
        when(() => mockAdb.pullFileWithProgress(any(), any(), any()))
            .thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            throw const AdbException('fail');
          }
        });

        await provider.pullFiles(['/sdcard/f.txt'], '/local');
        await Future.delayed(Duration.zero);

        expect(provider.failedTasks.length, 1);
        final task = provider.failedTasks.first;

        provider.retryTask(task.id);

        // Task should be queued or processing
        expect(task.transferredBytes, 0);
        expect(task.errorMessage, isNull);
        expect(task.completedAt, isNull);
      });

      test('does nothing for nonexistent task id', () {
        provider.retryTask('nonexistent_id');
        // Should not throw, no tasks affected
        expect(provider.tasks, isEmpty);
      });

      test('does nothing for active task', () async {
        when(() => mockAdb.getRemoteFileSize(any())).thenAnswer((_) async => 0);
        when(() => mockAdb.pullFileWithProgress(any(), any(), any()))
            .thenAnswer((_) => Future.delayed(const Duration(hours: 1)));

        provider.pullFiles(['/sdcard/f.txt'], '/local');
        await Future.delayed(const Duration(milliseconds: 50));

        final task = provider.tasks.first;
        if (task.status == TransferStatus.inProgress) {
          provider.retryTask(task.id);
          // Should still be inProgress, not reset
          expect(task.status, TransferStatus.inProgress);
        }
      });
    });

    group('clearFinished', () {
      test('removes completed, failed, and cancelled tasks', () async {
        when(() => mockAdb.getRemoteFileSize(any())).thenAnswer((_) async => 0);

        // Create a completed task
        when(() => mockAdb.pullFileWithProgress(any(), any(), any()))
            .thenAnswer((_) async {});

        await provider.pullFiles(['/sdcard/a.txt'], '/local');
        await Future.delayed(Duration.zero);

        expect(provider.tasks.length, 1);
        expect(provider.completedTasks.length, 1);

        provider.clearFinished();

        expect(provider.tasks, isEmpty);
      });

      test('keeps active tasks', () async {
        when(() => mockAdb.getRemoteFileSize(any())).thenAnswer((_) async => 0);

        // First task completes, second stays active
        int callCount = 0;
        when(() => mockAdb.pullFileWithProgress(any(), any(), any()))
            .thenAnswer((_) async {
          callCount++;
          if (callCount == 2) {
            await Future.delayed(const Duration(hours: 1));
          }
        });

        await provider.pullFiles(['/sdcard/a.txt'], '/local');
        await Future.delayed(Duration.zero);

        // First should be completed
        expect(provider.completedTasks.isNotEmpty, isTrue);

        provider.clearFinished();

        // Only finished tasks removed
        expect(provider.completedTasks, isEmpty);
      });
    });

    group('overallSpeed', () {
      test('returns empty when no active tasks', () {
        expect(provider.overallSpeed, '');
      });

      test('returns B/s when elapsed is under 1 second', () async {
        when(() => mockAdb.getRemoteFileSize(any())).thenAnswer((_) async => 0);
        when(() => mockAdb.pullFileWithProgress(any(), any(), any()))
            .thenAnswer((_) => Future.delayed(const Duration(hours: 1)));

        provider.pullFiles(['/sdcard/f.txt'], '/local');
        await Future.delayed(const Duration(milliseconds: 50));

        // Task is inProgress but elapsed < 1s, so totalBps = 0 → '0 B/s'
        expect(provider.overallSpeed, '0 B/s');
      });

      test('returns KB/s for medium active transfer', () async {
        when(() => mockAdb.getRemoteFileSize(any())).thenAnswer((_) async => 0);
        when(() => mockAdb.pullFileWithProgress(any(), any(), any()))
            .thenAnswer((_) => Future.delayed(const Duration(hours: 1)));

        provider.pullFiles(['/sdcard/f.txt'], '/local');
        await Future.delayed(const Duration(milliseconds: 1100));

        final task = provider.tasks.firstWhere(
          (t) => t.status == TransferStatus.inProgress,
        );
        task.transferredBytes = 5120; // 5KB in ~1s = ~5 KB/s

        final speed = provider.overallSpeed;
        expect(speed, contains('KB/s'));
      });

      test('returns MB/s for fast active transfer', () async {
        when(() => mockAdb.getRemoteFileSize(any())).thenAnswer((_) async => 0);
        when(() => mockAdb.pullFileWithProgress(any(), any(), any()))
            .thenAnswer((_) => Future.delayed(const Duration(hours: 1)));

        provider.pullFiles(['/sdcard/f.txt'], '/local');
        await Future.delayed(const Duration(milliseconds: 1100));

        final task = provider.tasks.firstWhere(
          (t) => t.status == TransferStatus.inProgress,
        );
        task.transferredBytes = 10 * 1024 * 1024; // 10MB in ~1s

        final speed = provider.overallSpeed;
        expect(speed, contains('MB/s'));
      });
    });

    group('totalActive', () {
      test('counts active and queued tasks', () async {
        when(() => mockAdb.getRemoteFileSize(any())).thenAnswer((_) async => 0);
        when(() => mockAdb.pullFileWithProgress(any(), any(), any()))
            .thenAnswer((_) => Future.delayed(const Duration(hours: 1)));

        provider.pullFiles(['/sdcard/a.txt', '/sdcard/b.txt'], '/local');
        await Future.delayed(const Duration(milliseconds: 50));

        expect(provider.totalActive, greaterThanOrEqualTo(1));
      });
    });
  });
}
