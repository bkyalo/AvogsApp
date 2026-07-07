import 'package:avogs/core/auth/auth_repository.dart';
import 'package:avogs/core/theme/app_colors.dart';
import 'package:avogs/shared/widgets/avogs_logo.dart';
import 'package:avogs/shared/widgets/pin_pad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PinUnlockScreen extends ConsumerStatefulWidget {
  const PinUnlockScreen({super.key});

  @override
  ConsumerState<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends ConsumerState<PinUnlockScreen> {
  String _pin = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
  }

  Future<void> _tryBiometric() async {
    final auth = ref.read(authControllerProvider);
    if (!auth.biometricEnabled) return;
    await ref.read(authControllerProvider.notifier).unlockWithBiometric();
  }

  Future<void> _onDigit(String digit) async {
    if (_pin.length >= PinPad.pinLength) return;
    setState(() => _pin += digit);
    if (_pin.length == PinPad.pinLength) {
      final ok =
          await ref.read(authControllerProvider.notifier).unlockWithPin(_pin);
      if (!ok && mounted) setState(() => _pin = '');
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AvogsLogo(),
                  const SizedBox(height: 8),
                  Text(
                    auth.user?.name ?? '',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.accentLime,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Enter PIN',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.white,
                        ),
                  ),
                  const SizedBox(height: 24),
                  PinPad(
                    pin: _pin,
                    onDigit: _onDigit,
                    onBackspace: _onBackspace,
                    errorText: auth.errorMessage,
                  ),
                  if (auth.biometricEnabled) ...[
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: _tryBiometric,
                      icon: const Icon(Icons.fingerprint, color: AppColors.accentLime),
                      label: const Text(
                        'Use biometric',
                        style: TextStyle(color: AppColors.accentLime),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
