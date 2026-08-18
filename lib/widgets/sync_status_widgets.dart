import 'package:flutter/material.dart';

import '../design_system/tokens/color_tokens.dart';
import '../design_system/tokens/typography.dart';

enum SyncStatus {
  idle,
  syncing,
  success,
  conflict,
  error,
  offline,
}

/// Simplified indicator that reflects local data persistence state.
class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({
    super.key,
    this.showLabel = true,
    this.compact = false,
  });

  final bool showLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _buildStatusWidget(
      status: SyncStatus.success,
      label: showLabel ? 'Saved locally' : null,
      compact: compact,
    );
  }

  Widget _buildStatusWidget({
    required SyncStatus status,
    String? label,
    required bool compact,
  }) {
    final color = _getStatusColor(status);
    final icon = _getStatusIcon(status);

    if (compact) {
      return Tooltip(
        message: label ?? _getStatusLabel(status),
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          if (label != null) ...[
            const SizedBox(width: 8),
            Text(
              label,
              style: MindWellTypography.body(color: color).copyWith(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.success:
        return Colors.green;
      case SyncStatus.syncing:
        return MindWellColors.lightGreen;
      case SyncStatus.idle:
      case SyncStatus.offline:
        return Colors.grey;
      case SyncStatus.conflict:
        return Colors.orange;
      case SyncStatus.error:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.success:
        return Icons.cloud_done;
      case SyncStatus.syncing:
        return Icons.cloud_sync;
      case SyncStatus.idle:
        return Icons.cloud_queue;
      case SyncStatus.conflict:
      case SyncStatus.error:
      case SyncStatus.offline:
        return Icons.cloud_off;
    }
  }

  String _getStatusLabel(SyncStatus status) {
    switch (status) {
      case SyncStatus.success:
        return 'Synced';
      case SyncStatus.syncing:
        return 'Syncing';
      case SyncStatus.idle:
        return 'Idle';
      case SyncStatus.conflict:
        return 'Conflict';
      case SyncStatus.error:
        return 'Error';
      case SyncStatus.offline:
        return 'Offline';
    }
  }
}

/// Placeholder panel for future sync queue messaging.
class OfflineQueuePanel extends StatelessWidget {
  const OfflineQueuePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_done, color: MindWellColors.lightGreen, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Offline sync disabled – all changes stay on-device.',
              style: MindWellTypography.body(color: MindWellColors.darkGray)
                  .copyWith(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
