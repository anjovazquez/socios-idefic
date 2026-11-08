import 'dart:async';
import 'dart:typed_data';

import 'package:socios_idefic/application/app_use_cases.dart';
import 'package:socios_idefic/application/auth/sign_in_with_google.dart';
import 'package:socios_idefic/application/auth/sign_in_with_password.dart';
import 'package:socios_idefic/application/auth/sign_out.dart';
import 'package:socios_idefic/application/auth/watch_session.dart';
import 'package:socios_idefic/application/card/card_use_cases.dart';
import 'package:socios_idefic/application/club/club_branding_use_cases.dart';
import 'package:socios_idefic/application/club/resolve_club_entry.dart';
import 'package:socios_idefic/application/club/select_active_club.dart';
import 'package:socios_idefic/application/member/member_use_cases.dart';
import 'package:socios_idefic/application/onboarding/onboarding_use_cases.dart';
import 'package:socios_idefic/application/payment/payment_use_cases.dart';
import 'package:socios_idefic/application/platform/platform_use_cases.dart';
import 'package:socios_idefic/application/profile/profile_use_cases.dart';
import 'package:socios_idefic/application/season/season_use_cases.dart';
import 'package:socios_idefic/domain/auth/auth_failures.dart';
import 'package:socios_idefic/domain/auth/auth_repository.dart';
import 'package:socios_idefic/domain/auth/auth_user.dart';
import 'package:socios_idefic/domain/card/card_repository.dart';
import 'package:socios_idefic/domain/card/card_validation.dart';
import 'package:socios_idefic/domain/card/membership_card.dart';
import 'package:socios_idefic/domain/club/active_club_store.dart';
import 'package:socios_idefic/domain/club/club_branding.dart';
import 'package:socios_idefic/domain/club/club_branding_repository.dart';
import 'package:socios_idefic/domain/club/club_repository.dart';
import 'package:socios_idefic/domain/club/my_club.dart';
import 'package:socios_idefic/domain/member/club_member.dart';
import 'package:socios_idefic/domain/member/members_repository.dart';
import 'package:socios_idefic/domain/onboarding/onboarding.dart';
import 'package:socios_idefic/domain/onboarding/onboarding_repository.dart';
import 'package:socios_idefic/domain/payment/club_payments.dart';
import 'package:socios_idefic/domain/payment/my_subscription.dart';
import 'package:socios_idefic/domain/payment/online_payments.dart';
import 'package:socios_idefic/domain/payment/payment.dart';
import 'package:socios_idefic/domain/payment/payments_repository.dart';
import 'package:socios_idefic/domain/payment/receipt.dart';
import 'package:socios_idefic/infrastructure/payment/manual_payment_gateway.dart';
import 'package:socios_idefic/infrastructure/payment/stripe_payment_gateway.dart';
import 'package:socios_idefic/domain/platform/audit_entry.dart';
import 'package:socios_idefic/domain/profile/my_profile.dart';
import 'package:socios_idefic/domain/profile/profile_repository.dart';
import 'package:socios_idefic/domain/season/renewal.dart';
import 'package:socios_idefic/domain/season/season.dart';
import 'package:socios_idefic/domain/season/season_membership.dart';
import 'package:socios_idefic/domain/season/season_repository.dart';
import 'package:socios_idefic/domain/platform/club_data.dart';
import 'package:socios_idefic/domain/platform/platform_club.dart';
import 'package:socios_idefic/domain/platform/platform_failures.dart';
import 'package:socios_idefic/domain/platform/platform_repository.dart';

const idefic = MyClub(
  id: 'club-idefic',
  name: 'IDEFIC',
  code: 'IDEFIC',
  role: ClubRole.member,
  primaryColor: '#0B3D91',
  memberNumber: 2,
);

const ideficAsAdmin = MyClub(
  id: 'club-idefic',
  name: 'IDEFIC',
  code: 'IDEFIC',
  role: ClubRole.clubAdmin,
  primaryColor: '#0B3D91',
  memberNumber: 1,
);

const demo = MyClub(
  id: 'club-demo',
  name: 'Club Demo',
  code: 'DEMO',
  role: ClubRole.member,
  primaryColor: '#B3261E',
  memberNumber: 7,
);

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({Map<String, String>? passwords, AuthUser? signedIn})
    : _passwords = passwords ?? {},
      _current = signedIn;

  final Map<String, String> _passwords;
  final _changes = StreamController<AuthUser?>.broadcast();
  AuthUser? _current;
  String? lastEmail;
  Object? failure;

  /// Google account picked on the provider screen; null cancels.
  String? googleEmail;
  int googleAttempts = 0;

  @override
  AuthUser? get currentUser => _current;

  @override
  Stream<AuthUser?> authStateChanges() => _changes.stream;

  @override
  Future<AuthUser> signInWithPassword({
    required String email,
    required String password,
  }) async {
    lastEmail = email;
    if (failure case final error?) throw error;
    if (_passwords[email] != password) {
      throw const InvalidCredentialsFailure();
    }
    final user = AuthUser(id: 'user-$email', email: email);
    _current = user;
    _changes.add(user);
    return user;
  }

  /// Mimics Supabase: the session (or the rejection) arrives later through
  /// the auth stream after the provider redirects back. Accounts that exist
  /// (here: have a password) are linked by email; others are rejected.
  @override
  Future<void> signInWithGoogle() async {
    googleAttempts++;
    final email = googleEmail;
    if (email == null) throw const SignInCancelledFailure();
    if (!_passwords.containsKey(email)) {
      _changes.addError(const UnregisteredAccountFailure());
      return;
    }
    final user = AuthUser(id: 'user-$email', email: email);
    _current = user;
    _changes.add(user);
  }

  /// Session created by an invitation link (VS-007).
  void signInFromLink(String email) {
    final user = AuthUser(id: 'user-$email', email: email);
    _current = user;
    _changes.add(user);
  }

  @override
  Future<void> signOut() async {
    _current = null;
    _changes.add(null);
  }
}

class FakeClubRepository implements ClubRepository {
  FakeClubRepository([Map<String, List<MyClub>>? clubsByEmail])
    : clubsByEmail = clubsByEmail ?? {};

  final Map<String, List<MyClub>> clubsByEmail;
  FakeAuthRepository? auth;
  FakePlatformRepository? platform;
  List<MyClub> fixed = const [];

  @override
  Future<List<MyClub>> getMyClubs() async {
    final email = auth?.currentUser?.email;
    if (email == null) return fixed;
    final platform = this.platform;
    if (platform != null && platform.adminEmails.contains(email)) {
      return [
        for (final club in platform.clubs.where((c) => c.isActive))
          MyClub(
            id: club.id,
            name: club.name,
            code: club.code,
            role: ClubRole.platformAdmin,
          ),
      ];
    }
    return clubsByEmail[email] ?? const [];
  }
}

class InMemoryActiveClubStore implements ActiveClubStore {
  String? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String clubId) async => value = clubId;
}

/// In-memory platform administration mirroring the server rules.
class FakePlatformRepository implements PlatformRepository {
  FakePlatformRepository({
    Set<String>? adminEmails,
    List<PlatformClub>? clubs,
    this.existingUsers = const {},
  }) : adminEmails = adminEmails ?? {},
       clubs = clubs ?? [];

  final Set<String> adminEmails;
  final List<PlatformClub> clubs;
  final Set<String> existingUsers;
  FakeAuthRepository? auth;
  final List<AuditEntry> audit = [];

  void _audit(String clubId, String action, Map<String, Object?> payload) {
    final club = clubs.where((c) => c.id == clubId).firstOrNull;
    audit.add(
      AuditEntry(
        id: audit.length + 1,
        action: action,
        asPlatformAdmin: true,
        createdAt: DateTime(2026, 11, 8, 12, audit.length),
        clubId: clubId,
        clubName: club?.name,
        actorEmail: auth?.currentUser?.email,
        payload: payload,
      ),
    );
  }

  @override
  Future<List<AuditEntry>> getAuditLog({
    String? clubId,
    int? beforeId,
    int limit = 50,
  }) async {
    _require();
    return audit.reversed
        .where((e) => clubId == null || e.clubId == clubId)
        .where((e) => beforeId == null || e.id < beforeId)
        .take(limit)
        .toList();
  }

  bool get _isAdmin => adminEmails.contains(auth?.currentUser?.email);

  void _require() {
    if (!_isAdmin) throw const NotPlatformAdminFailure();
  }

  @override
  Future<bool> isPlatformAdmin() async => _isAdmin;

  @override
  Future<List<PlatformClub>> getClubs() async {
    _require();
    return [...clubs]..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Future<String> createClub({
    required ClubData data,
    required String adminEmail,
    String? adminName,
  }) async {
    _require();
    if (clubs.any((c) => c.code == data.code)) {
      throw const DuplicateClubCodeFailure();
    }
    final known = existingUsers.contains(adminEmail);
    final club = PlatformClub(
      id: 'club-${data.code.toLowerCase()}',
      name: data.name,
      code: data.code,
      isActive: true,
      memberCount: known ? 1 : 0,
      adminEmail: known ? adminEmail : null,
      pendingAdminEmail: known ? null : adminEmail,
    );
    clubs.add(club);
    _audit(club.id, 'club_created', {'name': club.name, 'code': club.code});
    return club.id;
  }

  @override
  Future<void> updateClub({
    required String clubId,
    required ClubData data,
  }) async {
    _require();
    if (clubs.any((c) => c.code == data.code && c.id != clubId)) {
      throw const DuplicateClubCodeFailure();
    }
    _replace(clubId, (c) => _copy(c, name: data.name, code: data.code));
  }

  @override
  Future<void> setClubActive({
    required String clubId,
    required bool active,
  }) async {
    _require();
    _replace(clubId, (c) => _copy(c, isActive: active));
    _audit(clubId, active ? 'club_activated' : 'club_deactivated', {});
  }

  void _replace(String id, PlatformClub Function(PlatformClub) change) {
    final index = clubs.indexWhere((c) => c.id == id);
    clubs[index] = change(clubs[index]);
  }

  static PlatformClub _copy(
    PlatformClub c, {
    String? name,
    String? code,
    bool? isActive,
  }) => PlatformClub(
    id: c.id,
    name: name ?? c.name,
    code: code ?? c.code,
    isActive: isActive ?? c.isActive,
    memberCount: c.memberCount,
    adminEmail: c.adminEmail,
    pendingAdminEmail: c.pendingAdminEmail,
  );
}

/// Branding store that also updates what [FakeClubRepository] returns, so
/// the session sees the new identity after saving.
class FakeClubBrandingRepository implements ClubBrandingRepository {
  FakeClubBrandingRepository(this.clubs);

  final FakeClubRepository clubs;
  int uploads = 0;
  ClubBranding? lastSaved;

  MyClub _club(String clubId) => clubs.clubsByEmail.values
      .expand((list) => list)
      .firstWhere((club) => club.id == clubId);

  MyClub? _mine(String clubId) => clubs
      .clubsByEmail[clubs.auth?.currentUser?.email]
      ?.where((club) => club.id == clubId)
      .firstOrNull;

  void _requireAdmin(String clubId) {
    if (!(_mine(clubId)?.canAdminister ?? false)) {
      throw const BrandingPermissionFailure();
    }
  }

  @override
  Future<ClubBranding> getBranding(String clubId) async {
    _requireAdmin(clubId);
    final club = _club(clubId);
    return ClubBranding(
      clubId: club.id,
      name: club.name,
      primaryColor: club.primaryColor ?? ClubBranding.defaultPrimaryColor,
      secondaryColor: club.secondaryColor,
      logoUrl: club.logoUrl,
      logoPath: club.logoUrl == null ? null : '$clubId/logo.png',
    );
  }

  @override
  Future<void> saveBranding(ClubBranding branding) async {
    _requireAdmin(branding.clubId);
    lastSaved = branding;
    for (final entry in clubs.clubsByEmail.entries) {
      clubs.clubsByEmail[entry.key] = [
        for (final club in entry.value)
          if (club.id == branding.clubId)
            MyClub(
              id: club.id,
              name: branding.name,
              code: club.code,
              role: club.role,
              memberNumber: club.memberNumber,
              primaryColor: branding.primaryColor,
              secondaryColor: branding.secondaryColor,
              logoUrl: branding.logoUrl,
              imageUrl: branding.imageUrl,
            )
          else
            club,
      ];
    }
  }

  @override
  Future<String> uploadAsset({
    required String clubId,
    required ClubAssetKind kind,
    required Uint8List bytes,
    required String contentType,
  }) async {
    _requireAdmin(clubId);
    uploads++;
    return '$clubId/${kind.name}-$uploads.png';
  }

  @override
  String publicUrl(String path) => 'https://cdn.test/$path';
}

/// Members per club mirroring the server rules of VS-006.
class FakeMembersRepository implements MembersRepository {
  FakeMembersRepository({Map<String, List<ClubMember>>? members, this.auth})
    : members = members ?? {};

  final Map<String, List<ClubMember>> members;
  FakeAuthRepository? auth;
  FakeClubRepository? clubs;

  /// Emails with an account somewhere on the platform.
  Set<String> existingAccounts = {};
  final List<String> sentEmails = [];

  bool _isAdmin(String clubId) =>
      clubs?.clubsByEmail[auth?.currentUser?.email]?.any(
        (c) => c.id == clubId && c.canAdminister,
      ) ??
      false;

  @override
  Future<MemberPage> getMembers(
    String clubId, {
    String? query,
    MemberStatus? status,
    int offset = 0,
    int limit = 50,
  }) async {
    if (!_isAdmin(clubId)) throw const MemberPermissionFailure();
    final q = query?.toLowerCase();
    final matching =
        (members[clubId] ?? const <ClubMember>[])
            .where((m) => status == null || m.status == status)
            .where(
              (m) =>
                  q == null ||
                  m.displayName.toLowerCase().contains(q) ||
                  m.email.contains(q) ||
                  m.memberNumber?.toString() == q,
            )
            .toList()
          ..sort(
            (a, b) => (a.memberNumber ?? 0).compareTo(b.memberNumber ?? 0),
          );
    return MemberPage(
      members: matching.skip(offset).take(limit).toList(),
      total: matching.length,
    );
  }

  void _replace(String membershipId, ClubMember Function(ClubMember) change) {
    for (final list in members.values) {
      final index = list.indexWhere((m) => m.membershipId == membershipId);
      if (index >= 0) list[index] = change(list[index]);
    }
  }

  @override
  Future<void> deactivate(String membershipId) async =>
      _replace(membershipId, (m) => m.copyWith(status: MemberStatus.inactive));

  @override
  Future<MemberStatus> reactivate(String membershipId) async {
    _replace(membershipId, (m) => m.copyWith(status: MemberStatus.active));
    return MemberStatus.active;
  }

  @override
  Future<String> memberPhotoUrl(String path) async =>
      'https://signed.test/$path';

  @override
  Future<InvitationOutcome> invite({
    required String clubId,
    required String email,
    required String firstName,
  }) async {
    if (!_isAdmin(clubId)) throw const MemberPermissionFailure();
    final list = members.putIfAbsent(clubId, () => []);
    if (list.any((m) => m.email == email && m.status == MemberStatus.active)) {
      throw const AlreadyMemberFailure();
    }
    final existing = existingAccounts.contains(email);
    final next =
        list.fold<int>(
          0,
          (max, m) => (m.memberNumber ?? 0) > max ? m.memberNumber! : max,
        ) +
        1;
    list.add(
      ClubMember(
        membershipId: 'm-$email',
        email: email,
        firstName: firstName,
        memberNumber: next,
        isClubAdmin: false,
        status: existing ? MemberStatus.active : MemberStatus.invited,
      ),
    );
    sentEmails.add(email);
    if (existing) {
      // Same account, one more club (RF-004).
      final club = clubs!.clubsByEmail[auth!.currentUser!.email]!.firstWhere(
        (c) => c.id == clubId,
      );
      clubs!.clubsByEmail[email] = [
        ...?clubs!.clubsByEmail[email],
        MyClub(
          id: club.id,
          name: club.name,
          code: club.code,
          role: ClubRole.member,
          primaryColor: club.primaryColor,
          memberNumber: next,
        ),
      ];
    }
    return existing
        ? InvitationOutcome.addedExistingAccount
        : InvitationOutcome.invited;
  }

  @override
  Future<void> setMemberNumber(String membershipId, int number) async {
    for (final entry in members.entries) {
      final index = entry.value.indexWhere(
        (m) => m.membershipId == membershipId,
      );
      if (index < 0) continue;
      if (!_isAdmin(entry.key)) throw const MemberPermissionFailure();
      if (entry.value.any(
        (m) => m.memberNumber == number && m.membershipId != membershipId,
      )) {
        throw const MemberNumberTakenFailure();
      }
      final m = entry.value[index];
      entry.value[index] = ClubMember(
        membershipId: m.membershipId,
        email: m.email,
        status: m.status,
        isClubAdmin: m.isClubAdmin,
        firstName: m.firstName,
        lastName: m.lastName,
        memberNumber: number,
      );
      return;
    }
  }

  @override
  Future<void> resendInvitation(String membershipId) async {
    final member = members.values
        .expand((list) => list)
        .firstWhere((m) => m.membershipId == membershipId);
    if (member.status != MemberStatus.invited) {
      throw const InvitationNotPendingFailure();
    }
    sentEmails.add(member.email);
  }
}

/// First-access state per email. Unknown emails have finished it.
class FakeOnboardingRepository implements OnboardingRepository {
  FakeOnboardingRepository({
    Map<String, OnboardingStatus>? pending,
    Map<String, String>? linkTokens,
    Map<String, List<MyClub>>? clubsOnCompletion,
  }) : pending = pending ?? {},
       linkTokens = linkTokens ?? {},
       clubsOnCompletion = clubsOnCompletion ?? {};

  /// Emails that have not finished the first access.
  final Map<String, OnboardingStatus> pending;

  /// Valid one-time tokens → email.
  final Map<String, String> linkTokens;

  /// Clubs that become reachable when the first access is completed.
  final Map<String, List<MyClub>> clubsOnCompletion;

  FakeAuthRepository? auth;
  FakeClubRepository? clubs;
  final Map<String, String> passwords = {};
  PersonalData? completedWith;

  String get _email => auth!.currentUser!.email;

  @override
  Future<OnboardingStatus> getStatus() async =>
      pending[_email] ??
      OnboardingStatus(
        completed: true,
        needsPassword: false,
        termsVersion: 'v1',
        email: _email,
      );

  @override
  Future<void> verifyInvitation({
    required String tokenHash,
    required String type,
  }) async {
    final email = linkTokens.remove(tokenHash);
    if (email == null) throw const InvitationLinkExpiredFailure();
    auth!.signInFromLink(email);
  }

  @override
  Future<void> setPassword(String password) async =>
      passwords[_email] = password;

  @override
  Future<void> complete({
    required PersonalData data,
    required String termsVersion,
  }) async {
    final email = _email;
    pending.remove(email);
    completedWith = data;
    clubs?.clubsByEmail[email] = clubsOnCompletion[email] ?? const [];
  }
}

/// Profiles by email; the signed-in person only reaches their own.
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository([Map<String, MyProfile>? profiles])
    : profiles = profiles ?? {};

  final Map<String, MyProfile> profiles;
  FakeAuthRepository? auth;
  int uploads = 0;

  String get _email => auth!.currentUser!.email;

  @override
  Future<MyProfile> getMyProfile() async =>
      profiles[_email] ?? MyProfile(email: _email);

  @override
  Future<void> updateMyProfile({
    required PersonalData data,
    required String? photoPath,
  }) async {
    profiles[_email] = MyProfile(
      email: _email,
      firstName: data.firstName,
      lastName: data.lastName,
      phone: data.phone,
      birthDate: data.birthDate,
      photoPath: photoPath,
      photoUrl: photoPath == null ? null : 'https://signed.test/$photoPath',
    );
  }

  @override
  Future<String> uploadPhoto({
    required Uint8List bytes,
    required String contentType,
  }) async {
    uploads++;
    return 'user-$_email/photo-$uploads.jpg';
  }

  @override
  Future<String> photoUrl(String path) async => 'https://signed.test/$path';
}

/// Seasons per club with the server rules; activation updates the active
/// season shown by [FakeClubRepository].
class FakeSeasonRepository implements SeasonRepository {
  FakeSeasonRepository([Map<String, List<Season>>? seasons])
    : seasons = seasons ?? {};

  final Map<String, List<Season>> seasons;
  FakeClubRepository? clubs;
  FakeMembersRepository? members;

  /// History per club membership id.
  final Map<String, List<MemberSeason>> history = {};

  /// Renewal candidates per target season, and its ordinary fee.
  final Map<String, List<RenewalCandidate>> candidates = {};
  int ordinaryFeeCents = 5500;
  final List<List<RenewalItem>> renewals = [];

  @override
  Future<List<RenewalCandidate>> getRenewalCandidates(
    String seasonId, {
    required bool keepCustomFees,
  }) async => [
    for (final c in candidates[seasonId] ?? const <RenewalCandidate>[])
      keepCustomFees && c.previousWasCustom
          ? c
          : RenewalCandidate(
              membershipId: c.membershipId,
              email: c.email,
              firstName: c.firstName,
              memberNumber: c.memberNumber,
              previousSeasonName: c.previousSeasonName,
              previousFeeCents: c.previousFeeCents,
              previousWasCustom: c.previousWasCustom,
              proposedFeeCents: ordinaryFeeCents,
              alreadyRenewed: c.alreadyRenewed,
            ),
  ];

  @override
  Future<int> bulkRenew(String seasonId, List<RenewalItem> items) async {
    renewals.add(items);
    final list = candidates[seasonId]!;
    var created = 0;
    for (final item in items) {
      final index = list.indexWhere((c) => c.membershipId == item.membershipId);
      final c = list[index];
      if (c.alreadyRenewed) continue;
      created++;
      list[index] = RenewalCandidate(
        membershipId: c.membershipId,
        email: c.email,
        firstName: c.firstName,
        memberNumber: c.memberNumber,
        previousSeasonName: c.previousSeasonName,
        previousFeeCents: c.previousFeeCents,
        previousWasCustom: c.previousWasCustom,
        proposedFeeCents: c.proposedFeeCents,
        alreadyRenewed: true,
      );
    }
    return created;
  }

  void _updateMember(
    String seasonMembershipId,
    ClubMember Function(ClubMember) change,
  ) {
    for (final list in members?.members.values ?? <List<ClubMember>>[]) {
      final index = list.indexWhere(
        (m) => m.seasonMembershipId == seasonMembershipId,
      );
      if (index >= 0) list[index] = change(list[index]);
    }
  }

  @override
  Future<List<MemberSeason>> getMemberSeasons(String membershipId) async =>
      history[membershipId] ?? const [];

  @override
  Future<void> setMemberFee({
    required String seasonMembershipId,
    required int feeCents,
  }) async => _updateMember(
    seasonMembershipId,
    (m) => m.copyWith(
      seasonFeeCents: feeCents,
      seasonStatus:
          feeCents == 0 &&
              m.seasonStatus == SeasonMembershipStatus.pendingPayment
          ? SeasonMembershipStatus.active
          : m.seasonStatus,
    ),
  );

  Future<void> setSeasonMembershipStatus({
    required String seasonMembershipId,
    required SeasonMembershipStatus status,
  }) async => _updateMember(
    seasonMembershipId,
    (m) => m.copyWith(seasonStatus: status),
  );

  @override
  Future<List<Season>> getSeasons(String clubId) async =>
      [...?seasons[clubId]]..sort((a, b) => b.name.compareTo(a.name));

  @override
  Future<void> createSeason({
    required String clubId,
    required String name,
    DateTime? startsOn,
    DateTime? endsOn,
  }) async {
    final list = seasons.putIfAbsent(clubId, () => []);
    if (list.any((s) => s.name == name)) {
      throw const SeasonAlreadyExistsFailure();
    }
    final year = int.parse(name.substring(0, 4));
    list.add(
      Season(
        id: 'season-$name',
        clubId: clubId,
        name: name,
        startsOn: startsOn ?? DateTime(year, 9),
        endsOn: endsOn ?? DateTime(year + 1, 8, 31),
        status: SeasonStatus.draft,
      ),
    );
  }

  @override
  Future<void> activateSeason({
    required String seasonId,
    required int defaultFeeCents,
  }) async {
    for (final entry in seasons.entries) {
      if (!entry.value.any((s) => s.id == seasonId)) continue;
      entry.value.setAll(0, [
        for (final s in entry.value)
          Season(
            id: s.id,
            clubId: s.clubId,
            name: s.name,
            startsOn: s.startsOn,
            endsOn: s.endsOn,
            status: s.id == seasonId
                ? SeasonStatus.active
                : s.status == SeasonStatus.active
                ? SeasonStatus.closed
                : s.status,
            defaultFeeCents: s.id == seasonId
                ? defaultFeeCents
                : s.defaultFeeCents,
          ),
      ]);
      final name = entry.value.firstWhere((s) => s.id == seasonId).name;
      final byEmail = clubs?.clubsByEmail;
      if (byEmail == null) return;
      for (final email in byEmail.keys.toList()) {
        byEmail[email] = [
          for (final c in byEmail[email]!)
            c.id == entry.key
                ? MyClub(
                    id: c.id,
                    name: c.name,
                    code: c.code,
                    role: c.role,
                    logoUrl: c.logoUrl,
                    imageUrl: c.imageUrl,
                    primaryColor: c.primaryColor,
                    secondaryColor: c.secondaryColor,
                    memberNumber: c.memberNumber,
                    activeSeasonName: name,
                  )
                : c,
        ];
      }
    }
  }
}

/// Cards by email of the signed-in member.
class FakeCardRepository implements CardRepository {
  FakeCardRepository([Map<String, MembershipCard>? cards])
    : cards = cards ?? {};

  final Map<String, MembershipCard> cards;
  FakeAuthRepository? auth;

  /// Valid QR tokens and what they show.
  final Map<String, CardValidation> validations = {};
  final List<String> lookups = [];
  final List<String> regenerated = [];

  @override
  Future<CardValidation> validate(String token) async {
    lookups.add(token);
    return validations[token] ?? const CardValidation.notFound();
  }

  @override
  Future<void> regenerate(String seasonMembershipId) async {
    regenerated.add(seasonMembershipId);
    validations.clear();
  }

  @override
  Future<MembershipCard> getMyCard(String clubId) async {
    final card = cards[auth?.currentUser?.email];
    if (card == null) throw const NotAMemberFailure();
    return card;
  }
}

/// Payments per season membership; paying activates the member and
/// cancelling the only payment makes the fee pending again.
class FakePaymentsRepository implements PaymentsRepository {
  final Map<String, List<Payment>> payments = {};
  final Map<String, String> instructions = {};
  FakeMembersRepository? members;
  int _ids = 0;

  void _setSeasonStatus(String seasonMembershipId, SeasonMembershipStatus s) {
    for (final list in members?.members.values ?? <List<ClubMember>>[]) {
      final i = list.indexWhere(
        (m) => m.seasonMembershipId == seasonMembershipId,
      );
      if (i >= 0) list[i] = list[i].copyWith(seasonStatus: s);
    }
  }

  ClubMember? _member(String seasonMembershipId) => members?.members.values
      .expand((list) => list)
      .where((m) => m.seasonMembershipId == seasonMembershipId)
      .firstOrNull;

  @override
  Future<List<Payment>> getSeasonPayments(String seasonMembershipId) async =>
      [...?payments[seasonMembershipId]].reversed.toList();

  @override
  Future<void> recordManualPayment({
    required String seasonMembershipId,
    required PaymentMethod method,
    int? amountCents,
    DateTime? paidOn,
    String? reference,
  }) async {
    final list = payments.putIfAbsent(seasonMembershipId, () => []);
    if (list.any((p) => p.status == PaymentStatus.paid)) {
      throw const AlreadyPaidFailure();
    }
    list.add(
      Payment(
        id: 'pay-${++_ids}',
        seasonMembershipId: seasonMembershipId,
        amountCents:
            amountCents ?? _member(seasonMembershipId)!.seasonFeeCents!,
        concept: 'Cuota de socio 2026/2027',
        status: PaymentStatus.paid,
        provider: PaymentProvider.manual,
        method: method,
        reference: reference,
        paidAt: paidOn ?? DateTime(2026, 11, 9),
        createdAt: DateTime(2026, 11, 9),
      ),
    );
    _setSeasonStatus(seasonMembershipId, SeasonMembershipStatus.active);
  }

  @override
  Future<void> setStatus(String paymentId, PaymentStatus status) async {
    for (final list in payments.values) {
      final i = list.indexWhere((p) => p.id == paymentId);
      if (i < 0) continue;
      final p = list[i];
      list[i] = Payment(
        id: p.id,
        seasonMembershipId: p.seasonMembershipId,
        amountCents: p.amountCents,
        concept: p.concept,
        status: status,
        provider: p.provider,
        method: p.method,
        paidAt: p.paidAt,
        createdAt: p.createdAt,
      );
      if (!list.any((x) => x.status == PaymentStatus.paid)) {
        _setSeasonStatus(
          p.seasonMembershipId,
          SeasonMembershipStatus.pendingPayment,
        );
      }
    }
  }

  @override
  Future<String?> getPaymentInstructions(String clubId) async =>
      instructions[clubId];

  @override
  Future<void> setPaymentInstructions(String clubId, String text) async =>
      instructions[clubId] = text.trim();

  /// «Mi suscripción» and history, per club (signed-in member).
  final Map<String, MySubscription> subscriptions = {};
  final Map<String, List<MyPayment>> myPayments = {};

  @override
  Future<MySubscription> getMySubscription(String clubId) async =>
      subscriptions[clubId] ?? const MySubscription();

  @override
  Future<List<MyPayment>> getMyPayments(String clubId) async =>
      myPayments[clubId] ?? const [];

  /// Lines of the club payments screen, per club.
  final Map<String, List<ClubPaymentLine>> clubLines = {};
  final List<ClubPaymentsFilter> clubQueries = [];

  @override
  Future<ClubPaymentsPage> getClubPayments(
    String clubId, {
    ClubPaymentsFilter filter = const ClubPaymentsFilter(),
    int offset = 0,
    int limit = 50,
  }) async {
    clubQueries.add(filter);
    final query = filter.query.trim().toLowerCase();
    final all = [...?clubLines[clubId]]
        .where(
          (l) =>
              (filter.seasonId == null || l.seasonId == filter.seasonId) &&
              (filter.status == null || l.status == filter.status) &&
              (query.isEmpty ||
                  l.memberName.toLowerCase().contains(query) ||
                  l.memberEmail.contains(query) ||
                  '${l.memberNumber}' == query),
        )
        .toList();
    int sum(PaymentStatus status) => all
        .where((l) => l.status == status)
        .fold(0, (total, l) => total + l.amountCents);
    return ClubPaymentsPage(
      lines: all.skip(offset).take(limit).toList(),
      total: all.length,
      paidCents: sum(PaymentStatus.paid),
      pendingCents: sum(PaymentStatus.pending),
    );
  }

  /// Online payments (Stripe) per club; checkout pages per fee.
  final Map<String, OnlinePaymentsStatus> online = {};
  final Map<String, Uri> checkouts = {};
  bool onlineConfigured = true;

  @override
  Future<OnlinePaymentsStatus> getOnlinePaymentsStatus(String clubId) async =>
      online[clubId] ?? OnlinePaymentsStatus.notConnected;

  @override
  Future<Uri> startOnlinePaymentsOnboarding(String clubId) async {
    if (!onlineConfigured) throw const OnlinePaymentsUnavailableFailure();
    online[clubId] = OnlinePaymentsStatus.pendingVerification;
    return Uri.parse('https://connect.stripe.test/$clubId');
  }

  @override
  Future<OnlinePaymentsStatus> refreshOnlinePaymentsStatus(
    String clubId,
  ) async => online[clubId] ?? OnlinePaymentsStatus.notConnected;

  final List<bool> checkoutSaveFlags = [];

  @override
  Future<Uri> createCheckout(
    String seasonMembershipId, {
    bool saveForRenewal = false,
  }) async {
    final url = checkouts[seasonMembershipId];
    if (url == null) throw const OnlinePaymentsUnavailableFailure();
    checkoutSaveFlags.add(saveForRenewal);
    return url;
  }

  /// Saved methods per club (signed-in member).
  final Map<String, RenewalSetup> renewal = {};

  @override
  Future<RenewalSetup> getMyRenewalSetup(String clubId) async =>
      renewal[clubId] ?? RenewalSetup.none;

  @override
  Future<Uri> startPaymentMethodSetup(String clubId) async {
    if (!onlineConfigured) throw const OnlinePaymentsUnavailableFailure();
    return Uri.parse('https://checkout.stripe.test/setup/$clubId');
  }

  @override
  Future<void> removePaymentMethod(String clubId) async =>
      renewal[clubId] = RenewalSetup.none;

  /// Receipts by payment id; missing = not paid.
  final Map<String, Receipt> receipts = {};

  @override
  Future<Receipt> getReceipt(String paymentId) async {
    final receipt = receipts[paymentId];
    if (receipt == null) throw const NoReceiptFailure();
    return receipt;
  }
}

/// Records the receipts handed to the user instead of building PDFs.
class FakeReceiptRenderer implements ReceiptRenderer {
  final List<Receipt> delivered = [];

  @override
  Future<void> deliver(Receipt receipt) async => delivered.add(receipt);
}

AppUseCases buildUseCases({
  required FakeAuthRepository auth,
  required FakeClubRepository clubs,
  InMemoryActiveClubStore? store,
  FakePlatformRepository? platform,
  FakeClubBrandingRepository? branding,
  FakeMembersRepository? members,
  FakeOnboardingRepository? onboarding,
  FakeProfileRepository? profile,
  FakeSeasonRepository? seasons,
  FakeCardRepository? cards,
  FakePaymentsRepository? payments,
  FakeReceiptRenderer? receiptRenderer,
}) {
  final activeClubStore = store ?? InMemoryActiveClubStore();
  final platformRepository = platform ?? FakePlatformRepository();
  final brandingRepository = branding ?? FakeClubBrandingRepository(clubs);
  final profileRepository = (profile ?? FakeProfileRepository())..auth = auth;
  final seasonRepository = (seasons ?? FakeSeasonRepository())..clubs = clubs;
  final cardRepository = (cards ?? FakeCardRepository())..auth = auth;
  final onboardingRepository = (onboarding ?? FakeOnboardingRepository())
    ..auth = auth
    ..clubs = clubs;
  final membersRepository = (members ?? FakeMembersRepository())
    ..auth = auth
    ..clubs = clubs;
  seasonRepository.members = membersRepository;
  final paymentsRepository = (payments ?? FakePaymentsRepository())
    ..members = membersRepository;
  platformRepository.auth = auth;
  clubs
    ..auth = auth
    ..platform = platformRepository;
  return AppUseCases(
    watchSession: WatchSession(auth),
    signInWithPassword: SignInWithPassword(auth),
    signInWithGoogle: SignInWithGoogle(auth),
    signOut: SignOut(auth, activeClubStore),
    resolveClubEntry: ResolveClubEntry(clubs, activeClubStore),
    selectActiveClub: SelectActiveClub(activeClubStore),
    isPlatformAdmin: IsPlatformAdmin(platformRepository),
    getPlatformClubs: GetPlatformClubs(platformRepository),
    createClub: CreateClub(platformRepository),
    updateClub: UpdateClub(platformRepository),
    setClubActive: SetClubActive(platformRepository),
    getAuditLog: GetAuditLog(platformRepository),
    getClubMembers: GetClubMembers(membersRepository),
    inviteMember: InviteMember(membersRepository),
    resendInvitation: ResendInvitation(membersRepository),
    deactivateMember: DeactivateMember(membersRepository),
    reactivateMember: ReactivateMember(membersRepository),
    getMemberPhotoUrl: GetMemberPhotoUrl(membersRepository),
    setMemberNumber: SetMemberNumber(membersRepository),
    getOnboardingStatus: GetOnboardingStatus(onboardingRepository),
    verifyInvitationLink: VerifyInvitationLink(onboardingRepository),
    setNewPassword: SetNewPassword(onboardingRepository),
    completeOnboarding: CompleteOnboarding(onboardingRepository),
    getMyProfile: GetMyProfile(profileRepository),
    updateMyProfile: UpdateMyProfile(profileRepository),
    uploadProfilePhoto: UploadProfilePhoto(profileRepository),
    getSeasons: GetSeasons(seasonRepository),
    createSeason: CreateSeason(seasonRepository),
    activateSeason: ActivateSeason(seasonRepository),
    getMemberSeasons: GetMemberSeasons(seasonRepository),
    setMemberFee: SetMemberFee(seasonRepository),
    getRenewalCandidates: GetRenewalCandidates(seasonRepository),
    bulkRenew: BulkRenew(seasonRepository),
    getMyCard: GetMyCard(cardRepository),
    validateCard: ValidateCard(cardRepository),
    regenerateCard: RegenerateCard(cardRepository),
    getSeasonPayments: GetSeasonPayments(paymentsRepository),
    recordManualPayment: RecordManualPayment(paymentsRepository),
    cancelPayment: CancelPayment(paymentsRepository),
    getPaymentInstructions: GetPaymentInstructions(paymentsRepository),
    setPaymentInstructions: SetPaymentInstructions(paymentsRepository),
    startPayment: StartPayment(ManualPaymentGateway(paymentsRepository)),
    getMySubscription: GetMySubscription(paymentsRepository),
    getMyPayments: GetMyPayments(paymentsRepository),
    getClubPayments: GetClubPayments(paymentsRepository),
    startOnlinePayment: StartPayment(StripePaymentGateway(paymentsRepository)),
    getOnlinePaymentsStatus: GetOnlinePaymentsStatus(paymentsRepository),
    startOnlinePaymentsOnboarding: StartOnlinePaymentsOnboarding(
      paymentsRepository,
    ),
    refreshOnlinePaymentsStatus: RefreshOnlinePaymentsStatus(
      paymentsRepository,
    ),
    getMyRenewalSetup: GetMyRenewalSetup(paymentsRepository),
    startPaymentMethodSetup: StartPaymentMethodSetup(paymentsRepository),
    removePaymentMethod: RemovePaymentMethod(paymentsRepository),
    downloadReceipt: DownloadReceipt(
      paymentsRepository,
      receiptRenderer ?? FakeReceiptRenderer(),
    ),
    getClubBranding: GetClubBranding(brandingRepository),
    saveClubBranding: SaveClubBranding(brandingRepository),
    uploadClubAsset: UploadClubAsset(brandingRepository),
  );
}
