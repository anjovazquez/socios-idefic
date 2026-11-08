import '../../domain/auth/auth_repository.dart';
import '../../domain/auth/auth_user.dart';

class WatchSession {
  const WatchSession(this._auth);

  final AuthRepository _auth;

  AuthUser? get currentUser => _auth.currentUser;

  Stream<AuthUser?> call() => _auth.authStateChanges();
}
