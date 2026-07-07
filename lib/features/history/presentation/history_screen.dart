import 'package:avogs/shared/widgets/feature_placeholder.dart';
import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: 'Transaction History',
      description:
          'Phase C: searchable list of synced sales, payments, purchases, adjustments.',
      icon: Icons.history,
    );
  }
}
