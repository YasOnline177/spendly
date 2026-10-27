import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import 'auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository([FirebaseAuth? auth])
      : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  Stream<AppUser?> authStateChanges() {
    return _auth.authStateChanges().map(
          (u) => u == null ? null : AppUser(uid: u.uid, email: u.email, emailVerified: u.emailVerified),
        );
  }

  @override
  Future<void> signIn({required String email, required String password}) {
    return _guard(
      () => _auth.signInWithEmailAndPassword(email: email, password: password),
    );
  }

  @override
  Future<void> signUp({required String email, required String password}) {
    return _guard(() async {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
      await cred.user?.sendEmailVerification();
    });
  }

  @override
  Future<void> sendPasswordReset(String email) {
    return _guard(() => _auth.sendPasswordResetEmail(email: email));
  }

  @override
  Future<void> signOut() => _auth.signOut();

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e.code));
    }
  }

  @override
  Future<void> sendEmailVerification() {
    return _guard(() async {
      await _auth.currentUser?.sendEmailVerification();
    });
  }

  @override
  Future<bool> refreshEmailVerified() async {
    try {
      await _auth.currentUser?.reload();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e.code));
    }
    return _auth.currentUser?.emailVerified ?? false;
  }

  String _message(String code) {
    switch (code) {
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Wrong email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Choose a stronger password (at least 6 characters).';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      case 'too-many-requests':
        return 'Too many attempts. Try again in a few minutes.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}