import '../../domain/auth/auth_repository.dart';
import '../../domain/club/active_club_store.dart';

class SignOut {
  const SignOut(this._auth, this._activeClubStore);

  final AuthRepository _auth;
  final ActiveClubStore _activeClubStore;

  Future<void> call() async {
    await _activeClubStore.clear();
    await _auth.signOut();
  }
}
