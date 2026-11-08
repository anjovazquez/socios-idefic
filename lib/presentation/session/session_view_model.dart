import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../application/app_use_cases.dart';
import '../../application/club/resolve_club_entry.dart';
import '../../domain/auth/auth_user.dart';
import '../../domain/club/my_club.dart';

enum SessionStatus { loading, signedOut, noClubs, choosingClub, inClub, error }

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

  String? _userId;

  void start() {
    _onUser(_useCases.watchSession.currentUser);
    _subscription = _useCases.watchSession().listen(_onUser);
  }

  void _onUser(AuthUser? user) {
    if (user == null) {
      _userId = null;
      _clubs = const [];
      _activeClub = null;
      _setStatus(SessionStatus.signedOut);
      return;
    }
    if (user.id == _userId) return;
    _userId = user.id;
    unawaited(loadClubs());
  }

  Future<void> loadClubs() async {
    _setStatus(SessionStatus.loading);
    try {
      final entry = await _useCases.resolveClubEntry();
      _clubs = entry.clubs;
      switch (entry) {
        case NoClubEntry():
          _activeClub = null;
          _setStatus(SessionStatus.noClubs);
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

  Future<void> signOut() => _useCases.signOut();

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
