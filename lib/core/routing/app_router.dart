import 'package:avogs/core/auth/auth_models.dart';
import 'package:avogs/core/auth/auth_repository.dart';
import 'package:avogs/core/responsive/adaptive_scaffold.dart';
import 'package:avogs/core/routing/app_routes.dart';
import 'package:avogs/features/auth/presentation/fa_login_screen.dart';
import 'package:avogs/features/auth/presentation/pin_setup_screen.dart';
import 'package:avogs/features/auth/presentation/pin_unlock_screen.dart';
import 'package:avogs/features/dashboard/presentation/dashboard_screen.dart';
import 'package:avogs/features/history/presentation/history_screen.dart';
import 'package:avogs/features/master_data/master_data_repository.dart';
import 'package:avogs/features/services/presentation/services_screen.dart';
import 'package:avogs/features/inventory/presentation/adjustment_screen.dart';
import 'package:avogs/features/payments/presentation/payment_screen.dart';
import 'package:avogs/features/purchasing/presentation/supplier_invoice_screen.dart';
import 'package:avogs/features/sales/presentation/pos_screen.dart';
import 'package:avogs/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    refreshListenable: _AuthRefreshListenable(ref),
    redirect: (context, state) {
      final status = authState.status;
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
          final index = shellIndexForLocation(state.matchedLocation);
          return AdaptiveScaffold(
            title: _titleForLocation(state.matchedLocation),
            selectedIndex: index,
            onDestinationSelected: (i) {
              if (i == 0) {
                ref
                    .read(masterDataSyncProvider.notifier)
                    .refreshCustomersAndSuppliers();
              }
              goToShellIndex(context, i);
            },
            destinations: const [
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
            ],
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

String _titleForLocation(String location) {
  if (location.startsWith('/services')) return 'Services';
  if (location.startsWith('/sales')) return 'Direct Sale';
  if (location.startsWith('/payments')) return 'Customer Payment';
  if (location.startsWith('/purchasing')) return 'Supplier Invoice';
  if (location.startsWith('/inventory')) return 'Stock Adjustment';
  if (location.startsWith('/history')) return 'Activity';
  if (location.startsWith('/settings')) return 'Account';
  return 'Home';
}

class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable(this._ref) {
    _sub = _ref.listen(authControllerProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;
  late final ProviderSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
