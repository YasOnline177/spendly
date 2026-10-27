import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendly_android/data/models/app_user.dart';
import 'package:spendly_android/features/auth/application/auth_provider.dart';
import 'package:spendly_android/features/auth/presentation/auth_gate.dart';

import '../../helpers/fake_auth_repository.dart';

Widget _app(FakeAuthRepository repo) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
    child: const MaterialApp(home: AuthGate()),
  );
}

void main() {
  testWidgets('signed-out user sees the login screen', (tester) async {
    await tester.pumpWidget(_app(FakeAuthRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('unverified user is held on the verify screen', (tester) async {
    await tester.pumpWidget(
      _app(
        FakeAuthRepository(
          user: const AppUser(uid: 'u1', email: 'new@example.com'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Verify your email'), findsOneWidget);
    expect(find.text('new@example.com'), findsOneWidget);
  });

  testWidgets('tapping verified while still unverified shows a hint',
      (tester) async {
    await tester.pumpWidget(
      _app(
        FakeAuthRepository(
          user: const AppUser(uid: 'u1', email: 'new@example.com'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("I've verified my email"));
    await tester.pumpAndSettle();

    expect(
      find.text('Not verified yet. Check your inbox and spam folder.'),
      findsOneWidget,
    );
  });
}