import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendly_android/app.dart';

void main() {
  testWidgets('add a transaction and see it in the list', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SpendlyApp()));

    expect(find.text('No transactions yet'), findsOneWidget);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '1500');
    await tester.ensureVisible(find.text('Save transaction'));
    await tester.tap(find.text('Save transaction'));
    await tester.pumpAndSettle();

    expect(find.text('No transactions yet'), findsNothing);
    expect(find.text('Food'), findsOneWidget);
  });
}