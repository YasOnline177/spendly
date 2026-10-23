import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendly_android/app.dart';

void main() {
  testWidgets('shows app title and transactions', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SpendlyApp()));

    expect(find.text('Spendly'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
  });
}