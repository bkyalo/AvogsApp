import 'package:avogs/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class PinPad extends StatelessWidget {
  const PinPad({
    super.key,
    required this.pin,
    required this.onDigit,
    required this.onBackspace,
    this.errorText,
  });

  final String pin;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final String? errorText;

  static const pinLength = 4;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(pinLength, (index) {
            final filled = index < pin.length;
            return Container(
              width: 15,
              height: 15,
              margin: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.accentLime, width: 2),
                color: filled ? AppColors.accentLime : Colors.transparent,
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 18,
          child: Text(
            errorText ?? '',
            style: const TextStyle(color: AppColors.errorRed, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final digit in ['1', '2', '3', '4', '5', '6', '7', '8', '9'])
              _PinKey(
                label: digit,
                onTap: () => onDigit(digit),
              ),
            const SizedBox.shrink(),
            _PinKey(label: '0', onTap: () => onDigit('0')),
            _PinKey(
              icon: Icons.backspace_outlined,
              onTap: onBackspace,
            ),
          ],
        ),
      ],
    );
  }
}

class _PinKey extends StatelessWidget {
  const _PinKey({this.label, this.icon, required this.onTap});

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accentLime.withValues(alpha: 0.08),
      shape: const CircleBorder(
        side: BorderSide(color: AppColors.accentLime, width: 1.5),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Center(
          child: icon != null
              ? Icon(icon, color: AppColors.white)
              : Text(
                  label!,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}
