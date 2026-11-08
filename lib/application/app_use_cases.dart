import 'auth/sign_in_with_google.dart';
import 'auth/sign_in_with_password.dart';
import 'auth/sign_out.dart';
import 'auth/watch_session.dart';
import 'club/club_branding_use_cases.dart';
import 'club/resolve_club_entry.dart';
import 'club/select_active_club.dart';
import 'member/member_use_cases.dart';
import 'onboarding/onboarding_use_cases.dart';
import 'platform/platform_use_cases.dart';
import 'profile/profile_use_cases.dart';

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
    required this.getAuditLog,
    required this.getClubMembers,
    required this.inviteMember,
    required this.resendInvitation,
    required this.getOnboardingStatus,
    required this.verifyInvitationLink,
    required this.setNewPassword,
    required this.completeOnboarding,
    required this.getMyProfile,
    required this.updateMyProfile,
    required this.uploadProfilePhoto,
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
  final GetAuditLog getAuditLog;
  final GetClubMembers getClubMembers;
  final InviteMember inviteMember;
  final ResendInvitation resendInvitation;
  final GetOnboardingStatus getOnboardingStatus;
  final VerifyInvitationLink verifyInvitationLink;
  final SetNewPassword setNewPassword;
  final CompleteOnboarding completeOnboarding;
  final GetMyProfile getMyProfile;
  final UpdateMyProfile updateMyProfile;
  final UploadProfilePhoto uploadProfilePhoto;
}
