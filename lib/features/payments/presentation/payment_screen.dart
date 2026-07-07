import 'package:avogs/core/theme/app_colors.dart';
import 'package:avogs/core/utils/formatters.dart';
import 'package:avogs/features/master_data/master_data_repository.dart';
import 'package:avogs/features/payments/application/payment_controller.dart';
import 'package:avogs/shared/models/transaction_models.dart';
import 'package:avogs/shared/widgets/sync_status_banner.dart';
import 'package:avogs/shared/widgets/transaction_success_screen.dart';
import 'package:avogs/shared/widgets/transaction_form_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PaymentScreen extends ConsumerWidget {
  const PaymentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(paymentControllerProvider);
    final controller = ref.read(paymentControllerProvider.notifier);
    final customers = ref.watch(customersProvider);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    if (state.loading && state.prefill == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final prefill = state.prefill;
    if (prefill == null) {
      return Center(
        child: Text(state.errorMessage ?? 'Failed to load payment form'),
      );
    }

    final allocated = state.allocatedTotal;
    final overAllocated = allocated > state.amount + 0.005;

    return Column(
      children: [
        const SyncStatusBanner(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              customers.when(
                data: (list) => CustomerPickerField(
                  customers: list,
                  selectedId: state.customerId,
                  enabled: !state.submitting,
                  onSelected: controller.setCustomer,
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
              ),
              const SizedBox(height: 8),
              Text(
                '${prefill.defaults.reference} · ${prefill.defaults.documentDate}',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
              const SizedBox(height: 16),
              MoneyField(
                value: state.amount,
                label: 'Payment amount',
                emptyWhenZero: true,
                textStyle: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                onChanged: controller.setAmount,
              ),
              if (state.allocations.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  overAllocated
                      ? 'Allocated ${formatMoney(allocated)} — more than the payment amount'
                      : 'Allocated ${formatMoney(allocated)} to ${state.allocations.length} invoice(s)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: overAllocated ? AppColors.errorRed : muted,
                    fontWeight:
                        overAllocated ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
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
              Text('Open invoices', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (prefill.openDocuments.isEmpty)
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 28,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 34,
                          color: muted.withValues(alpha: 0.7),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No open invoices',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'This customer has nothing outstanding — the payment will be recorded on account',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                for (final doc in prefill.openDocuments) ...[
                  _InvoiceCard(
                    doc: doc,
                    allocated: state.allocations[doc.transNo],
                    onToggle: (checked) =>
                        controller.toggleAllocation(doc, checked),
                    onAmountChanged: (v) =>
                        controller.setAllocationAmount(doc.transNo, v),
                  ),
                  const SizedBox(height: 10),
                ],
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
          totalLabel: 'Payment',
          submitting: state.submitting,
          enabled: state.amount > 0 && state.selectedBankAccountId != null,
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

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({
    required this.doc,
    required this.allocated,
    required this.onToggle,
    required this.onAmountChanged,
  });

  final OpenDocument doc;
  final double? allocated;
  final ValueChanged<bool> onToggle;
  final ValueChanged<double> onAmountChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final selected = allocated != null;
    final overBalance = selected && allocated! > doc.balance + 0.005;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: selected
            ? BorderSide(color: theme.colorScheme.primary, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onToggle(!selected),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          child: Column(
            children: [
              Row(
                children: [
                  Checkbox(
                    value: selected,
                    visualDensity: VisualDensity.compact,
                    onChanged: (checked) => onToggle(checked ?? false),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.reference,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          doc.documentDate,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatMoney(doc.balance),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Balance',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (selected)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 0, 4),
                  child: MoneyField(
                    value: allocated!,
                    label: 'Allocate',
                    errorText: overBalance
                        ? 'Max ${formatMoney(doc.balance)}'
                        : null,
                    onChanged: onAmountChanged,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
