import '../models/app_user.dart';

abstract class AuthRepository {
  Stream<AppUser?> authStateChanges();
  Future<void> signIn({required String email, required String password});
  Future<void> signUp({required String email, required String password});
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();
  Future<void> sendEmailVerification();
  Future<bool> refreshEmailVerified();
}

/// A user-friendly auth error, safe to show on screen.
class AuthFailure implements Exception {
  final String message;
  const AuthFailure(this.message);

  @override
  String toString() => message;
}