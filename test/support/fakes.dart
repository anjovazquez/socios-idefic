import 'dart:async';
import 'dart:typed_data';

import 'package:socios_idefic/application/app_use_cases.dart';
import 'package:socios_idefic/application/auth/sign_in_with_google.dart';
import 'package:socios_idefic/application/auth/sign_in_with_password.dart';
import 'package:socios_idefic/application/auth/sign_out.dart';
import 'package:socios_idefic/application/auth/watch_session.dart';
import 'package:socios_idefic/application/club/club_branding_use_cases.dart';
import 'package:socios_idefic/application/club/resolve_club_entry.dart';
import 'package:socios_idefic/application/club/select_active_club.dart';
import 'package:socios_idefic/application/platform/platform_use_cases.dart';
import 'package:socios_idefic/domain/auth/auth_failures.dart';
import 'package:socios_idefic/domain/auth/auth_repository.dart';
import 'package:socios_idefic/domain/auth/auth_user.dart';
import 'package:socios_idefic/domain/club/active_club_store.dart';
import 'package:socios_idefic/domain/club/club_branding.dart';
import 'package:socios_idefic/domain/club/club_branding_repository.dart';
import 'package:socios_idefic/domain/club/club_repository.dart';
import 'package:socios_idefic/domain/club/my_club.dart';
import 'package:socios_idefic/domain/platform/audit_entry.dart';
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

AppUseCases buildUseCases({
  required FakeAuthRepository auth,
  required FakeClubRepository clubs,
  InMemoryActiveClubStore? store,
  FakePlatformRepository? platform,
  FakeClubBrandingRepository? branding,
}) {
  final activeClubStore = store ?? InMemoryActiveClubStore();
  final platformRepository = platform ?? FakePlatformRepository();
  final brandingRepository = branding ?? FakeClubBrandingRepository(clubs);
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
    getClubBranding: GetClubBranding(brandingRepository),
    saveClubBranding: SaveClubBranding(brandingRepository),
    uploadClubAsset: UploadClubAsset(brandingRepository),
  );
}
