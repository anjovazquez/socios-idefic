import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../application/app_use_cases.dart';
import '../../application/club/resolve_club_entry.dart';
import '../../domain/auth/auth_failures.dart';
import '../../domain/auth/auth_user.dart';
import '../../domain/club/my_club.dart';

enum SessionStatus {
  loading,
  signedOut,
  noClubs,
  choosingClub,
  inClub,
  platform,
  error,
}

/// Presentation state of the session: who is signed in and which club is open.
class SessionViewModel extends ChangeNotifier {
  SessionViewModel(this._useCases);

  final AppUseCases _useCases;
  StreamSubscription<AuthUser?>? _subscription;

  SessionStatus _status = SessionStatus.loading;
  SessionStatus get status => _status;

  List<MyClub> _clubs = const [];
  List<MyClub> get clubs => _clubs;

  MyClub? _activeClub;
  MyClub? get activeClub => _activeClub;

  bool get canSwitchClub => _clubs.length > 1;

  bool _isPlatformAdmin = false;

  /// Shows the platform administration entry (§3.1).
  bool get isPlatformAdmin => _isPlatformAdmin;

  String? _userId;

  /// Failure raised while a provider (Google) sends the user back.
  AuthFailure? _signInFailure;
  AuthFailure? get signInFailure => _signInFailure;

  void start() {
    _onUser(_useCases.watchSession.currentUser);
    _subscription = _useCases.watchSession().listen(
      _onUser,
      onError: (Object error) {
        _signInFailure = error is AuthFailure
            ? error
            : AuthUnavailableFailure(error);
        notifyListeners();
      },
    );
  }

  void _onUser(AuthUser? user) {
    if (user == null) {
      _userId = null;
      _isPlatformAdmin = false;
      _clubs = const [];
      _activeClub = null;
      _setStatus(SessionStatus.signedOut);
      return;
    }
    if (user.id == _userId) return;
    _userId = user.id;
    _signInFailure = null;
    unawaited(loadClubs());
  }

  Future<void> loadClubs() async {
    _setStatus(SessionStatus.loading);
    try {
      final (entry, isPlatformAdmin) = await (
        _useCases.resolveClubEntry(),
        _useCases.isPlatformAdmin(),
      ).wait;
      _isPlatformAdmin = isPlatformAdmin;
      _clubs = entry.clubs;
      switch (entry) {
        case NoClubEntry():
          _activeClub = null;
          _setStatus(
            isPlatformAdmin ? SessionStatus.platform : SessionStatus.noClubs,
          );
        case ChooseClubEntry():
          _activeClub = null;
          _setStatus(SessionStatus.choosingClub);
        case EnterClubEntry(:final club):
          _activeClub = club;
          _setStatus(SessionStatus.inClub);
      }
    } catch (_) {
      _setStatus(SessionStatus.error);
    }
  }

  Future<void> selectClub(String clubId) async {
    _activeClub = await _useCases.selectActiveClub(clubId, _clubs);
    _setStatus(SessionStatus.inClub);
  }

  /// Opens the selector while keeping the session (RF-030).
  void openClubSelector() => _setStatus(SessionStatus.choosingClub);

  void openPlatform() {
    if (_isPlatformAdmin) _setStatus(SessionStatus.platform);
  }

  /// Leaves the platform administration back to the club or the selector.
  void closePlatform() {
    if (_activeClub != null) {
      _setStatus(SessionStatus.inClub);
    } else if (_clubs.isNotEmpty) {
      _setStatus(SessionStatus.choosingClub);
    }
  }

  /// Reloads the clubs the user can enter without leaving the current screen
  /// (e.g. after the platform admin creates or deactivates a club).
  Future<void> refreshClubs() async {
    final entry = await _useCases.resolveClubEntry();
    _clubs = entry.clubs;
    if (_activeClub case final active?
        when !_clubs.any((club) => club.id == active.id)) {
      _activeClub = null;
    }
    notifyListeners();
  }

  Future<void> signOut() => _useCases.signOut();

  void clearSignInFailure() {
    if (_signInFailure == null) return;
    _signInFailure = null;
    notifyListeners();
  }

  void _setStatus(SessionStatus status) {
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
