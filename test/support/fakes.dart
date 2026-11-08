import 'dart:async';

import 'package:socios_idefic/application/app_use_cases.dart';
import 'package:socios_idefic/application/auth/sign_in_with_google.dart';
import 'package:socios_idefic/application/auth/sign_in_with_password.dart';
import 'package:socios_idefic/application/auth/sign_out.dart';
import 'package:socios_idefic/application/auth/watch_session.dart';
import 'package:socios_idefic/application/club/resolve_club_entry.dart';
import 'package:socios_idefic/application/club/select_active_club.dart';
import 'package:socios_idefic/domain/auth/auth_failures.dart';
import 'package:socios_idefic/domain/auth/auth_repository.dart';
import 'package:socios_idefic/domain/auth/auth_user.dart';
import 'package:socios_idefic/domain/club/active_club_store.dart';
import 'package:socios_idefic/domain/club/club_repository.dart';
import 'package:socios_idefic/domain/club/my_club.dart';

const idefic = MyClub(
  id: 'club-idefic',
  name: 'IDEFIC',
  code: 'IDEFIC',
  role: ClubRole.member,
  primaryColor: '#0B3D91',
  memberNumber: 2,
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
  List<MyClub> fixed = const [];

  @override
  Future<List<MyClub>> getMyClubs() async {
    final email = auth?.currentUser?.email;
    if (email == null) return fixed;
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

AppUseCases buildUseCases({
  required FakeAuthRepository auth,
  required FakeClubRepository clubs,
  InMemoryActiveClubStore? store,
}) {
  final activeClubStore = store ?? InMemoryActiveClubStore();
  clubs.auth = auth;
  return AppUseCases(
    watchSession: WatchSession(auth),
    signInWithPassword: SignInWithPassword(auth),
    signInWithGoogle: SignInWithGoogle(auth),
    signOut: SignOut(auth, activeClubStore),
    resolveClubEntry: ResolveClubEntry(clubs, activeClubStore),
    selectActiveClub: SelectActiveClub(activeClubStore),
  );
}
