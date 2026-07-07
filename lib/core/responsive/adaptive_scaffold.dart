import 'package:avogs/core/responsive/breakpoints.dart';
import 'package:avogs/core/theme/app_colors.dart';
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
  });

  final String title;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;
  final Widget child;
  final List<Widget>? actions;

  @override
  State<AdaptiveScaffold> createState() => _AdaptiveScaffoldState();
}

class _AdaptiveScaffoldState extends State<AdaptiveScaffold> {
  var _railExtended = true;

  @override
  Widget build(BuildContext context) {
    final layout = layoutSizeOf(context);

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
                  _TopBar(
                    title: widget.title,
                    actions: widget.actions,
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
      appBar: AppBar(
        title: Text(widget.title),
        actions: widget.actions,
      ),
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.selectedIndex,
        onDestinationSelected: widget.onDestinationSelected,
        destinations: widget.destinations,
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, this.actions});

  final String title;
  final List<Widget>? actions;

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

void goToShellIndex(BuildContext context, int index) {
  switch (index) {
    case 0:
      context.go('/dashboard');
    case 1:
      context.go('/services');
    case 2:
      context.go('/history');
    case 3:
      context.go('/settings');
    default:
      context.go('/dashboard');
  }
}
