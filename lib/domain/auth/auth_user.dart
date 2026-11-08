/// The globally identified person behind a session (RN-003).
class AuthUser {
  const AuthUser({required this.id, required this.email});

  final String id;
  final String email;
}
