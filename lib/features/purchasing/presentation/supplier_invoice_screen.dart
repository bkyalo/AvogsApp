import 'package:avogs/core/theme/app_colors.dart';
import 'package:avogs/features/master_data/master_data_repository.dart';
import 'package:avogs/features/purchasing/application/purchase_controller.dart';
import 'package:avogs/shared/widgets/sync_status_banner.dart';
import 'package:avogs/shared/widgets/transaction_success_screen.dart';
import 'package:avogs/shared/widgets/transaction_form_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SupplierInvoiceScreen extends ConsumerWidget {
  const SupplierInvoiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(purchaseControllerProvider);
    final controller = ref.read(purchaseControllerProvider.notifier);
    final suppliers = ref.watch(suppliersProvider);

    if (state.loading && state.prefill == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final prefill = state.prefill;
    if (prefill == null) {
      return Center(child: Text(state.errorMessage ?? 'Failed to load form'));
    }

    return Column(
      children: [
        const SyncStatusBanner(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              suppliers.when(
                data: (list) => DropdownButtonFormField<int>(
                  value: state.supplierId,
                  decoration: const InputDecoration(labelText: 'Supplier'),
                  items: [
                    for (final s in list)
                      DropdownMenuItem(value: s.id, child: Text(s.name)),
                  ],
                  onChanged: (id) {
                    if (id != null) {
                      controller.load(supplierId: id, location: state.location);
                    }
                  },
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: ValueKey(prefill.defaults.reference),
                decoration: const InputDecoration(
                  labelText: 'Supplier invoice #',
                  hintText: 'Required — supplier\'s own reference',
                ),
                onChanged: controller.setSupplierRef,
              ),
              const SizedBox(height: 8),
              Text(
                '${prefill.defaults.reference} · ${prefill.defaults.location}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => CatalogPickerSheet.show(
                    context,
                    catalog: prefill.catalog,
                    onSelected: controller.addLine,
                    showPrice: (item) => item.supplierPrice,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add item'),
                ),
              ),
              const SizedBox(height: 12),
              TransactionLineList(
                lines: state.lines,
                requirePrice: true,
                onQuantityChanged: controller.updateQuantity,
                onUnitPriceChanged: controller.updatePrice,
                onRemove: controller.removeLine,
              ),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  state.errorMessage!,
                  style: const TextStyle(color: AppColors.errorRed),
                ),
              ],
            ],
          ),
        ),
        TransactionTotalBar(
          total: state.total,
          submitting: state.submitting,
          enabled: state.lines.isNotEmpty &&
              state.supplierRef.trim().isNotEmpty &&
              state.lines.every((l) => l.unitPrice > 0),
          submitLabel: 'Receive stock',
          onSubmit: () async {
            final details = await controller.submit();
            if (details != null && context.mounted) {
              await showTransactionSuccess(context, details);
            }
          },
        ),
      ],
    );
  }
}
