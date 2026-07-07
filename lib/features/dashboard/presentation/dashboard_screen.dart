import 'package:avogs/core/config/app_config_provider.dart';
import 'package:avogs/core/sync/sync_service.dart';
import 'package:avogs/core/theme/app_colors.dart';
import 'package:avogs/features/master_data/master_data_repository.dart';
import 'package:avogs/shared/widgets/sync_status_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  var _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncMasterData());
  }

  Future<void> _syncMasterData() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await ref.read(masterDataSyncProvider.notifier).refreshCustomersAndSuppliers();
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      ref.read(masterDataSyncProvider.notifier).refreshCustomersAndSuppliers(),
      ref.read(syncServiceProvider.notifier).syncPending(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final customersAsync = ref.watch(customersProvider);
    final suppliersAsync = ref.watch(suppliersProvider);

    return Column(
      children: [
        const SyncStatusBanner(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Today',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            if (_isRefreshing)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else
                              IconButton(
                                icon: const Icon(Icons.refresh),
                                tooltip: 'Refresh',
                                onPressed: _syncMasterData,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sales summary and reports will appear here once connected to the API.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        if (config.selectedStoreCode != null) ...[
                          const SizedBox(height: 12),
                          Chip(
                            label: Text('Store: ${config.selectedStoreCode}'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Master data',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _MasterDataTile(
                  icon: Icons.people_outline,
                  label: 'Customers',
                  asyncValue: customersAsync,
                ),
                const SizedBox(height: 8),
                _MasterDataTile(
                  icon: Icons.local_shipping_outlined,
                  label: 'Suppliers',
                  asyncValue: suppliersAsync,
                ),
                const SizedBox(height: 8),
                Text(
                  'Pull down to refresh customers, suppliers, and pending sync.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MasterDataTile extends StatelessWidget {
  const _MasterDataTile({
    required this.icon,
    required this.label,
    required this.asyncValue,
  });

  final IconData icon;
  final String label;
  final AsyncValue<dynamic> asyncValue;

  @override
  Widget build(BuildContext context) {
    final trailing = asyncValue.when(
      loading: () => const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (e, _) => Text(
        'Error',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      data: (items) => Text(
        '${items.length} cached',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.primaryGreen,
              fontWeight: FontWeight.w600,
            ),
      ),
    );

    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppColors.primaryGreen),
        title: Text(label),
        trailing: trailing,
      ),
    );
  }
}
