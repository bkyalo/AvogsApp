import 'package:avogs/core/auth/auth_models.dart';
import 'package:avogs/core/routing/app_router.dart';
import 'package:avogs/core/theme/app_theme.dart';
import 'package:avogs/core/theme/theme_mode_provider.dart';
import 'package:avogs/core/auth/auth_repository.dart';
import 'package:avogs/shared/widgets/avogs_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AvogsApp extends ConsumerWidget {
  const AvogsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final themeMode = ref.watch(themeModeProvider);

    if (auth.status == AuthStatus.unknown) {
      return MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        debugShowCheckedModeBanner: false,
        home: const AvogsSplash(),
      );
    }

    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: "AVO'Gs",
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
