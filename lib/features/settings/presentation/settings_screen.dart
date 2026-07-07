import 'package:avogs/core/auth/auth_repository.dart';
import 'package:avogs/core/config/app_config_provider.dart';
import 'package:avogs/core/config/app_environment.dart';
import 'package:avogs/core/theme/app_theme.dart';
import 'package:avogs/core/theme/theme_mode_provider.dart';
import 'package:avogs/features/master_data/master_data_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final themeMode = ref.watch(themeModeProvider);
    final storesAsync = ref.watch(storesProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
