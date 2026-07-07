import 'package:avogs/core/auth/auth_models.dart';
import 'package:avogs/core/auth/auth_repository.dart';
import 'package:avogs/core/routing/app_router.dart';
import 'package:avogs/core/theme/app_theme.dart';
import 'package:avogs/core/theme/theme_mode_provider.dart';
import 'package:avogs/shared/widgets/avogs_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AvogsApp extends ConsumerWidget {
  const AvogsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
