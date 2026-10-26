import 'package:spendly_android/data/models/app_user.dart';
import 'package:spendly_android/data/repositories/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.user, this.signInError});

  final AppUser? user;
  final AuthFailure? signInError;

  @override
  Stream<AppUser?> authStateChanges() => Stream.value(user);

  @override
  Future<void> signIn({required String email, required String password}) async {
    if (signInError != null) throw signInError!;
  }

  @override
  Future<void> signUp({required String email, required String password}) async {}

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signOut() async {}
}