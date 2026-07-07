import 'package:avogs/core/auth/auth_repository.dart';
import 'package:avogs/core/theme/app_colors.dart';
import 'package:avogs/shared/widgets/avogs_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FaLoginScreen extends ConsumerStatefulWidget {
  const FaLoginScreen({super.key});

  @override
  ConsumerState<FaLoginScreen> createState() => _FaLoginScreenState();
}

class _FaLoginScreenState extends ConsumerState<FaLoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  var _loading = false;
  var _obscure = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    await ref.read(authControllerProvider.notifier).login(
          identifier: _identifierController.text.trim(),
          password: _passwordController.text,
        );
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AvogsLogo(large: true),
                  const SizedBox(height: 8),
                  Text(
                    'RETAIL OPERATIONS',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.accentLime,
                          letterSpacing: 3,
                        ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _identifierController,
                    style: const TextStyle(color: AppColors.white),
                    decoration: InputDecoration(
                      labelText: 'Username',
                      labelStyle: TextStyle(
                        color: AppColors.white.withValues(alpha: 0.8),
                      ),
                      filled: true,
                      fillColor: AppColors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscure,
                    style: const TextStyle(color: AppColors.white),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: TextStyle(
                        color: AppColors.white.withValues(alpha: 0.8),
                      ),
                      filled: true,
                      fillColor: AppColors.white.withValues(alpha: 0.08),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off,
                          color: AppColors.accentLime,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _loading ? null : _submit(),
                  ),
                  if (auth.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      auth.errorMessage!,
                      style: const TextStyle(color: AppColors.errorRed),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Sign in'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
