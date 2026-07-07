import 'package:avogs/core/routing/app_routes.dart';
import 'package:avogs/core/theme/app_colors.dart';
import 'package:avogs/features/shifts/application/checkout_controller.dart';
import 'package:avogs/features/shifts/shifts_repository.dart';
import 'package:avogs/shared/widgets/sync_status_banner.dart';
import 'package:avogs/shared/widgets/transaction_form_widgets.dart';
import 'package:avogs/shared/widgets/transaction_success_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _stepTitles = ['Cash', 'Stock Count', 'Notes'];

/// Closing counterpart to [CheckinScreen] — deliberately smaller: no shift
/// picker (the open shift is already known), no photos, one notes field
/// instead of two, and one fewer step. Reached from Account or a
/// reminder-notification tap, never a required gate.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    if (index == _page) return;
    setState(() => _page = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _handleBottomAction(
    BuildContext context,
    CheckoutController controller,
  ) async {
    if (_page < _stepTitles.length - 1) {
      _goToPage(_page + 1);
      return;
    }
    final details = await controller.submit();
    if (details != null && context.mounted) {
      await showTransactionSuccess(context, details);
      // Closing the shop locks the app behind PIN entry (see
      // CheckoutController.submit) — go straight there instead of the
      // dashboard, which the router would just redirect away from anyway
      // now that the session is locked.
      if (context.mounted) context.go(AppRoutes.pinUnlock);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(checkoutControllerProvider);
    final controller = ref.read(checkoutControllerProvider.notifier);
    final showBackButton = !state.loading && !state.blocked && _page > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Close Shop'),
        automaticallyImplyLeading: false,
        leading: showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _goToPage(_page - 1),
              )
            : null,
      ),
      body: _buildBody(context, state, controller),
    );
  }

  Widget _buildBody(
    BuildContext context,
    CheckoutFormState state,
    CheckoutController controller,
  ) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.blocked) {
      return _BlockedView(status: state.blockedStatus);
    }

    return Column(
      children: [
        const SyncStatusBanner(),
        _StepHeader(currentPage: _page, onTapStep: _goToPage),
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _page = i),
            children: [
              _CashPage(state: state, controller: controller),
              _StockCountPage(state: state, controller: controller),
              _NotesPage(state: state, controller: controller),
            ],
          ),
        ),
        TransactionTotalBar(
          total: state.till + state.floatAmount,
          totalLabel: 'Till + Float',
          submitting: state.submitting,
          enabled: true,
          submitLabel: _page < _stepTitles.length - 1 ? 'Next' : 'Close Shop',
          onSubmit: () => _handleBottomAction(context, controller),
        ),
      ],
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.currentPage, required this.onTapStep});

  final int currentPage;
  final ValueChanged<int> onTapStep;

  @override
  Widget build(BuildContext context) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step ${currentPage + 1} of ${_stepTitles.length} · ${_stepTitles[currentPage]}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < _stepTitles.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: GestureDetector(
                    onTap: () => onTapStep(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= currentPage
                            ? AppColors.primaryGreen
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CashPage extends StatelessWidget {
  const _CashPage({required this.state, required this.controller});

  final CheckoutFormState state;
  final CheckoutController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionLabel('Shift'),
        const SizedBox(height: 8),
        Text(
          '${state.shift[0].toUpperCase()}${state.shift.substring(1)} shift',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),
        _SectionLabel('Cash'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: MoneyField(
                value: state.till,
                label: 'Till',
                onChanged: controller.setTill,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MoneyField(
                value: state.floatAmount,
                label: 'Float',
                onChanged: controller.setFloat,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StockCountPage extends StatelessWidget {
  const _StockCountPage({required this.state, required this.controller});

  final CheckoutFormState state;
  final CheckoutController controller;

  @override
  Widget build(BuildContext context) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionLabel('Stock Count'),
        const SizedBox(height: 8),
        if (state.stockCounts.isEmpty)
          Text(
            'No stock count items for this shift.',
            style: TextStyle(color: onSurfaceVariant, fontSize: 13),
          )
        else
          for (var i = 0; i < state.stockCounts.length; i++) ...[
            _CheckoutStockCountRow(
              key: ValueKey('close-${state.stockCounts[i].stockId}'),
              entry: state.stockCounts[i],
              onChanged: (qty) => controller.updateActualQty(i, qty),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _NotesPage extends StatelessWidget {
  const _NotesPage({required this.state, required this.controller});

  final CheckoutFormState state;
  final CheckoutController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionLabel('Notes'),
        const SizedBox(height: 8),
        TextFormField(
          key: const ValueKey('checkout_notes'),
          initialValue: state.notes,
          decoration: const InputDecoration(
            labelText: 'Notes',
            hintText: 'Anything worth flagging before you go?',
          ),
          maxLines: 2,
          onChanged: controller.setNotes,
        ),
        if (state.errorMessage != null) ...[
          const SizedBox(height: 14),
          Text(
            state.errorMessage!,
            style: const TextStyle(color: AppColors.errorRed),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

class _CheckoutStockCountRow extends StatelessWidget {
  const _CheckoutStockCountRow({super.key, required this.entry, required this.onChanged});

  final CheckoutStockCountEntry entry;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    final mismatch = entry.actualQty != entry.expectedQty;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Expected ${entry.expectedQty.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 11, color: onSurfaceVariant),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 90,
              child: TextFormField(
                key: ValueKey('close-qty-${entry.stockId}'),
                initialValue: entry.actualQty.toStringAsFixed(0),
                textAlign: TextAlign.center,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: mismatch
                      ? AppColors.honey.withValues(alpha: 0.12)
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (v) {
                  final parsed = double.tryParse(v);
                  if (parsed != null) onChanged(parsed);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockedView extends StatelessWidget {
  const _BlockedView({required this.status});

  final ShiftStatus? status;

  @override
  Widget build(BuildContext context) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront_outlined, size: 48, color: AppColors.primaryGreen),
            const SizedBox(height: 16),
            Text(
              'No shift open',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'There\'s nothing to close right now.',
              textAlign: TextAlign.center,
              style: TextStyle(color: onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => context.go(AppRoutes.dashboard),
              child: const Text('Back to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}
