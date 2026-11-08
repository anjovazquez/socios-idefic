import 'auth_user.dart';

abstract interface class AuthRepository {
  AuthUser? get currentUser;

  /// Emits the current user (or null) whenever the session changes.
  Stream<AuthUser?> authStateChanges();

  /// Throws an [AuthFailure] when the credentials are rejected.
  Future<AuthUser> signInWithPassword({
    required String email,
    required String password,
  });

  Future<void> signOut();
}
