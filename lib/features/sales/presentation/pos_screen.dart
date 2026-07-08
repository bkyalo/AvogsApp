import 'package:avogs/core/responsive/breakpoints.dart';
import 'package:avogs/core/theme/app_colors.dart';
import 'package:avogs/features/master_data/master_data_repository.dart';
import 'package:avogs/features/sales/application/pos_controller.dart';
import 'package:avogs/features/sales/presentation/sales_receipt_screen.dart';
import 'package:avogs/shared/models/transaction_models.dart';
import 'package:avogs/shared/widgets/sync_status_banner.dart';
import 'package:avogs/shared/widgets/transaction_form_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PosScreen extends ConsumerWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(posControllerProvider);
    final controller = ref.read(posControllerProvider.notifier);
    final customers = ref.watch(customersProvider);
    final layout = layoutSizeOf(context);

    if (state.loading && state.prefill == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null && state.prefill == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => controller.loadPrefill(
                  customerId: state.customerId,
                  location: state.location,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final prefill = state.prefill!;
    final catalogPanel = _CatalogPanel(
      catalog: prefill.catalog,
      onAdd: controller.addLine,
    );
    final cartPanel = _CartPanel(state: state, controller: controller);

    return Column(
      children: [
        const SyncStatusBanner(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(height: 10),
              SegmentedButton<SaleTiming>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
                segments: const [
                  ButtonSegment(
                    value: SaleTiming.payNow,
                    icon: Icon(Icons.payments_outlined, size: 16),
                    label: Text('Pay now'),
                  ),
                  ButtonSegment(
                    value: SaleTiming.payLater,
                    icon: Icon(Icons.schedule_outlined, size: 16),
                    label: Text('Pay later'),
                  ),
                ],
                selected: {state.saleTiming},
                onSelectionChanged: state.submitting
                    ? null
                    : (s) => controller.setSaleTiming(s.first),
              ),
              if (state.saleTiming == SaleTiming.payNow) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<PaymentMethod>(
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                        ),
                        segments: const [
                          ButtonSegment(
                            value: PaymentMethod.cash,
                            icon: Icon(Icons.payments_outlined, size: 16),
                            label: Text('Cash'),
                          ),
                          ButtonSegment(
                            value: PaymentMethod.mpesa,
                            icon: Icon(Icons.phone_iphone, size: 16),
                            label: Text('M-Pesa'),
                          ),
                        ],
                        selected: {state.paymentMethod},
                        onSelectionChanged: state.submitting
                            ? null
                            : (s) => controller.setPaymentMethod(s.first),
                      ),
                    ),
                  ],
                ),
                if (state.paymentMethod == PaymentMethod.mpesa) ...[
                  const SizedBox(height: 10),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'M-Pesa reference',
                      hintText: 'e.g. QA123456',
                      isDense: true,
                    ),
                    enabled: !state.submitting,
                    onChanged: controller.setPaymentMemo,
                  ),
                ],
              ] else if (prefill.defaults.dueDate != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Due ${prefill.defaults.dueDate}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${prefill.defaults.reference} · ${prefill.defaults.location}',
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: layout == LayoutSize.expanded
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: catalogPanel),
                    const VerticalDivider(width: 1),
                    Expanded(flex: 2, child: cartPanel),
                  ],
                )
              : cartPanel,
        ),
        if (layout != LayoutSize.expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => CatalogPickerSheet.show(
                  context,
                  catalog: prefill.catalog,
                  onSelected: controller.addLine,
                  showPrice: (item) => item.unitPrice,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add item'),
              ),
            ),
          ),
        TransactionTotalBar(
          total: state.total,
          submitting: state.submitting,
          enabled: state.lines.isNotEmpty,
          submitLabel: state.saleTiming == SaleTiming.payLater
              ? 'Post invoice'
              : 'Complete sale',
          onSubmit: () => _submit(context, ref, controller, state.lines),
        ),
      ],
    );
  }

  Future<void> _submit(
    BuildContext context,
    WidgetRef ref,
    PosController controller,
    List<TransactionLine> lines,
  ) async {
    final ok = await confirmStockWarnings(context, lines);
    if (!ok || !context.mounted) return;

    final result = await controller.submit();
    if (result == null || !context.mounted) return;

    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SalesReceiptScreen(
          reference: result.reference,
          customerName: result.customerName,
          storeCode: result.storeCode,
          documentDate: result.documentDate,
          lines: result.lines,
          total: result.total,
          paymentMethod: result.paymentMethod,
          paymentStatus: result.paymentStatus,
          balanceDue: result.balanceDue,
          invoiceNo: result.invoiceNo,
          customerId: result.customerId,
          queuedOffline: result.queuedOffline,
        ),
      ),
    );
  }
}

class _CatalogPanel extends StatelessWidget {
  const _CatalogPanel({required this.catalog, required this.onAdd});

  final List<CatalogItem> catalog;
  final ValueChanged<CatalogItem> onAdd;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Catalog', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in catalog)
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: Text(item.description),
                onPressed: () => onAdd(item),
              ),
          ],
        ),
      ],
    );
  }
}

class _CartPanel extends ConsumerWidget {
  const _CartPanel({required this.state, required this.controller});

  final PosState state;
  final PosController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (state.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              state.errorMessage!,
              style: const TextStyle(color: AppColors.errorRed),
            ),
          ),
        TransactionLineList(
          lines: state.lines,
          onQuantityChanged: controller.updateQuantity,
          onUnitPriceChanged: controller.updatePrice,
          onRemove: controller.removeLine,
        ),
      ],
    );
  }
}
