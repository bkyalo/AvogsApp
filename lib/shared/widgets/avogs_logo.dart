import 'package:avogs/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class AvogsLogo extends StatelessWidget {
  const AvogsLogo({
    super.key,
    this.large = false,
    this.onDark = true,
  });

  final bool large;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: large ? 4 : 2,
          color: onDark ? AppColors.white : AppColors.primaryDark,
        );

    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: const [
          TextSpan(text: 'AVO'),
          TextSpan(
            text: "'Gs",
            style: TextStyle(color: AppColors.accentLime),
          ),
        ],
      ),
    );
  }
}
