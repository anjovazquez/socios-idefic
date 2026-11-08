import 'package:flutter/foundation.dart';

import '../../application/app_use_cases.dart';
import '../../domain/season/season.dart';
import '../../domain/sponsor/sponsor.dart';
import '../club/image_picking.dart';

String sponsorFailureMessage(SponsorFailure failure) => switch (failure) {
  InvalidSponsorFailure(field: SponsorField.name) =>
    'El nombre debe tener entre 2 y 80 caracteres',
  InvalidSponsorFailure(field: SponsorField.website) =>
    'La web debe empezar por https://, por ejemplo https://restaurante.es',
  InvalidSponsorFailure(field: SponsorField.logo) =>
    'El logo debe ser PNG, JPG o WebP de 2 MB como máximo',
  InvalidSponsorFailure(field: SponsorField.seasons) =>
    'Elige al menos un patrocinador',
  SponsorAlreadyExistsFailure() => 'Ya hay un patrocinador con ese nombre',
  SponsorPermissionFailure() =>
    'Solo el administrador del club puede gestionar patrocinadores',
  SponsorUnavailableFailure() =>
    'No hemos podido conectar. Inténtalo de nuevo en un momento',
};

/// Sponsors of the club and their seasons (RF-026…RF-028).
class SponsorsViewModel extends ChangeNotifier {
  SponsorsViewModel(
    this._useCases, {
    required this.clubId,
    required this.pickImage,
  });

  final AppUseCases _useCases;
  final String clubId;
  final PickImage pickImage;

  List<Sponsor> _sponsors = const [];
  List<Sponsor> get sponsors => _sponsors;

  List<Season> _seasons = const [];

  /// Seasons that can be linked (not closed first, newest first).
  List<Season> get seasons => _seasons;

  Season? get activeSeason =>
      _seasons.where((s) => s.status == SeasonStatus.active).firstOrNull;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _loadError;
  String? get loadError => _loadError;

  Future<void> load() async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _useCases.getClubSponsors(clubId),
        _useCases.getSeasons(clubId),
      ]);
      _sponsors = results[0] as List<Sponsor>;
      _seasons = results[1] as List<Season>;
    } on SponsorFailure catch (failure) {
      _loadError = sponsorFailureMessage(failure);
    } catch (_) {
      _loadError = sponsorFailureMessage(const SponsorUnavailableFailure());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Active sponsors of the season before the active one that are not yet in
  /// the active season (RF-028: renewal is explicit).
  List<Sponsor> get renewalCandidates {
    final active = activeSeason;
    if (active == null) return const [];
    final previous = _seasons
        .where((s) => s.id != active.id && s.name.compareTo(active.name) < 0)
        .fold<Season?>(
          null,
          (best, s) =>
              best == null || s.name.compareTo(best.name) > 0 ? s : best,
        );
    if (previous == null) return const [];
    return _sponsors
        .where(
          (s) =>
              s.isActive &&
              s.seasonIds.contains(previous.id) &&
              !s.seasonIds.contains(active.id),
        )
        .toList();
  }

  /// Returns the confirmation, or throws the error message.
  Future<String> save({
    Sponsor? sponsor,
    required String name,
    required String website,
    String? logoPath,
    required List<String> seasonIds,
  }) async {
    await _guard(
      () => _useCases.saveSponsor(
        sponsorId: sponsor?.id,
        clubId: clubId,
        name: name,
        website: website,
        logoPath: logoPath,
        seasonIds: seasonIds,
      ),
    );
    await load();
    return sponsor == null
        ? 'Patrocinador ${name.trim()} dado de alta'
        : 'Cambios guardados';
  }

  /// Uploads a chosen logo; returns its path (null if nothing was chosen).
  Future<({String path, Uint8List bytes})?> chooseLogo() async {
    final picked = await pickImage();
    if (picked == null) return null;
    String? path;
    await _guard(() async {
      path = await _useCases.uploadSponsorLogo(
        clubId: clubId,
        bytes: picked.bytes,
        contentType: picked.contentType,
      );
    });
    return (path: path!, bytes: picked.bytes);
  }

  Future<String> setActive(Sponsor sponsor, bool active) async {
    await _guard(() => _useCases.setSponsorActive(sponsor.id, active));
    await load();
    return active
        ? '${sponsor.name} vuelve a mostrarse a los socios'
        : '${sponsor.name} ya no se muestra a los socios';
  }

  Future<String> renew(List<String> sponsorIds) async {
    final season = activeSeason!;
    var added = 0;
    await _guard(() async {
      added = await _useCases.renewSponsors(season.id, sponsorIds);
    });
    await load();
    return added == 1
        ? '1 patrocinador renovado para ${season.name}'
        : '$added patrocinadores renovados para ${season.name}';
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on SponsorFailure catch (failure) {
      throw sponsorFailureMessage(failure);
    } catch (error) {
      if (error is String) rethrow;
      throw sponsorFailureMessage(const SponsorUnavailableFailure());
    }
  }
}
