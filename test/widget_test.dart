import 'package:avogs/app.dart';
import 'package:avogs/shared/widgets/avogs_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('shows avocado splash while auth bootstraps', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: AvogsApp(),
      ),
    );

    expect(find.byType(AvogsSplash), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
}
