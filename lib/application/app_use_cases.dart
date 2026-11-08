import 'auth/sign_in_with_google.dart';
import 'blog/blog_use_cases.dart';
import 'auth/sign_in_with_password.dart';
import 'auth/sign_out.dart';
import 'auth/watch_session.dart';
import 'card/card_use_cases.dart';
import 'club/club_branding_use_cases.dart';
import 'club/resolve_club_entry.dart';
import 'club/select_active_club.dart';
import 'member/member_use_cases.dart';
import 'onboarding/onboarding_use_cases.dart';
import 'payment/payment_use_cases.dart';
import 'platform/platform_use_cases.dart';
import 'profile/profile_use_cases.dart';
import 'season/season_use_cases.dart';

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
    required this.setMemberNumber,
    required this.deactivateMember,
    required this.reactivateMember,
    required this.getMemberPhotoUrl,
    required this.getOnboardingStatus,
    required this.verifyInvitationLink,
    required this.setNewPassword,
    required this.completeOnboarding,
    required this.getMyProfile,
    required this.updateMyProfile,
    required this.uploadProfilePhoto,
    required this.getSeasons,
    required this.createSeason,
    required this.activateSeason,
    required this.setSeasonRenewal,
    required this.getMemberSeasons,
    required this.setMemberFee,
    required this.getRenewalCandidates,
    required this.bulkRenew,
    required this.getMyCard,
    required this.validateCard,
    required this.regenerateCard,
    required this.getSeasonPayments,
    required this.recordManualPayment,
    required this.cancelPayment,
    required this.getPaymentInstructions,
    required this.setPaymentInstructions,
    required this.startPayment,
    required this.getMySubscription,
    required this.getMyPayments,
    required this.downloadReceipt,
    required this.getClubPayments,
    required this.startOnlinePayment,
    required this.getOnlinePaymentsStatus,
    required this.startOnlinePaymentsOnboarding,
    required this.refreshOnlinePaymentsStatus,
    required this.getMyRenewalSetup,
    required this.startPaymentMethodSetup,
    required this.removePaymentMethod,
    required this.cancelRenewal,
    required this.getClubPosts,
    required this.savePost,
    required this.setPostStatus,
    required this.uploadPostImage,
    required this.getPostImageUrl,
    required this.getClubFeed,
    required this.getPost,
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
  final SetMemberNumber setMemberNumber;
  final DeactivateMember deactivateMember;
  final ReactivateMember reactivateMember;
  final GetMemberPhotoUrl getMemberPhotoUrl;
  final GetOnboardingStatus getOnboardingStatus;
  final VerifyInvitationLink verifyInvitationLink;
  final SetNewPassword setNewPassword;
  final CompleteOnboarding completeOnboarding;
  final GetMyProfile getMyProfile;
  final UpdateMyProfile updateMyProfile;
  final UploadProfilePhoto uploadProfilePhoto;
  final GetSeasons getSeasons;
  final CreateSeason createSeason;
  final ActivateSeason activateSeason;
  final SetSeasonRenewal setSeasonRenewal;
  final GetMemberSeasons getMemberSeasons;
  final SetMemberFee setMemberFee;
  final GetRenewalCandidates getRenewalCandidates;
  final BulkRenew bulkRenew;
  final GetMyCard getMyCard;
  final ValidateCard validateCard;
  final RegenerateCard regenerateCard;
  final GetSeasonPayments getSeasonPayments;
  final RecordManualPayment recordManualPayment;
  final CancelPayment cancelPayment;
  final GetPaymentInstructions getPaymentInstructions;
  final SetPaymentInstructions setPaymentInstructions;
  final StartPayment startPayment;
  final GetMySubscription getMySubscription;
  final GetMyPayments getMyPayments;
  final DownloadReceipt downloadReceipt;
  final GetClubPayments getClubPayments;

  /// Online payment (Stripe); [startPayment] stays the manual one.
  final StartPayment startOnlinePayment;
  final GetOnlinePaymentsStatus getOnlinePaymentsStatus;
  final StartOnlinePaymentsOnboarding startOnlinePaymentsOnboarding;
  final RefreshOnlinePaymentsStatus refreshOnlinePaymentsStatus;
  final GetMyRenewalSetup getMyRenewalSetup;
  final StartPaymentMethodSetup startPaymentMethodSetup;
  final RemovePaymentMethod removePaymentMethod;
  final CancelRenewal cancelRenewal;
  final GetClubPosts getClubPosts;
  final SavePost savePost;
  final SetPostStatus setPostStatus;
  final UploadPostImage uploadPostImage;
  final GetPostImageUrl getPostImageUrl;
  final GetClubFeed getClubFeed;
  final GetPost getPost;
}
