import 'dart:async';

import 'package:avogs/core/theme/app_colors.dart';
import 'package:avogs/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppShellHeader extends StatefulWidget {
  const AppShellHeader({
    super.key,
    required this.storeLabel,
    this.isRefreshing = false,
    this.onRefresh,
  });

  final String storeLabel;
  final bool isRefreshing;
  final VoidCallback? onRefresh;

  @override
  State<AppShellHeader> createState() => _AppShellHeaderState();
}

class _AppShellHeaderState extends State<AppShellHeader> {
  late Timer _clock;
  var _time = '';

  @override
  void initState() {
    super.initState();
    _tick();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    final t = DateFormat('hh:mm a').format(DateTime.now());
    if (t != _time) setState(() => _time = t);
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final isMorning = hour < 14;
    final shiftColor = isMorning ? AppColors.accentLime : AppColors.infoBlue;

    return Material(
      color: AppColors.primaryDark,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.white,
                      ),
                      children: [
                        TextSpan(text: 'AVO'),
                        TextSpan(
                          text: "'Gs",
                          style: TextStyle(color: AppColors.accentLime),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    widget.storeLabel,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: shiftColor.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isMorning ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined,
                      color: AppColors.white,
                      size: 13,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isMorning ? 'Morning' : 'Evening',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(_time, style: AppTheme.mono(size: 12, color: AppColors.white)),
              if (widget.onRefresh != null) ...[
                const SizedBox(width: 4),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: widget.isRefreshing
                      ? const Padding(
                          padding: EdgeInsets.all(7),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accentLime,
                          ),
                        )
                      : IconButton(
                          onPressed: widget.onRefresh,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Refresh',
                          icon: const Icon(
                            Icons.refresh,
                            color: AppColors.accentLime,
                            size: 20,
                          ),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
