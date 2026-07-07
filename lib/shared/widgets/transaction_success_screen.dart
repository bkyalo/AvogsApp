import 'package:avogs/core/theme/app_colors.dart';
import 'package:avogs/core/utils/formatters.dart';
import 'package:avogs/shared/models/transaction_models.dart';
import 'package:flutter/material.dart';

class TransactionSuccessScreen extends StatelessWidget {
  const TransactionSuccessScreen({
    super.key,
    required this.details,
  });

  final TransactionSuccessDetails details;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Success')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          const Icon(
            Icons.check_circle,
            size: 64,
            color: AppColors.primaryGreen,
          ),
          const SizedBox(height: 16),
          Text(
            details.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryGreen,
                ),
          ),
          const SizedBox(height: 16),
          if (details.queuedOffline)
            const Card(
              child: ListTile(
                leading: Icon(Icons.cloud_upload, color: AppColors.honey),
                title: Text('Queued offline'),
                subtitle: Text('Will sync when connection is restored.'),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    details.reference,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  if (details.subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(details.subtitle!),
                  ],
                  for (final line in details.detailLines) ...[
                    const SizedBox(height: 4),
                    Text(line),
                  ],
                  if (details.total != null) ...[
                    const Divider(height: 24),
                    Row(
                      children: [
                        Text(
                          details.totalLabel,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        Text(
                          formatMoney(details.total!),
                          style:
                              Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryGreen,
                                  ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

Future<void> showTransactionSuccess(
  BuildContext context,
  TransactionSuccessDetails details,
) {
  return Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) => TransactionSuccessScreen(details: details),
    ),
  );
}
