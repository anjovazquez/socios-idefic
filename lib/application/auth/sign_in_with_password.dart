import '../../domain/auth/auth_failures.dart';
import '../../domain/auth/auth_repository.dart';
import '../../domain/auth/auth_user.dart';

class SignInWithPassword {
  const SignInWithPassword(this._auth);

  final AuthRepository _auth;

  Future<AuthUser> call({required String email, required String password}) {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || password.isEmpty) {
      throw const MissingCredentialsFailure();
    }
    return _auth.signInWithPassword(email: normalizedEmail, password: password);
  }
}
