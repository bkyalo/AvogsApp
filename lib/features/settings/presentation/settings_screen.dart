import 'package:avogs/core/auth/auth_repository.dart';
import 'package:avogs/core/config/app_config_provider.dart';
import 'package:avogs/core/config/app_environment.dart';
import 'package:avogs/core/routing/app_routes.dart';
import 'package:avogs/core/theme/app_colors.dart';
import 'package:avogs/core/theme/app_theme.dart';
import 'package:avogs/core/theme/theme_mode_provider.dart';
import 'package:avogs/features/master_data/master_data_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final themeMode = ref.watch(themeModeProvider);
    final storesAsync = ref.watch(storesProvider);
    final auth = ref.watch(authControllerProvider);
    final canBiometric = ref.watch(canUseBiometricProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Store', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        storesAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => ListTile(
            title: const Text('Could not load stores'),
            subtitle: Text('$e'),
            trailing: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(storesProvider),
            ),
          ),
          data: (stores) {
            if (stores.isEmpty) {
              return const ListTile(
                title: Text('No stores available'),
                subtitle: Text('Check API connection'),
              );
            }
            return DropdownButtonFormField<String>(
              value: stores.any((s) => s.code == config.selectedStoreCode)
                  ? config.selectedStoreCode
                  : null,
              decoration: const InputDecoration(
                labelText: 'Active store',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final store in stores)
                  DropdownMenuItem(
                    value: store.code,
                    child: Text('${store.name} (${store.code})'),
                  ),
              ],
              onChanged: (code) async {
                if (code != null) {
                  await ref.read(appConfigProvider.notifier).setStore(code);
                }
              },
            );
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ShiftActionCard(
                icon: Icons.storefront_outlined,
                label: 'Open Shop',
                accent: AppColors.accentLime,
                onTap: () => context.go(AppRoutes.shifts),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ShiftActionCard(
                icon: Icons.storefront,
                label: 'Close Shop',
                accent: AppColors.mutedGray,
                onTap: () => context.go(AppRoutes.shiftClose),
              ),
            ),
          ],
        ),
        const Divider(height: 32),
        Text('Environment', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...AppEnvironment.values.map(
          (env) => RadioListTile<AppEnvironment>(
            value: env,
            groupValue: config.environment,
            title: Text(env.label),
            subtitle: Text(env.baseUrl),
            onChanged: (value) {
              if (value != null) {
                ref.read(appConfigProvider.notifier).setEnvironment(value);
              }
            },
          ),
        ),
        if (config.environment == AppEnvironment.local) ...[
          const SizedBox(height: 8),
          Text(
            'Local uses localhost:8090. On a USB-connected phone, run: adb reverse tcp:8090 tcp:8090',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
        const Divider(height: 32),
        Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...ThemeMode.values.map(
          (mode) => RadioListTile<ThemeMode>(
            value: mode,
            groupValue: themeMode,
            title: Text(switch (mode) {
              ThemeMode.system => 'System',
              ThemeMode.light => 'Light',
              ThemeMode.dark => 'Dark',
            }),
            onChanged: (value) {
              if (value != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ref.read(themeModeProvider.notifier).setThemeMode(value);
                });
              }
            },
          ),
        ),
        const Divider(height: 32),
        Text('Security', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        canBiometric.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (available) => available
              ? SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.fingerprint),
                  title: const Text('Biometric unlock'),
                  subtitle: const Text(
                    'Use fingerprint or face instead of your PIN',
                  ),
                  value: auth.biometricEnabled,
                  onChanged: (enabled) async {
                    final ok = await ref
                        .read(authControllerProvider.notifier)
                        .setBiometricEnabled(enabled);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Biometric confirmation failed — unlock is still off',
                          ),
                        ),
                      );
                    }
                  },
                )
              : Text(
                  'Biometric unlock is not available on this device — no fingerprint or face is enrolled.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
        ),
        const Divider(height: 32),
        FilledButton.tonal(
          style: FilledButton.styleFrom(
            textStyle: AppTheme.filledButtonTextStyle,
          ),
          onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          child: const Text('Sign out'),
        ),
      ],
    );
  }
}

/// Small, compact shift-action card — deliberately lighter-weight than the
/// Services grid cards these replaced (single line, no description) since
/// this is now a secondary entry point on the Account screen, not the
/// primary one.
class _ShiftActionCard extends StatelessWidget {
  const _ShiftActionCard({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE8E4DC);

    return Material(
      color: isDark ? const Color(0xFF162B1E) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: accent, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: onSurface,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
