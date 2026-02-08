import 'package:flutter_test/flutter_test.dart';
import 'package:filedroid/models/transfer_task.dart';

void main() {
  group('TransferTask', () {
    TransferTask createTask({
      TransferStatus status = TransferStatus.queued,
      int totalBytes = 0,
      int transferredBytes = 0,
      DateTime? startedAt,
    }) {
      return TransferTask(
        id: 'task_1',
        sourcePath: '/remote/file.mp4',
        destPath: '/local/file.mp4',
        fileName: 'file.mp4',
        direction: TransferDirection.toMac,
        status: status,
        totalBytes: totalBytes,
        transferredBytes: transferredBytes,
        startedAt: startedAt,
      );
    }

    group('constructor', () {
      test('creates with required fields and defaults', () {
        final task = createTask();
        expect(task.id, 'task_1');
        expect(task.sourcePath, '/remote/file.mp4');
        expect(task.destPath, '/local/file.mp4');
        expect(task.fileName, 'file.mp4');
        expect(task.direction, TransferDirection.toMac);
        expect(task.status, TransferStatus.queued);
        expect(task.totalBytes, 0);
        expect(task.transferredBytes, 0);
        expect(task.errorMessage, isNull);
        expect(task.completedAt, isNull);
        expect(task.startedAt, isNotNull);
      });

      test('uses custom startedAt when provided', () {
        final custom = DateTime(2025, 1, 1);
        final task = createTask(startedAt: custom);
        expect(task.startedAt, custom);
      });

      test('generates startedAt when not provided', () {
        final before = DateTime.now();
        final task = createTask();
        final after = DateTime.now();
        expect(task.startedAt.isAfter(before) || task.startedAt.isAtSameMomentAs(before), isTrue);
        expect(task.startedAt.isBefore(after) || task.startedAt.isAtSameMomentAs(after), isTrue);
      });
    });

    group('progress', () {
      test('returns 0 when totalBytes is 0', () {
        final task = createTask(totalBytes: 0, transferredBytes: 100);
        expect(task.progress, 0.0);
      });

      test('returns 0 when totalBytes is negative', () {
        final task = createTask(totalBytes: -1, transferredBytes: 100);
        expect(task.progress, 0.0);
      });

      test('returns correct ratio', () {
        final task = createTask(totalBytes: 1000, transferredBytes: 500);
        expect(task.progress, 0.5);
      });

      test('returns 1.0 when complete', () {
        final task = createTask(totalBytes: 1000, transferredBytes: 1000);
        expect(task.progress, 1.0);
      });

      test('clamps to 1.0 when transferred exceeds total', () {
        final task = createTask(totalBytes: 100, transferredBytes: 200);
        expect(task.progress, 1.0);
      });
    });

    group('formattedSpeed', () {
      test('returns empty when not inProgress', () {
        final task = createTask(status: TransferStatus.queued);
        expect(task.formattedSpeed, '');
      });

      test('returns empty when elapsed is 0 seconds', () {
        final task = createTask(
          status: TransferStatus.inProgress,
          transferredBytes: 1024,
          startedAt: DateTime.now(),
        );
        expect(task.formattedSpeed, '');
      });

      test('returns B/s for slow transfers', () {
        final task = createTask(
          status: TransferStatus.inProgress,
          transferredBytes: 500,
          startedAt: DateTime.now().subtract(const Duration(seconds: 5)),
        );
        expect(task.formattedSpeed, '100 B/s');
      });

      test('returns KB/s for medium transfers', () {
        final task = createTask(
          status: TransferStatus.inProgress,
          transferredBytes: 10240,
          startedAt: DateTime.now().subtract(const Duration(seconds: 2)),
        );
        expect(task.formattedSpeed, '5.0 KB/s');
      });

      test('returns MB/s for fast transfers', () {
        final task = createTask(
          status: TransferStatus.inProgress,
          transferredBytes: 10 * 1024 * 1024,
          startedAt: DateTime.now().subtract(const Duration(seconds: 1)),
        );
        expect(task.formattedSpeed, '10.0 MB/s');
      });

      test('returns empty for completed status', () {
        final task = createTask(status: TransferStatus.completed);
        expect(task.formattedSpeed, '');
      });

      test('returns empty for failed status', () {
        final task = createTask(status: TransferStatus.failed);
        expect(task.formattedSpeed, '');
      });

      test('returns empty for cancelled status', () {
        final task = createTask(status: TransferStatus.cancelled);
        expect(task.formattedSpeed, '');
      });
    });

    group('formattedTotal', () {
      test('returns empty when totalBytes is 0', () {
        final task = createTask(totalBytes: 0);
        expect(task.formattedTotal, '');
      });

      test('returns empty when totalBytes is negative', () {
        final task = createTask(totalBytes: -1);
        expect(task.formattedTotal, '');
      });

      test('returns bytes for small files', () {
        final task = createTask(totalBytes: 500);
        expect(task.formattedTotal, '500 B');
      });

      test('returns KB for kilobyte range', () {
        final task = createTask(totalBytes: 2048);
        expect(task.formattedTotal, '2 KB');
      });

      test('returns MB with decimal for small MB', () {
        final task = createTask(totalBytes: 5 * 1024 * 1024);
        expect(task.formattedTotal, '5.0 MB');
      });

      test('returns MB without decimal for large MB', () {
        final task = createTask(totalBytes: 50 * 1024 * 1024);
        expect(task.formattedTotal, '50 MB');
      });

      test('returns GB for gigabyte range', () {
        final task = createTask(totalBytes: 2 * 1024 * 1024 * 1024);
        expect(task.formattedTotal, '2.0 GB');
      });
    });

    group('isActive', () {
      test('true for queued', () {
        expect(createTask(status: TransferStatus.queued).isActive, isTrue);
      });

      test('true for inProgress', () {
        expect(createTask(status: TransferStatus.inProgress).isActive, isTrue);
      });

      test('false for completed', () {
        expect(createTask(status: TransferStatus.completed).isActive, isFalse);
      });

      test('false for failed', () {
        expect(createTask(status: TransferStatus.failed).isActive, isFalse);
      });

      test('false for cancelled', () {
        expect(createTask(status: TransferStatus.cancelled).isActive, isFalse);
      });
    });

    group('isFinished', () {
      test('false for queued', () {
        expect(createTask(status: TransferStatus.queued).isFinished, isFalse);
      });

      test('false for inProgress', () {
        expect(createTask(status: TransferStatus.inProgress).isFinished, isFalse);
      });

      test('true for completed', () {
        expect(createTask(status: TransferStatus.completed).isFinished, isTrue);
      });

      test('true for failed', () {
        expect(createTask(status: TransferStatus.failed).isFinished, isTrue);
      });

      test('true for cancelled', () {
        expect(createTask(status: TransferStatus.cancelled).isFinished, isTrue);
      });
    });

    group('mutable fields', () {
      test('status can be changed', () {
        final task = createTask();
        task.status = TransferStatus.inProgress;
        expect(task.status, TransferStatus.inProgress);
      });

      test('transferredBytes can be changed', () {
        final task = createTask();
        task.transferredBytes = 500;
        expect(task.transferredBytes, 500);
      });

      test('errorMessage can be set', () {
        final task = createTask();
        task.errorMessage = 'Failed';
        expect(task.errorMessage, 'Failed');
      });

      test('completedAt can be set', () {
        final task = createTask();
        final now = DateTime.now();
        task.completedAt = now;
        expect(task.completedAt, now);
      });
    });
  });

  group('TransferDirection', () {
    test('has toAndroid value', () {
      expect(TransferDirection.toAndroid, isNotNull);
    });

    test('has toMac value', () {
      expect(TransferDirection.toMac, isNotNull);
    });
  });

  group('TransferStatus', () {
    test('has all expected values', () {
      expect(TransferStatus.values.length, 5);
      expect(TransferStatus.values, contains(TransferStatus.queued));
      expect(TransferStatus.values, contains(TransferStatus.inProgress));
      expect(TransferStatus.values, contains(TransferStatus.completed));
      expect(TransferStatus.values, contains(TransferStatus.failed));
      expect(TransferStatus.values, contains(TransferStatus.cancelled));
    });
  });
}
