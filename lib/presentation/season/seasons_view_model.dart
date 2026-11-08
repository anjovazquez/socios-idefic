import 'package:flutter/foundation.dart';

import '../../application/app_use_cases.dart';
import '../../domain/season/season.dart';

class SeasonsViewModel extends ChangeNotifier {
  SeasonsViewModel(this._useCases, {required this.clubId, this.onChanged});

  final AppUseCases _useCases;
  final String clubId;

  /// Refreshes the session so the home shows the new active season.
  final Future<void> Function()? onChanged;

  List<Season> _seasons = const [];
  List<Season> get seasons => _seasons;

  Season? get active =>
      _seasons.where((s) => s.status == SeasonStatus.active).firstOrNull;

  String get suggestedName => suggestNextSeasonName(_seasons);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _loadError;
  String? get loadError => _loadError;

  Future<void> load() async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      _seasons = await _useCases.getSeasons(clubId);
    } on SeasonFailure catch (failure) {
      _loadError = messageFor(failure);
    } catch (_) {
      _loadError = messageFor(const SeasonUnavailableFailure());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Returns the confirmation, or throws the error message.
  Future<String> create({
    required String name,
    DateTime? startsOn,
    DateTime? endsOn,
  }) async {
    await _guard(
      () => _useCases.createSeason(
        clubId: clubId,
        name: name,
        startsOn: startsOn,
        endsOn: endsOn,
      ),
    );
    await load();
    return 'Temporada ${name.trim()} creada';
  }

  Future<String> activate(Season season, String fee) async {
    await _guard(() => _useCases.activateSeason(season: season, fee: fee));
    await load();
    await onChanged?.call();
    return 'Temporada ${season.name} activa';
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on SeasonFailure catch (failure) {
      throw messageFor(failure);
    } catch (error) {
      if (error is String) rethrow;
      throw messageFor(const SeasonUnavailableFailure());
    }
  }

  static String messageFor(SeasonFailure failure) => switch (failure) {
    InvalidSeasonDataFailure(field: SeasonField.name) =>
      'El nombre debe ser dos años seguidos, p. ej. 2026/2027',
    InvalidSeasonDataFailure(field: SeasonField.dates) =>
      'La fecha de fin debe ser posterior a la de inicio',
    InvalidSeasonDataFailure(field: SeasonField.fee) =>
      'Indica la cuota de la temporada',
    SeasonAlreadyExistsFailure() => 'Ya existe una temporada con ese nombre',
    SeasonClosedFailure() =>
      'Una temporada cerrada no se puede volver a activar',
    SeasonPermissionFailure() =>
      'Solo el administrador del club puede gestionar temporadas',
    SeasonUnavailableFailure() =>
      'No hemos podido conectar. Inténtalo de nuevo en un momento',
  };
}
