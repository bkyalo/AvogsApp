import 'package:avogs/core/auth/auth_models.dart';
import 'package:avogs/core/auth/auth_repository.dart';
import 'package:avogs/core/notifications/shift_reminder_service.dart';
import 'package:avogs/core/routing/app_router.dart';
import 'package:avogs/core/routing/app_routes.dart';
import 'package:avogs/core/theme/app_theme.dart';
import 'package:avogs/core/theme/theme_mode_provider.dart';
import 'package:avogs/shared/widgets/avogs_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AvogsApp extends ConsumerStatefulWidget {
  const AvogsApp({super.key});

  @override
  ConsumerState<AvogsApp> createState() => _AvogsAppState();
}

class _AvogsAppState extends ConsumerState<AvogsApp> {
  bool _checkedLaunchPayload = false;

  @override
  void initState() {
    super.initState();
    // Reassigned on every rebuild that reaches here (harmless — same
    // closure shape) so it's always pointed at a live router, but set here
    // once up front so a tap that arrives before the first build still has
    // somewhere to go.
    ShiftReminderService.instance.onNotificationTap = _handleNotificationTap;

    // Cold-launch-by-notification-tap case: the router/provider tree isn't
    // guaranteed ready during initState, so check after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkLaunchPayload());
  }

  Future<void> _checkLaunchPayload() async {
    if (_checkedLaunchPayload) return;
    _checkedLaunchPayload = true;
    final payload = await ShiftReminderService.instance.consumeLaunchPayload();
    if (payload != null && mounted) _handleNotificationTap(payload);
  }

  void _handleNotificationTap(String payload) {
    if (payload != ShiftReminderService.shiftCloseTapPayload) return;
    if (!mounted) return;
    // If staff aren't authenticated/checked-in, the router's own redirect
    // logic takes over from here (bounces to login, etc.) — this is just a
    // navigation hint, not a bypass of any gating.
    ref.read(routerProvider).go(AppRoutes.shiftClose);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    if (auth.status == AuthStatus.unknown) {
      return const _ThemedApp(home: AvogsSplash());
    }

    return _ThemedApp(router: ref.read(routerProvider));
  }
}

class _ThemedApp extends ConsumerWidget {
  const _ThemedApp({this.home, this.router})
      : assert(home != null || router != null);

  final Widget? home;
  final GoRouter? router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    if (router != null) {
      return MaterialApp.router(
        title: "AVO'Gs",
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        themeAnimationDuration: Duration.zero,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      );
    }

    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      themeAnimationDuration: Duration.zero,
      debugShowCheckedModeBanner: false,
      home: home,
    );
  }
}
