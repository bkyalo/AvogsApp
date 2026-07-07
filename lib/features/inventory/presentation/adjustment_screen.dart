import 'package:avogs/core/theme/app_colors.dart';
import 'package:avogs/features/inventory/application/adjustment_controller.dart';
import 'package:avogs/shared/widgets/sync_status_banner.dart';
import 'package:avogs/shared/widgets/transaction_success_screen.dart';
import 'package:avogs/shared/widgets/transaction_form_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdjustmentScreen extends ConsumerWidget {
  const AdjustmentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adjustmentControllerProvider);
    final controller = ref.read(adjustmentControllerProvider.notifier);

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
              Text(
                '${prefill.defaults.reference} · ${prefill.defaults.location}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: ValueKey(prefill.defaults.reference),
                decoration: const InputDecoration(
                  labelText: 'Memo',
                  hintText: 'e.g. 3 avocados spoiled',
                ),
                onChanged: controller.setMemo,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => CatalogPickerSheet.show(
                        context,
                        catalog: prefill.catalog,
                        onSelected: (item) => controller.addLine(item, decrease: true),
                        showPrice: (item) => item.materialCost,
                      ),
                      icon: const Icon(Icons.remove_circle_outline),
                      label: const Text('Decrease (wastage)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => CatalogPickerSheet.show(
                        context,
                        catalog: prefill.catalog,
                        onSelected: (item) => controller.addLine(item, decrease: false),
                        showPrice: (item) => item.materialCost,
                      ),
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Increase'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TransactionLineList(
                lines: state.lines,
                onQuantityChanged: controller.updateQuantity,
                onRemove: controller.removeLine,
                allowNegativeQuantity: true,
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
          total: state.lines.fold(0, (sum, l) => sum + l.quantity.abs()),
          submitting: state.submitting,
          enabled: state.lines.isNotEmpty,
          submitLabel: 'Save adjustment',
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
