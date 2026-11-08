import 'auth/sign_in_with_google.dart';
import 'auth/sign_in_with_password.dart';
import 'auth/sign_out.dart';
import 'auth/watch_session.dart';
import 'club/club_branding_use_cases.dart';
import 'club/resolve_club_entry.dart';
import 'club/select_active_club.dart';
import 'platform/platform_use_cases.dart';

/// Use cases the presentation layer needs, built by the composition root.
class AppUseCases {
  const AppUseCases({
    required this.watchSession,
    required this.signInWithPassword,
    required this.signInWithGoogle,
    required this.signOut,
    required this.resolveClubEntry,
    required this.selectActiveClub,
    required this.isPlatformAdmin,
    required this.getPlatformClubs,
    required this.createClub,
    required this.updateClub,
    required this.setClubActive,
    required this.getClubBranding,
    required this.saveClubBranding,
    required this.uploadClubAsset,
  });

  final WatchSession watchSession;
  final SignInWithPassword signInWithPassword;
  final SignInWithGoogle signInWithGoogle;
  final SignOut signOut;
  final ResolveClubEntry resolveClubEntry;
  final SelectActiveClub selectActiveClub;
  final IsPlatformAdmin isPlatformAdmin;
  final GetPlatformClubs getPlatformClubs;
  final CreateClub createClub;
  final UpdateClub updateClub;
  final SetClubActive setClubActive;
  final GetClubBranding getClubBranding;
  final SaveClubBranding saveClubBranding;
  final UploadClubAsset uploadClubAsset;
}
