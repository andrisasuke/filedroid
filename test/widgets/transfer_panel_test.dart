import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:filedroid/models/transfer_task.dart';
import 'package:filedroid/providers/transfer_provider.dart';
import 'package:filedroid/widgets/transfer_panel.dart';
import '../helpers/test_helpers.dart';

/// Helper: create a completed task and add it to the provider.
TransferTask _addCompletedTask(TransferProvider prov, {
  String id = 'test_1',
  String fileName = 'test.txt',
  TransferDirection direction = TransferDirection.toMac,
  int totalBytes = 1024000,
}) {
  final task = TransferTask(
    id: id,
    sourcePath: '/sdcard/$fileName',
    destPath: '/tmp/$fileName',
    fileName: fileName,
    direction: direction,
    totalBytes: totalBytes,
  );
  task.status = TransferStatus.completed;
  task.transferredBytes = totalBytes;
  task.completedAt = DateTime.now();
  prov.tasks.add(task);
  return task;
}

/// Helper: create a failed task and add it to the provider.
TransferTask _addFailedTask(TransferProvider prov, {
  String id = 'test_1',
  String fileName = 'fail.txt',
  String error = 'Exception: Network error',
}) {
  final task = TransferTask(
    id: id,
    sourcePath: '/sdcard/$fileName',
    destPath: '/tmp/$fileName',
    fileName: fileName,
    direction: TransferDirection.toMac,
    totalBytes: 1024000,
  );
  task.status = TransferStatus.failed;
  task.errorMessage = error;
  task.completedAt = DateTime.now();
  prov.tasks.add(task);
  return task;
}

/// Helper: create a cancelled task and add it to the provider.
TransferTask _addCancelledTask(TransferProvider prov, {
  String id = 'test_1',
  String fileName = 'test.txt',
}) {
  final task = TransferTask(
    id: id,
    sourcePath: '/sdcard/$fileName',
    destPath: '/tmp/$fileName',
    fileName: fileName,
    direction: TransferDirection.toMac,
    totalBytes: 1024000,
  );
  task.status = TransferStatus.cancelled;
  task.completedAt = DateTime.now();
  prov.tasks.add(task);
  return task;
}

/// Helper: create an in-progress task and add it to the provider.
TransferTask _addInProgressTask(TransferProvider prov, {
  String id = 'test_1',
  String fileName = 'downloading.txt',
  TransferDirection direction = TransferDirection.toMac,
  int transferred = 512000,
  int total = 1024000,
}) {
  final task = TransferTask(
    id: id,
    sourcePath: direction == TransferDirection.toMac
        ? '/sdcard/$fileName'
        : '/tmp/$fileName',
    destPath: direction == TransferDirection.toMac
        ? '/tmp/$fileName'
        : '/sdcard/$fileName',
    fileName: fileName,
    direction: direction,
    totalBytes: total,
  );
  task.status = TransferStatus.inProgress;
  task.transferredBytes = transferred;
  prov.tasks.add(task);
  return task;
}

/// Helper: create a queued task and add it to the provider.
TransferTask _addQueuedTask(TransferProvider prov, {
  String id = 'test_1',
  String fileName = 'queued.txt',
  TransferDirection direction = TransferDirection.toMac,
  int totalBytes = 1024000,
}) {
  final task = TransferTask(
    id: id,
    sourcePath: '/sdcard/$fileName',
    destPath: '/tmp/$fileName',
    fileName: fileName,
    direction: direction,
    totalBytes: totalBytes,
  );
  // status defaults to queued
  prov.tasks.add(task);
  return task;
}

void main() {
  late MockAdbService mockAdb;
  late TransferProvider transferProvider;

  setUp(() {
    mockAdb = createMockAdb();
    transferProvider = createTransferProvider(mockAdb);
  });

  group('TransferPanel', () {
    testWidgets('shows "Transfers" header', (tester) async {
      await pumpApp(tester, const TransferPanel(), transferProvider: transferProvider);

      expect(find.text('Transfers'), findsOneWidget);
    });

    testWidgets('shows empty state when no transfers', (tester) async {
      await pumpApp(tester, const TransferPanel(), transferProvider: transferProvider);

      expect(find.text('No transfers'), findsOneWidget);
    });

    testWidgets('shows completed task with "ok" badge and "Done" subtitle', (tester) async {
      _addCompletedTask(transferProvider);
      await pumpApp(tester, const TransferPanel(), transferProvider: transferProvider);

      expect(find.text('ok'), findsOneWidget);
      expect(find.textContaining('Done'), findsOneWidget);
    });

    testWidgets('shows failed task with "!" badge and error message', (tester) async {
      _addFailedTask(transferProvider);
      await pumpApp(tester, const TransferPanel(), transferProvider: transferProvider);

      expect(find.text('!'), findsOneWidget);
      expect(find.textContaining('Exception: Network error'), findsOneWidget);
    });

    testWidgets('shows cancelled task with "--" badge and "Cancelled" subtitle', (tester) async {
      _addCancelledTask(transferProvider);
      await pumpApp(tester, const TransferPanel(), transferProvider: transferProvider);

      expect(find.text('--'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);
    });

    testWidgets('shows queued task with queued badge', (tester) async {
      // Add an in-progress task first (so queue doesn't auto-process)
      _addInProgressTask(transferProvider, id: 'active_1');
      _addQueuedTask(transferProvider, id: 'queued_1');
      await pumpApp(tester, const TransferPanel(), transferProvider: transferProvider);

      expect(find.textContaining('Queued'), findsOneWidget);
    });

    testWidgets('shows in-progress task (toMac) with "v" badge', (tester) async {
      _addInProgressTask(transferProvider, direction: TransferDirection.toMac);
      await pumpApp(tester, const TransferPanel(), transferProvider: transferProvider);

      expect(find.text('v'), findsOneWidget);
    });

    testWidgets('shows in-progress task (toAndroid) with "^" badge', (tester) async {
      _addInProgressTask(transferProvider, direction: TransferDirection.toAndroid);
      await pumpApp(tester, const TransferPanel(), transferProvider: transferProvider);

      expect(find.text('^'), findsOneWidget);
    });

    testWidgets('shows clear button when tasks exist and calls clearFinished', (tester) async {
      _addCompletedTask(transferProvider);
      await pumpApp(tester, const TransferPanel(), transferProvider: transferProvider);

      expect(find.text('Clear'), findsOneWidget);

      // Tap clear button
      await tester.tap(find.text('Clear'));
      await tester.pump();

      // All finished tasks should be removed
      expect(transferProvider.tasks.isEmpty, true);
      expect(find.text('No transfers'), findsOneWidget);
    });

    testWidgets('footer shows "All transfers complete!" when all done', (tester) async {
      _addCompletedTask(transferProvider, id: 'c1', fileName: 'file1.txt');
      _addCompletedTask(transferProvider, id: 'c2', fileName: 'file2.txt');
      await pumpApp(tester, const TransferPanel(), transferProvider: transferProvider);

      expect(find.text('All transfers complete!'), findsOneWidget);
    });

    testWidgets('footer shows active/queued count during transfers', (tester) async {
      _addInProgressTask(transferProvider, id: 'a1', fileName: 'file1.txt');
      _addQueuedTask(transferProvider, id: 'q1', fileName: 'file2.txt');
      await pumpApp(tester, const TransferPanel(), transferProvider: transferProvider);

      expect(find.textContaining('active'), findsOneWidget);
      expect(find.textContaining('queued'), findsOneWidget);
    });

    testWidgets('shows check icon for completed transfers', (tester) async {
      _addCompletedTask(transferProvider);
      await pumpApp(tester, const TransferPanel(), transferProvider: transferProvider);

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('shows cancel button for active transfers', (tester) async {
      _addInProgressTask(transferProvider);
      await pumpApp(tester, const TransferPanel(), transferProvider: transferProvider);

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('shows progress bar for in-progress transfers', (tester) async {
      _addInProgressTask(transferProvider);
      await pumpApp(tester, const TransferPanel(), transferProvider: transferProvider);

      // Progress bar uses FractionallySizedBox
      expect(find.byType(FractionallySizedBox), findsOneWidget);
    });

    testWidgets('cancel button tap calls cancelTask', (tester) async {
      _addInProgressTask(transferProvider);
      await pumpApp(tester, const TransferPanel(), transferProvider: transferProvider);

      // Verify task is in progress
      expect(transferProvider.tasks.first.status, TransferStatus.inProgress);

      // Tap cancel button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Verify task was cancelled
      expect(transferProvider.tasks.first.status, TransferStatus.cancelled);
    });
  });
}
