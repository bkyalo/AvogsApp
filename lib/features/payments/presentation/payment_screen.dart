import 'package:avogs/core/theme/app_colors.dart';
import 'package:avogs/core/utils/formatters.dart';
import 'package:avogs/features/master_data/master_data_repository.dart';
import 'package:avogs/features/payments/application/payment_controller.dart';
import 'package:avogs/shared/widgets/sync_status_banner.dart';
import 'package:avogs/shared/widgets/transaction_success_screen.dart';
import 'package:avogs/shared/widgets/transaction_form_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PaymentScreen extends ConsumerWidget {
  const PaymentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(paymentControllerProvider);
    final controller = ref.read(paymentControllerProvider.notifier);
    final customers = ref.watch(customersProvider);

    if (state.loading && state.prefill == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final prefill = state.prefill;
    if (prefill == null) {
      return Center(child: Text(state.errorMessage ?? 'Failed to load payment form'));
    }

    return Column(
      children: [
        const SyncStatusBanner(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              customers.when(
                data: (list) => DropdownButtonFormField<int>(
                  value: state.customerId,
                  decoration: const InputDecoration(labelText: 'Customer'),
                  items: [
                    for (final c in list)
                      DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (id) {
                    if (id != null) controller.setCustomer(id);
                  },
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
              ),
              const SizedBox(height: 12),
              Text(
                prefill.defaults.reference,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: ValueKey(prefill.defaults.reference),
                initialValue: state.amount > 0 ? state.amount.toStringAsFixed(2) : '',
                decoration: const InputDecoration(
                  labelText: 'Payment amount',
                  prefixText: 'KES ',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                onChanged: (v) {
                  final parsed = double.tryParse(v);
                  if (parsed != null) controller.setAmount(parsed);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: state.selectedBankAccountId,
                decoration: const InputDecoration(labelText: 'Bank account'),
                items: [
                  for (final b in prefill.bankAccounts)
                    DropdownMenuItem(value: b.id, child: Text(b.name)),
                ],
                onChanged: (id) {
                  if (id != null) controller.setBankAccount(id);
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Open invoices',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (prefill.openDocuments.isEmpty)
                const Text('No open invoices for this customer.')
              else
                for (final doc in prefill.openDocuments)
                  Card(
                    child: CheckboxListTile(
                      value: state.allocations.containsKey(doc.transNo),
                      onChanged: (checked) =>
                          controller.toggleAllocation(doc, checked ?? false),
                      title: Text(doc.reference),
                      subtitle: Text(
                        '${doc.documentDate} · Balance ${formatMoney(doc.balance)}',
                      ),
                      secondary: state.allocations.containsKey(doc.transNo)
                          ? SizedBox(
                              width: 90,
                              child: TextFormField(
                                initialValue: state.allocations[doc.transNo]
                                    ?.toStringAsFixed(2),
                                decoration: const InputDecoration(isDense: true),
                                keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                onChanged: (v) {
                                  final parsed = double.tryParse(v);
                                  if (parsed != null) {
                                    controller.setAllocationAmount(
                                      doc.transNo,
                                      parsed,
                                    );
                                  }
                                },
                              ),
                            )
                          : null,
                    ),
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
          total: state.amount,
          submitting: state.submitting,
          enabled: state.amount > 0,
          submitLabel: 'Record payment',
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
