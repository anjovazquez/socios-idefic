import 'package:flutter/foundation.dart';

import '../../application/app_use_cases.dart';
import '../../domain/platform/platform_club.dart';
import '../../domain/platform/platform_failures.dart';

class PlatformViewModel extends ChangeNotifier {
  PlatformViewModel(this._useCases, {this.onClubsChanged});

  final AppUseCases _useCases;

  /// Lets the session refresh the club selector after a change.
  final Future<void> Function()? onClubsChanged;

  List<PlatformClub> _clubs = const [];
  List<PlatformClub> get clubs => _clubs;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _loadError;
  String? get loadError => _loadError;

  Future<void> load() async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      _clubs = await _useCases.getPlatformClubs();
    } on PlatformFailure catch (failure) {
      _loadError = messageFor(failure);
    } catch (_) {
      _loadError = messageFor(const PlatformUnavailableFailure());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Returns an error message, or null when the club was created.
  Future<String?> createClub({
    required String name,
    required String code,
    required String adminEmail,
    String? adminName,
  }) => _mutate(
    () => _useCases.createClub(
      name: name,
      code: code,
      adminEmail: adminEmail,
      adminName: adminName,
    ),
  );

  Future<String?> updateClub({
    required String clubId,
    required String name,
    required String code,
  }) => _mutate(
    () => _useCases.updateClub(clubId: clubId, name: name, code: code),
  );

  Future<String?> setActive(PlatformClub club, {required bool active}) =>
      _mutate(() => _useCases.setClubActive(clubId: club.id, active: active));

  Future<String?> _mutate(Future<Object?> Function() action) async {
    try {
      await action();
    } on PlatformFailure catch (failure) {
      return messageFor(failure);
    } catch (_) {
      return messageFor(const PlatformUnavailableFailure());
    }
    await load();
    await onClubsChanged?.call();
    return null;
  }

  static String messageFor(PlatformFailure failure) => switch (failure) {
    InvalidClubDataFailure(field: ClubField.name) =>
      'Escribe el nombre del club',
    InvalidClubDataFailure(field: ClubField.code) =>
      'El código debe tener entre 2 y 20 letras o números',
    InvalidClubDataFailure(field: ClubField.adminEmail) =>
      'Escribe un email válido para el administrador',
    DuplicateClubCodeFailure() => 'Ese código ya está en uso',
    ClubAlreadyHasAdminFailure() => 'Este club ya tiene administrador',
    NotPlatformAdminFailure() => 'No tienes permiso para gestionar clubes',
    PlatformUnavailableFailure() =>
      'No hemos podido conectar. Inténtalo de nuevo en un momento',
  };
}
