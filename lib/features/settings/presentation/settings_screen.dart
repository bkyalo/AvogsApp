import 'package:avogs/core/auth/auth_repository.dart';
import 'package:avogs/core/config/app_config_provider.dart';
import 'package:avogs/core/config/app_environment.dart';
import 'package:avogs/core/theme/theme_mode_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final themeMode = ref.watch(themeModeProvider);

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
            title: Text(mode.name),
            onChanged: (value) {
              if (value != null) {
                ref.read(themeModeProvider.notifier).setThemeMode(value);
              }
            },
          ),
        ),
        const Divider(height: 32),
        ListTile(
          title: const Text('Store code'),
          subtitle: Text(config.selectedStoreCode ?? 'Not set'),
          trailing: const Icon(Icons.edit),
          onTap: () => _editStoreCode(context, ref, config.selectedStoreCode),
        ),
        const Divider(height: 32),
        FilledButton.tonal(
          onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          child: const Text('Sign out'),
        ),
      ],
    );
  }

  Future<void> _editStoreCode(
    BuildContext context,
    WidgetRef ref,
    String? current,
  ) async {
    final controller = TextEditingController(text: current ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Store code'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'e.g. DEF'),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await ref.read(appConfigProvider.notifier).setStore(result);
    }
  }
}
