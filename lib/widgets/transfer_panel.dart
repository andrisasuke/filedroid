import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transfer_task.dart';
import '../providers/transfer_provider.dart';
import '../utils/theme.dart';

class TransferPanel extends StatelessWidget {
  const TransferPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final transfer = context.watch<TransferProvider>();

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: FileBeamTheme.bgSurface.withValues(alpha: 0.9),
        border: const Border(
          left: BorderSide(color: FileBeamTheme.borderSubtle),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: FileBeamTheme.borderSubtle),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  'Transfers',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: FileBeamTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                if (transfer.totalActive > 0)
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: FileBeamTheme.greenSuccess,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${transfer.totalActive}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                const Spacer(),
                if (transfer.tasks.isNotEmpty)
                  Tooltip(
                    message: 'Clear finished transfers',
                    waitDuration: const Duration(milliseconds: 500),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: transfer.clearFinished,
                        child: const Text(
                          'Clear',
                          style: TextStyle(
                            fontSize: 13,
                            color: FileBeamTheme.accentCyan,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Transfer items
          Expanded(
            child: transfer.tasks.isEmpty
                ? const Center(
                    child: Text(
                      'No transfers',
                      style: TextStyle(
                        fontSize: 13,
                        color: FileBeamTheme.textTertiary,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: transfer.tasks.length,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemBuilder: (context, index) {
                      return _TransferItem(task: transfer.tasks[index]);
                    },
                  ),
          ),
          // Footer
          if (transfer.tasks.isNotEmpty)
            Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: FileBeamTheme.borderSubtle),
                ),
              ),
              child: Row(
                children: [
                  if (transfer.totalActive > 0)
                    Text(
                      '${transfer.activeTasks.length} active \u2022 ${transfer.queuedTasks.length} queued',
                      style: const TextStyle(
                        fontSize: 11,
                        color: FileBeamTheme.textTertiary,
                      ),
                    )
                  else if (transfer.completedTasks.isNotEmpty)
                    const Text(
                      'All transfers complete!',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: FileBeamTheme.greenSuccess,
                      ),
                    ),
                  const Spacer(),
                  if (transfer.overallSpeed.isNotEmpty)
                    Text(
                      '~${transfer.overallSpeed}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: FileBeamTheme.textTertiary,
                      ),
                    ),
                  if (transfer.completedTasks.isNotEmpty &&
                      transfer.totalActive == 0)
                    Text(
                      '${transfer.completedTasks.length} files',
                      style: const TextStyle(
                        fontSize: 11,
                        color: FileBeamTheme.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TransferItem extends StatelessWidget {
  final TransferTask task;

  const _TransferItem({required this.task});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: FileBeamTheme.borderSubtle),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status badge
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _buildStatusBadge(),
          ),
          const SizedBox(width: 10),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.fileName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: FileBeamTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                _buildSubtitle(),
                if (task.status == TransferStatus.inProgress) ...[
                  const SizedBox(height: 6),
                  _buildProgressBar(),
                ],
                if (task.status == TransferStatus.queued) ...[
                  const SizedBox(height: 6),
                  _buildQueuedBar(),
                ],
              ],
            ),
          ),
          // Cancel button for active transfers
          if (task.isActive)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 8),
              child: Tooltip(
                message: 'Cancel transfer',
                waitDuration: const Duration(milliseconds: 500),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      context.read<TransferProvider>().cancelTask(task.id);
                    },
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: FileBeamTheme.roseError.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 13, color: FileBeamTheme.roseError),
                    ),
                  ),
                ),
              ),
            ),
          // Completion indicator
          if (task.status == TransferStatus.completed)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 8),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: task.direction == TransferDirection.toMac
                      ? FileBeamTheme.purple
                      : FileBeamTheme.greenSuccess,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 13, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    switch (task.status) {
      case TransferStatus.completed:
        return Container(
          width: 24,
          height: 20,
          decoration: BoxDecoration(
            color: FileBeamTheme.greenSuccess.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Center(
            child: Text(
              'ok',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: FileBeamTheme.greenSuccess,
              ),
            ),
          ),
        );
      case TransferStatus.inProgress:
        final color = task.direction == TransferDirection.toMac
            ? FileBeamTheme.purple
            : FileBeamTheme.accentCyan;
        return Container(
          width: 24,
          height: 20,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              task.direction == TransferDirection.toMac ? 'v' : '^',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        );
      case TransferStatus.failed:
        return Container(
          width: 24,
          height: 20,
          decoration: BoxDecoration(
            color: FileBeamTheme.roseError.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Center(
            child: Text(
              '!',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: FileBeamTheme.roseError,
              ),
            ),
          ),
        );
      case TransferStatus.cancelled:
        return Container(
          width: 24,
          height: 20,
          decoration: BoxDecoration(
            color: FileBeamTheme.amberWarning.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Center(
            child: Text(
              '--',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: FileBeamTheme.amberWarning,
              ),
            ),
          ),
        );
      default:
        return Container(
          width: 24,
          height: 20,
          decoration: BoxDecoration(
            color: FileBeamTheme.bgElevated,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              task.direction == TransferDirection.toMac ? '^' : '^',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: FileBeamTheme.textTertiary,
              ),
            ),
          ),
        );
    }
  }

  Widget _buildSubtitle() {
    switch (task.status) {
      case TransferStatus.completed:
        return Text(
          '${task.formattedTotal} \u2022 Done',
          style: const TextStyle(
            fontSize: 11,
            color: FileBeamTheme.textTertiary,
          ),
        );
      case TransferStatus.inProgress:
        return Text(
          '${task.formattedTotal} \u2022 ${task.formattedSpeed}',
          style: const TextStyle(
            fontSize: 11,
            color: FileBeamTheme.textTertiary,
          ),
        );
      case TransferStatus.failed:
        return Text(
          task.errorMessage ?? 'Transfer failed',
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            color: FileBeamTheme.roseError,
          ),
        );
      case TransferStatus.queued:
        return Text(
          '${task.formattedTotal} \u2022 Queued',
          style: const TextStyle(
            fontSize: 11,
            color: FileBeamTheme.textTertiary,
          ),
        );
      case TransferStatus.cancelled:
        return const Text(
          'Cancelled',
          style: TextStyle(
            fontSize: 11,
            color: FileBeamTheme.amberWarning,
          ),
        );
    }
  }

  Widget _buildProgressBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 4,
        child: Stack(
          children: [
            Container(color: FileBeamTheme.bgElevated),
            FractionallySizedBox(
              widthFactor: task.progress,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: FileBeamTheme.progressGradient,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueuedBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 4,
        child: Container(color: FileBeamTheme.bgElevated),
      ),
    );
  }
}
