import 'package:avogs/core/routing/app_routes.dart';
import 'package:avogs/core/theme/app_colors.dart';
import 'package:avogs/features/shifts/application/checkin_controller.dart';
import 'package:avogs/features/shifts/shifts_repository.dart';
import 'package:avogs/shared/widgets/sync_status_banner.dart';
import 'package:avogs/shared/widgets/transaction_form_widgets.dart';
import 'package:avogs/shared/widgets/transaction_success_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _stepTitles = ['Shift & Cash', 'Stock Count', 'Photos', 'Notes'];

class CheckinScreen extends ConsumerStatefulWidget {
  const CheckinScreen({super.key});

  @override
  ConsumerState<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends ConsumerState<CheckinScreen> {
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
    CheckinController controller,
  ) async {
    if (_page < _stepTitles.length - 1) {
      _goToPage(_page + 1);
      return;
    }
    final details = await controller.submit();
    if (details != null) {
      if (context.mounted) {
        await showTransactionSuccess(context, details);
        if (context.mounted) context.go(AppRoutes.dashboard);
      }
      return;
    }
    // Submit failed — if it's the photo-upload guard, jump back to the
    // Photos step so the error is visible next to what it's actually
    // about, rather than wherever the user happened to be.
    final error = ref.read(checkinControllerProvider).errorMessage;
    if (error != null && error.toLowerCase().contains('photo')) {
      _goToPage(2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(checkinControllerProvider);
    final controller = ref.read(checkinControllerProvider.notifier);
    final showBackButton =
        !state.loading && !state.blocked && state.errorMessage == null && _page > 0;

    return Scaffold(
      // No shell here on purpose — this is a focused onboarding step shown
      // right after login (or PIN unlock) when no shift is open yet, not a
      // regular tab. No back button until there's somewhere to go back to
      // (a previous step).
      appBar: AppBar(
        title: const Text('Open Shop'),
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
    CheckinFormState state,
    CheckinController controller,
  ) {
    if (state.loading && !state.blocked) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading check-in form…'),
          ],
        ),
      );
    }

    if (state.blocked) {
      return _BlockedView(status: state.blockedStatus);
    }

    // A hard failure — nothing came back for either the stock list or the
    // photo slots — gets the full-screen retry view. A failure surfaced
    // later (e.g. on submit) leaves that data in place, so this condition
    // won't wrongly blow away a mostly-loaded form over one bad request.
    final hasLoadError = state.errorMessage != null &&
        !state.loadingPrefill &&
        state.stockCounts.isEmpty &&
        state.photoSlots.isEmpty;
    if (hasLoadError) {
      return _LoadErrorView(
        message: state.errorMessage!,
        onRetry: controller.retry,
      );
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
              _ShiftCashPage(state: state, controller: controller),
              _StockCountPage(state: state, controller: controller),
              _PhotosPage(state: state, controller: controller),
              _NotesPage(state: state, controller: controller),
            ],
          ),
        ),
        TransactionTotalBar(
          total: state.till + state.floatAmount,
          totalLabel: 'Till + Float',
          submitting: state.submitting,
          enabled: _page < _stepTitles.length - 1 || !state.loadingPrefill,
          submitLabel: _page < _stepTitles.length - 1 ? 'Next' : 'Open Shop',
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

class _ShiftCashPage extends StatelessWidget {
  const _ShiftCashPage({required this.state, required this.controller});

  final CheckinFormState state;
  final CheckinController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionLabel('Shift'),
        const SizedBox(height: 8),
        _ShiftToggle(
          shift: state.shift,
          definitions: state.definitions,
          enabled: !state.loadingPrefill,
          onChanged: controller.setShift,
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
        if (state.loadingPrefill) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Loading expected cash…',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _StockCountPage extends StatelessWidget {
  const _StockCountPage({required this.state, required this.controller});

  final CheckinFormState state;
  final CheckinController controller;

  @override
  Widget build(BuildContext context) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionLabel('Stock Count'),
        const SizedBox(height: 8),
        if (state.loadingPrefill)
          for (var i = 0; i < 4; i++) ...[
            const _SkeletonStockRow(),
            const SizedBox(height: 8),
          ]
        else if (state.stockCounts.isEmpty)
          Text(
            'No stock count items for this shift.',
            style: TextStyle(color: onSurfaceVariant, fontSize: 13),
          )
        else
          for (var i = 0; i < state.stockCounts.length; i++) ...[
            _StockCountRow(
              // Keyed by shift too: switching shifts re-fetches the
              // prefill with new expected quantities, and the field needs
              // a fresh element (not a reused one holding the previous
              // shift's typed text) to pick that up.
              key: ValueKey('${state.shift}-${state.stockCounts[i].stockId}'),
              entry: state.stockCounts[i],
              onChanged: (qty) => controller.updateActualQty(i, qty),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _PhotosPage extends StatelessWidget {
  const _PhotosPage({required this.state, required this.controller});

  final CheckinFormState state;
  final CheckinController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionLabel('Photos'),
        const SizedBox(height: 8),
        Row(
          children: [
            if (state.loadingPrefill)
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                const Expanded(child: _SkeletonPhotoTile()),
              ]
            else
              for (var i = 0; i < state.photoSlots.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: _PhotoTile(
                    slot: state.photoSlots[i],
                    photo: state.photos[state.photoSlots[i].key],
                    onTap: () =>
                        controller.capturePhoto(state.photoSlots[i].key),
                  ),
                ),
              ],
          ],
        ),
      ],
    );
  }
}

class _NotesPage extends StatelessWidget {
  const _NotesPage({required this.state, required this.controller});

  final CheckinFormState state;
  final CheckinController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionLabel('Notes'),
        const SizedBox(height: 8),
        TextFormField(
          key: const ValueKey('calls_deliveries'),
          initialValue: state.callsDeliveries,
          decoration: const InputDecoration(
            labelText: 'Calls / deliveries',
            hintText: 'Anything expected today?',
          ),
          maxLines: 2,
          onChanged: controller.setCallsDeliveries,
        ),
        const SizedBox(height: 10),
        TextFormField(
          key: const ValueKey('pending_orders'),
          initialValue: state.pendingOrders,
          decoration: const InputDecoration(
            labelText: 'Pending orders',
          ),
          maxLines: 2,
          onChanged: controller.setPendingOrders,
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

class _ShiftToggle extends StatelessWidget {
  const _ShiftToggle({
    required this.shift,
    required this.definitions,
    required this.enabled,
    required this.onChanged,
  });

  final String shift;
  final List<ShiftDefinition> definitions;
  final bool enabled;
  final ValueChanged<String> onChanged;

  ShiftDefinition? _definitionFor(String key) {
    for (final d in definitions) {
      if (d.key == key) return d;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final keys = definitions.isNotEmpty
        ? definitions.map((d) => d.key).toList()
        : const ['morning', 'evening'];

    return Row(
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _ShiftChip(
              selected: keys[i] == shift,
              label: _definitionFor(keys[i])?.name ??
                  '${keys[i][0].toUpperCase()}${keys[i].substring(1)}',
              hours: _definitionFor(keys[i]) == null
                  ? null
                  : '${_definitionFor(keys[i])!.start} — ${_definitionFor(keys[i])!.end}',
              onTap: enabled ? () => onChanged(keys[i]) : null,
            ),
          ),
        ],
      ],
    );
  }
}

class _ShiftChip extends StatelessWidget {
  const _ShiftChip({
    required this.selected,
    required this.label,
    required this.hours,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final String? hours;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryGreen.withValues(alpha: 0.14)
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.primaryGreen
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.primaryGreen : null,
              ),
            ),
            if (hours != null) ...[
              const SizedBox(height: 2),
              Text(
                hours!,
                style: TextStyle(fontSize: 11, color: onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StockCountRow extends StatelessWidget {
  const _StockCountRow({super.key, required this.entry, required this.onChanged});

  final StockCountEntry entry;
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
                key: ValueKey('qty-${entry.stockId}'),
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

class _SkeletonBox extends StatefulWidget {
  const _SkeletonBox({
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06);
    final peak = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(base, peak, _controller.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

class _SkeletonStockRow extends StatelessWidget {
  const _SkeletonStockRow();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            const Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBox(width: 110, height: 13),
                  SizedBox(height: 6),
                  _SkeletonBox(width: 70, height: 10),
                ],
              ),
            ),
            const _SkeletonBox(width: 90, height: 34, borderRadius: 8),
          ],
        ),
      ),
    );
  }
}

class _SkeletonPhotoTile extends StatelessWidget {
  const _SkeletonPhotoTile();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: _SkeletonBox(
        width: double.infinity,
        height: double.infinity,
        borderRadius: 12,
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.slot,
    required this.photo,
    required this.onTap,
  });

  final PhotoSlotSpec slot;
  final PhotoSlotState? photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    final uploading = photo?.uploading ?? false;
    final uploaded = photo?.isUploaded ?? false;
    final error = photo?.error;
    final bytes = photo?.bytes;

    return GestureDetector(
      onTap: uploading ? null : onTap,
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
            border: Border.all(
              color: error != null
                  ? AppColors.errorRed
                  : uploaded
                      ? AppColors.primaryGreen
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (bytes != null)
                Image.memory(bytes, fit: BoxFit.cover)
              else
                Center(
                  child: Icon(
                    Icons.camera_alt_outlined,
                    color: onSurfaceVariant,
                    size: 26,
                  ),
                ),
              if (uploading)
                const ColoredBox(
                  color: Color(0x66000000),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              if (uploaded && !uploading)
                const Positioned(
                  top: 4,
                  right: 4,
                  child: Icon(Icons.check_circle, color: AppColors.primaryGreen, size: 18),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  color: const Color(0x99000000),
                  child: Text(
                    error != null ? 'Retry' : slot.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadErrorView extends StatelessWidget {
  const _LoadErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48, color: AppColors.errorRed),
            const SizedBox(height: 16),
            Text(
              'Could not load Open Shop',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
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
            const Icon(Icons.storefront, size: 48, color: AppColors.primaryGreen),
            const SizedBox(height: 16),
            Text(
              'Shop already open',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              status == null
                  ? 'A shift is currently open for this store.'
                  : '${status!.shift[0].toUpperCase()}${status!.shift.substring(1)} shift'
                      '${status!.openedAt != null ? ' · opened ${status!.openedAt}' : ''}',
              textAlign: TextAlign.center,
              style: TextStyle(color: onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => context.go(AppRoutes.dashboard),
              child: const Text('Continue to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}
