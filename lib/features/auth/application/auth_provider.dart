import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/app_user.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/firebase_auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FirebaseAuthRepository(),
);

/// Emits the signed-in user, or null when signed out.
final authStateProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

final currentUserIdProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider.select((s) => s.value?.uid)),
);

final emailVerifiedProvider = Provider<bool>(
  (ref) => ref.watch(
    authStateProvider.select((s) => s.value?.emailVerified ?? false),
  ),
);