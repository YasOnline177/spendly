import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendly_android/data/repositories/auth_repository.dart';
import 'package:spendly_android/features/auth/application/auth_provider.dart';
import 'package:spendly_android/features/auth/presentation/login_screen.dart';

import '../../helpers/fake_auth_repository.dart';

Widget _app(FakeAuthRepository repo) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
    child: const MaterialApp(home: LoginScreen()),
  );
}

void main() {
  testWidgets('shows validation errors when fields are empty', (tester) async {
    await tester.pumpWidget(_app(FakeAuthRepository()));

    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });

  testWidgets('shows the error message when sign in fails', (tester) async {
    await tester.pumpWidget(
      _app(
        FakeAuthRepository(
          signInError: const AuthFailure('Wrong email or password.'),
        ),
      ),
    );

    await tester.enterText(
        find.byType(TextFormField).at(0), 'me@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Wrong email or password.'), findsOneWidget);
  });

  testWidgets('can switch to the create-account form', (tester) async {
    await tester.pumpWidget(_app(FakeAuthRepository()));

    await tester.ensureVisible(find.text('New here? Create an account'));
    await tester.tap(find.text('New here? Create an account'));
    await tester.pump();

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });
}