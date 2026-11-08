import 'auth/sign_in_with_password.dart';
import 'auth/sign_out.dart';
import 'auth/watch_session.dart';
import 'club/resolve_club_entry.dart';
import 'club/select_active_club.dart';

/// Use cases the presentation layer needs, built by the composition root.
class AppUseCases {
  const AppUseCases({
    required this.watchSession,
    required this.signInWithPassword,
    required this.signOut,
    required this.resolveClubEntry,
    required this.selectActiveClub,
  });

  final WatchSession watchSession;
  final SignInWithPassword signInWithPassword;
  final SignOut signOut;
  final ResolveClubEntry resolveClubEntry;
  final SelectActiveClub selectActiveClub;
}
