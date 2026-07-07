import 'package:avogs/app.dart';
import 'package:avogs/core/notifications/shift_reminder_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Awaited before runApp so the tap-callback and launch-details plumbing
  // in app.dart always has an initialized plugin to talk to — the shift-end
  // reminder itself isn't scheduled until much later (on check-in success).
  await ShiftReminderService.instance.initialize();
  runApp(
    const ProviderScope(
      child: AvogsApp(),
    ),
  );
}
