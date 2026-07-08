import 'package:avogs/core/responsive/breakpoints.dart';
import 'package:avogs/core/theme/app_colors.dart';
import 'package:avogs/shared/widgets/app_bottom_nav.dart';
import 'package:avogs/shared/widgets/app_shell_header.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdaptiveScaffold extends StatefulWidget {
  const AdaptiveScaffold({
    super.key,
    required this.title,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.child,
    this.actions,
    this.storeLabel = 'Store',
    this.isRefreshing = false,
    this.onHeaderRefresh,
    this.showShellHeader = true,
  });

  final String title;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;
  final Widget child;
  final List<Widget>? actions;
  final String storeLabel;
  final bool isRefreshing;
  final VoidCallback? onHeaderRefresh;
  final bool showShellHeader;

  @override
  State<AdaptiveScaffold> createState() => _AdaptiveScaffoldState();
}

class _AdaptiveScaffoldState extends State<AdaptiveScaffold> {
  var _railExtended = true;

  static const _navIcons = <(IconData, IconData)>[
    (Icons.home_outlined, Icons.home),
    (Icons.grid_view_outlined, Icons.grid_view),
    (Icons.timeline_outlined, Icons.timeline),
    (Icons.person_outline, Icons.person),
  ];

  @override
  Widget build(BuildContext context) {
    final layout = layoutSizeOf(context);
    final canPop = GoRouter.of(context).canPop();
    final bottomDestinations = [
      for (var i = 0; i < widget.destinations.length; i++)
        (
          icon: _navIcons[i].$1,
          selectedIcon: _navIcons[i].$2,
          label: widget.destinations[i].label,
        ),
    ];

    if (layout == LayoutSize.expanded) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: _railExtended,
              selectedIndex: widget.selectedIndex,
              onDestinationSelected: widget.onDestinationSelected,
              leading: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  "AVO'Gs",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.accentLime,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              destinations: [
                for (final d in widget.destinations)
                  NavigationRailDestination(
                    icon: d.icon,
                    selectedIcon: d.selectedIcon ?? d.icon,
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  if (widget.showShellHeader)
                    AppShellHeader(
                      storeLabel: widget.storeLabel,
                      isRefreshing: widget.isRefreshing,
                      onRefresh: widget.onHeaderRefresh,
                    )
                  else
                    _TopBar(
                      title: widget.title,
                      actions: widget.actions,
                      canPop: canPop,
                      onBack: canPop ? () => context.pop() : null,
                    ),
                  Expanded(child: widget.child),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          if (widget.showShellHeader)
            AppShellHeader(
              storeLabel: widget.storeLabel,
              isRefreshing: widget.isRefreshing,
              onRefresh: widget.onHeaderRefresh,
            )
          else
            AppBar(
              title: Text(widget.title),
              actions: widget.actions,
              automaticallyImplyLeading: canPop,
              leading: canPop
                  ? BackButton(onPressed: () => context.pop())
                  : null,
            ),
          Expanded(child: widget.child),
          AppBottomNav(
            selectedIndex: widget.selectedIndex,
            onDestinationSelected: widget.onDestinationSelected,
            destinations: bottomDestinations,
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    this.actions,
    this.canPop = false,
    this.onBack,
  });

  final String title;
  final List<Widget>? actions;
  final bool canPop;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryDark,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (canPop && onBack != null) ...[
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back, color: AppColors.white),
                  tooltip: 'Back',
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.white,
                      ),
                ),
              ),
              ...?actions,
            ],
          ),
        ),
      ),
    );
  }
}

int shellIndexForLocation(String location) {
  if (location.startsWith('/services') ||
      location.startsWith('/sales') ||
      location.startsWith('/payments') ||
      location.startsWith('/purchasing') ||
      location.startsWith('/inventory')) {
    return 1;
  }
  if (location.startsWith('/history')) return 2;
  if (location.startsWith('/settings')) return 3;
  return 0;
}

bool showShellHeaderForLocation(String location) {
  return location == '/dashboard' ||
      location == '/services' ||
      location == '/history' ||
      location == '/settings';
}

void goToShellIndex(BuildContext context, int index) {
  switch (index) {
    case 0:
      context.go('/dashboard');
      break;
    case 1:
      context.go('/services');
      break;
    case 2:
      context.go('/history');
      break;
    case 3:
      context.go('/settings');
      break;
    default:
      context.go('/dashboard');
  }
}
