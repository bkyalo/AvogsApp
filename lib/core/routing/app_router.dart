import 'package:avogs/core/auth/auth_models.dart';
import 'package:avogs/core/auth/auth_repository.dart';
import 'package:avogs/core/config/app_config_provider.dart';
import 'package:avogs/core/responsive/adaptive_scaffold.dart';
import 'package:avogs/core/routing/app_routes.dart';
import 'package:avogs/features/auth/presentation/fa_login_screen.dart';
import 'package:avogs/features/auth/presentation/pin_setup_screen.dart';
import 'package:avogs/features/auth/presentation/pin_unlock_screen.dart';
import 'package:avogs/features/dashboard/presentation/dashboard_screen.dart';
import 'package:avogs/features/history/application/history_provider.dart';
import 'package:avogs/features/history/presentation/history_screen.dart';
import 'package:avogs/features/inventory/inventory_repository.dart';
import 'package:avogs/features/inventory/presentation/adjustment_screen.dart';
import 'package:avogs/features/inventory/presentation/stock_balances_screen.dart';
import 'package:avogs/features/master_data/master_data_repository.dart';
import 'package:avogs/features/payments/presentation/payment_screen.dart';
import 'package:avogs/features/purchasing/presentation/supplier_invoice_screen.dart';
import 'package:avogs/features/reports/reports_repository.dart';
import 'package:avogs/features/sales/presentation/pos_screen.dart';
import 'package:avogs/features/services/presentation/services_screen.dart';
import 'package:avogs/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Stable listenable for GoRouter — avoids recreating the router on auth changes.
final routerRefreshListenableProvider = Provider<Listenable>((ref) {
  final notifier = _RouterRefreshNotifier();
  ref.listen(authControllerProvider, (_, __) => notifier.notify());
  ref.onDispose(notifier.dispose);
  return notifier;
});

final routerProvider = Provider<GoRouter>((ref) {
  final refreshListenable = ref.watch(routerRefreshListenableProvider);

  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final status = ref.read(authControllerProvider).status;
      final path = state.matchedLocation;
      final isAuthRoute = path == AppRoutes.login ||
          path == AppRoutes.pinSetup ||
          path == AppRoutes.pinUnlock;

      if (status == AuthStatus.unknown) return null;

      if (status == AuthStatus.unauthenticated) {
        return path == AppRoutes.login ? null : AppRoutes.login;
      }
      if (status == AuthStatus.needsPinSetup) {
        return path == AppRoutes.pinSetup ? null : AppRoutes.pinSetup;
      }
      if (status == AuthStatus.locked) {
        return path == AppRoutes.pinUnlock ? null : AppRoutes.pinUnlock;
      }
      if (status == AuthStatus.authenticated && isAuthRoute) {
        return AppRoutes.dashboard;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const FaLoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.pinSetup,
        builder: (_, __) => const PinSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.pinUnlock,
        builder: (_, __) => const PinUnlockScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(
            location: state.matchedLocation,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (_, __) => const DashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.services,
            builder: (_, __) => const ServicesScreen(),
          ),
          GoRoute(
            path: AppRoutes.salesNew,
            builder: (_, __) => const PosScreen(),
          ),
          GoRoute(
            path: AppRoutes.paymentsNew,
            builder: (_, __) => const PaymentScreen(),
          ),
          GoRoute(
            path: AppRoutes.purchasingNew,
            builder: (_, __) => const SupplierInvoiceScreen(),
          ),
          GoRoute(
            path: AppRoutes.inventoryBalances,
            builder: (_, __) => const StockBalancesScreen(),
          ),
          GoRoute(
            path: AppRoutes.inventoryAdjust,
            builder: (_, __) => const AdjustmentScreen(),
          ),
          GoRoute(
            path: AppRoutes.history,
            builder: (_, __) => const HistoryScreen(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (_, __) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});

void _refreshShellTab(WidgetRef ref, int index) {
  switch (index) {
    case 0:
      ref.invalidate(todaySalesSummaryProvider);
      ref.invalidate(salesTrendProvider);
      break;
    case 1:
      ref.invalidate(inventoryBalancesProvider);
      break;
    case 2:
      ref.invalidate(historyEntriesProvider);
      ref.invalidate(shadowSalesProvider);
      break;
    case 3:
      ref.invalidate(storesProvider);
      break;
  }
}

String _titleForLocation(String location) {
  if (location.startsWith('/services')) return 'Services';
  if (location.startsWith('/sales')) return 'Direct Sale';
  if (location.startsWith('/payments')) return 'Customer Payment';
  if (location.startsWith('/purchasing')) return 'Supplier Invoice';
  if (location.startsWith('/inventory/balances')) return 'Stock Balances';
  if (location.startsWith('/inventory')) return 'Stock Adjustment';
  if (location.startsWith('/history')) return 'Activity';
  if (location.startsWith('/settings')) return 'Account';
  return 'Home';
}

class _RouterRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.location,
    required this.child,
  });

  final String location;
  final Widget child;

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.grid_view_outlined),
      selectedIcon: Icon(Icons.grid_view),
      label: 'Services',
    ),
    NavigationDestination(
      icon: Icon(Icons.timeline_outlined),
      selectedIcon: Icon(Icons.timeline),
      label: 'Activity',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: 'Account',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = shellIndexForLocation(location);
    final config = ref.watch(appConfigProvider);
    final storeLabel = config.selectedStoreCode ?? 'Select store';

    return AdaptiveScaffold(
      title: _titleForLocation(location),
      selectedIndex: index,
      showShellHeader: showShellHeaderForLocation(location),
      storeLabel: storeLabel,
      onHeaderRefresh: () => _refreshShellTab(ref, index),
      onDestinationSelected: (i) {
        if (i == 0) {
          ref
              .read(masterDataSyncProvider.notifier)
              .refreshCustomersAndSuppliers();
        }
        goToShellIndex(context, i);
      },
      destinations: _destinations,
      child: child,
    );
  }
}
