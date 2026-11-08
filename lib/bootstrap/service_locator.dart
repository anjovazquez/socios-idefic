import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../application/app_use_cases.dart';
import '../application/auth/sign_in_with_google.dart';
import '../application/auth/sign_in_with_password.dart';
import '../application/auth/sign_out.dart';
import '../application/auth/watch_session.dart';
import '../application/card/card_use_cases.dart';
import '../application/club/club_branding_use_cases.dart';
import '../application/club/resolve_club_entry.dart';
import '../application/club/select_active_club.dart';
import '../application/member/member_use_cases.dart';
import '../application/onboarding/onboarding_use_cases.dart';
import '../application/payment/payment_use_cases.dart';
import '../application/platform/platform_use_cases.dart';
import '../application/profile/profile_use_cases.dart';
import '../application/season/season_use_cases.dart';
import '../domain/auth/auth_repository.dart';
import '../domain/card/card_repository.dart';
import '../domain/club/active_club_store.dart';
import '../domain/club/club_branding_repository.dart';
import '../domain/club/club_repository.dart';
import '../domain/member/members_repository.dart';
import '../domain/onboarding/onboarding_repository.dart';
import '../domain/payment/payment_gateway.dart';
import '../domain/payment/payments_repository.dart';
import '../domain/platform/platform_repository.dart';
import '../domain/profile/profile_repository.dart';
import '../domain/season/season_repository.dart';
import '../infrastructure/auth/supabase_auth_repository.dart';
import '../infrastructure/card/supabase_card_repository.dart';
import '../infrastructure/club/shared_preferences_active_club_store.dart';
import '../infrastructure/club/supabase_club_branding_repository.dart';
import '../infrastructure/club/supabase_club_repository.dart';
import '../infrastructure/member/supabase_members_repository.dart';
import '../infrastructure/onboarding/supabase_onboarding_repository.dart';
import '../infrastructure/payment/manual_payment_gateway.dart';
import '../infrastructure/payment/supabase_payments_repository.dart';
import '../infrastructure/platform/supabase_platform_repository.dart';
import '../infrastructure/profile/supabase_profile_repository.dart';
import '../infrastructure/season/supabase_season_repository.dart';

/// Composition root. Only this layer knows about GetIt.
final GetIt serviceLocator = GetIt.instance;

/// Deep link registered in Android/iOS and in Supabase redirect URLs.
const mobileAuthRedirectUrl = 'es.idefic.socios://login-callback';

void configureDependencies() {
  final client = Supabase.instance.client;

  serviceLocator
    ..registerLazySingleton<AuthRepository>(
      () => SupabaseAuthRepository(
        client,
        oauthRedirectUrl: kIsWeb ? null : mobileAuthRedirectUrl,
      ),
    )
    ..registerLazySingleton<ClubRepository>(
      () => SupabaseClubRepository(client),
    )
    ..registerLazySingleton<ClubBrandingRepository>(
      () => SupabaseClubBrandingRepository(client),
    )
    ..registerLazySingleton<PaymentsRepository>(
      () => SupabasePaymentsRepository(client),
    )
    ..registerLazySingleton<PaymentGateway>(
      () => ManualPaymentGateway(serviceLocator()),
    )
    ..registerLazySingleton<CardRepository>(
      () => SupabaseCardRepository(client),
    )
    ..registerLazySingleton<SeasonRepository>(
      () => SupabaseSeasonRepository(client),
    )
    ..registerLazySingleton<ProfileRepository>(
      () => SupabaseProfileRepository(client),
    )
    ..registerLazySingleton<OnboardingRepository>(
      () => SupabaseOnboardingRepository(client),
    )
    ..registerLazySingleton<MembersRepository>(
      () => SupabaseMembersRepository(client),
    )
    ..registerLazySingleton<PlatformRepository>(
      () => SupabasePlatformRepository(client),
    )
    ..registerLazySingleton<ActiveClubStore>(
      SharedPreferencesActiveClubStore.new,
    )
    ..registerLazySingleton<AppUseCases>(
      () => AppUseCases(
        watchSession: WatchSession(serviceLocator()),
        signInWithPassword: SignInWithPassword(serviceLocator()),
        signInWithGoogle: SignInWithGoogle(serviceLocator()),
        signOut: SignOut(serviceLocator(), serviceLocator()),
        resolveClubEntry: ResolveClubEntry(serviceLocator(), serviceLocator()),
        selectActiveClub: SelectActiveClub(serviceLocator()),
        isPlatformAdmin: IsPlatformAdmin(serviceLocator()),
        getPlatformClubs: GetPlatformClubs(serviceLocator()),
        createClub: CreateClub(serviceLocator()),
        updateClub: UpdateClub(serviceLocator()),
        setClubActive: SetClubActive(serviceLocator()),
        getClubBranding: GetClubBranding(serviceLocator()),
        saveClubBranding: SaveClubBranding(serviceLocator()),
        uploadClubAsset: UploadClubAsset(serviceLocator()),
        getAuditLog: GetAuditLog(serviceLocator()),
        getClubMembers: GetClubMembers(serviceLocator()),
        inviteMember: InviteMember(serviceLocator()),
        resendInvitation: ResendInvitation(serviceLocator()),
        setMemberNumber: SetMemberNumber(serviceLocator()),
        deactivateMember: DeactivateMember(serviceLocator()),
        reactivateMember: ReactivateMember(serviceLocator()),
        getMemberPhotoUrl: GetMemberPhotoUrl(serviceLocator()),
        getOnboardingStatus: GetOnboardingStatus(serviceLocator()),
        verifyInvitationLink: VerifyInvitationLink(serviceLocator()),
        setNewPassword: SetNewPassword(serviceLocator()),
        completeOnboarding: CompleteOnboarding(serviceLocator()),
        getMyProfile: GetMyProfile(serviceLocator()),
        updateMyProfile: UpdateMyProfile(serviceLocator()),
        uploadProfilePhoto: UploadProfilePhoto(serviceLocator()),
        getSeasons: GetSeasons(serviceLocator()),
        createSeason: CreateSeason(serviceLocator()),
        activateSeason: ActivateSeason(serviceLocator()),
        getMemberSeasons: GetMemberSeasons(serviceLocator()),
        setMemberFee: SetMemberFee(serviceLocator()),
        getRenewalCandidates: GetRenewalCandidates(serviceLocator()),
        bulkRenew: BulkRenew(serviceLocator()),
        getMyCard: GetMyCard(serviceLocator()),
        validateCard: ValidateCard(serviceLocator()),
        regenerateCard: RegenerateCard(serviceLocator()),
        getSeasonPayments: GetSeasonPayments(serviceLocator()),
        recordManualPayment: RecordManualPayment(serviceLocator()),
        cancelPayment: CancelPayment(serviceLocator()),
        getPaymentInstructions: GetPaymentInstructions(serviceLocator()),
        setPaymentInstructions: SetPaymentInstructions(serviceLocator()),
        startPayment: StartPayment(serviceLocator()),
        getMySubscription: GetMySubscription(serviceLocator()),
        getMyPayments: GetMyPayments(serviceLocator()),
      ),
    );
}
