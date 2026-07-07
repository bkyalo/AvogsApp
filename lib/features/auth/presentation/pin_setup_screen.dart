import 'package:avogs/core/auth/auth_repository.dart';
import 'package:avogs/core/theme/app_colors.dart';
import 'package:avogs/shared/widgets/avogs_logo.dart';
import 'package:avogs/shared/widgets/pin_pad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  String _pin = '';
  String _confirmPin = '';
  var _confirming = false;
  var _enableBiometric = false;
  var _canUseBiometric = false;

  @override
  void initState() {
    super.initState();
    _loadBiometric();
  }

  Future<void> _loadBiometric() async {
    final canUse = await ref.read(authRepositoryProvider).canUseBiometric();
    if (mounted) setState(() => _canUseBiometric = canUse);
  }

  void _onDigit(String digit) {
    setState(() {
      if (!_confirming) {
        if (_pin.length < PinPad.pinLength) _pin += digit;
        if (_pin.length == PinPad.pinLength) _confirming = true;
      } else {
        if (_confirmPin.length < PinPad.pinLength) _confirmPin += digit;
        if (_confirmPin.length == PinPad.pinLength) _finish();
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (_confirming) {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        } else {
          _confirming = false;
        }
      } else if (_pin.isNotEmpty) {
        _pin = _pin.substring(0, _pin.length - 1);
      }
    });
  }

  Future<void> _finish() async {
    if (_pin != _confirmPin) {
      setState(() {
        _pin = '';
        _confirmPin = '';
        _confirming = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PINs do not match. Try again.')),
        );
      }
      return;
    }

    await ref.read(authControllerProvider.notifier).completePinSetup(
          _pin,
          enableBiometric: _enableBiometric,
        );
  }

  @override
  Widget build(BuildContext context) {
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
                  const SizedBox(height: 16),
                  Text(
                    _confirming ? 'Confirm your PIN' : 'Create a 4-digit PIN',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.white,
                        ),
                  ),
                  const SizedBox(height: 24),
                  PinPad(
                    pin: _confirming ? _confirmPin : _pin,
                    onDigit: _onDigit,
                    onBackspace: _onBackspace,
                  ),
                  if (_canUseBiometric && !_confirming) ...[
                    const SizedBox(height: 24),
                    SwitchListTile(
                      value: _enableBiometric,
                      onChanged: (v) => setState(() => _enableBiometric = v),
                      title: const Text(
                        'Enable biometric unlock',
                        style: TextStyle(color: AppColors.white),
                      ),
                      activeThumbColor: AppColors.accentLime,
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
