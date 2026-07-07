import 'package:avogs/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<({IconData icon, IconData selectedIcon, String label})> destinations;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF122419) : AppColors.white;
    final borderColor = isDark
        ? AppColors.white.withValues(alpha: 0.12)
        : const Color(0xFFE8E4DC);
    final selectedColor = isDark ? AppColors.accentLime : AppColors.primaryDark;
    final unselectedColor = isDark
        ? AppColors.mutedGray
        : const Color(0xFF5E5E54);

    return Material(
      color: background,
      child: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: borderColor)),
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 10),
            child: Row(
              children: [
                for (var i = 0; i < destinations.length; i++)
                  Expanded(
                    child: InkWell(
                      onTap: () => onDestinationSelected(i),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            selectedIndex == i
                                ? destinations[i].selectedIcon
                                : destinations[i].icon,
                            size: 22,
                            color: selectedIndex == i
                                ? selectedColor
                                : unselectedColor.withValues(alpha: 0.75),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            destinations[i].label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: selectedIndex == i
                                  ? selectedColor
                                  : unselectedColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
