import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shell/main_shell.dart';
import '../application/auth_provider.dart';
import 'login_screen.dart';
import 'verify_email_screen.dart';

/// Shows the login screen when signed out, the app when signed in.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);

    return auth.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Something went wrong: $e')),
      ),
      data: (user) {
        if (user == null) return const LoginScreen();
        if (!user.emailVerified) return VerifyEmailScreen(user: user);
        return const MainShell();
      },
    );
  }
}