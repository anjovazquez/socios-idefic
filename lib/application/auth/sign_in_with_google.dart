import '../../domain/auth/auth_repository.dart';

class SignInWithGoogle {
  const SignInWithGoogle(this._auth);

  final AuthRepository _auth;

  Future<void> call() => _auth.signInWithGoogle();
}
