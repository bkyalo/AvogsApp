import 'package:avogs/core/sync/sync_service.dart';
import 'package:avogs/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SyncStatusBanner extends ConsumerWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncServiceProvider);
    if (sync.isOnline && sync.pendingCount == 0 && !sync.isSyncing) {
      return const SizedBox.shrink();
    }

    final message = !sync.isOnline
        ? 'Offline — ${sync.pendingCount} pending'
        : sync.isSyncing
            ? 'Syncing ${sync.pendingCount} item(s)...'
            : '${sync.pendingCount} item(s) waiting to sync';

    return Material(
      color: !sync.isOnline ? AppColors.honey : AppColors.infoBlue,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                !sync.isOnline ? Icons.cloud_off : Icons.sync,
                color: AppColors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (sync.isOnline && sync.pendingCount > 0)
                TextButton(
                  onPressed: () =>
                      ref.read(syncServiceProvider.notifier).syncPending(),
                  child: const Text(
                    'Sync now',
                    style: TextStyle(color: AppColors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
