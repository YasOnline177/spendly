class AppUser {
  final String uid;
  final String? email;
  final bool emailVerified;

  const AppUser({
    required this.uid,
    this.email,
    this.emailVerified = false,
  });
}