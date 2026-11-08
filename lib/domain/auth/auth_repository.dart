import 'auth_user.dart';

abstract interface class AuthRepository {
  AuthUser? get currentUser;

  /// Emits the current user (or null) whenever the session changes.
  ///
  /// Errors are [AuthFailure]s raised while completing a provider sign-in
  /// (e.g. Google redirect back with an unregistered account).
  Stream<AuthUser?> authStateChanges();

  /// Throws an [AuthFailure] when the credentials are rejected.
  Future<AuthUser> signInWithPassword({
    required String email,
    required String password,
  });

  /// Starts the Google flow. The session arrives through
  /// [authStateChanges] once the provider redirects back.
  Future<void> signInWithGoogle();

  Future<void> signOut();
}
