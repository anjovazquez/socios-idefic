import 'package:flutter/foundation.dart';

import '../../application/app_use_cases.dart';
import '../../domain/club/club_branding.dart';
import '../../domain/club/club_branding_repository.dart';
import 'image_picking.dart';

/// State of the club settings screen (§16 Configuración, §20).
class ClubSettingsViewModel extends ChangeNotifier {
  ClubSettingsViewModel(
    this._useCases, {
    required this.clubId,
    required this.pickImage,
    this.onSaved,
  });

  final AppUseCases _useCases;
  final String clubId;
  final PickImage pickImage;
  final Future<void> Function()? onSaved;

  ClubBranding? _draft;
  ClubBranding? get draft => _draft;

  /// Raw text typed in the color fields (may be invalid while typing).
  String primaryText = '';
  String secondaryText = '';

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isBusy = false;
  bool get isBusy => _isBusy;

  String? _error;
  String? get error => _error;

  /// Valid primary color for the preview, falling back to the saved one.
  String get previewPrimary =>
      normalizeHexColor(primaryText) ??
      _draft?.primaryColor ??
      ClubBranding.defaultPrimaryColor;

  String? get previewSecondary => normalizeHexColor(secondaryText);

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final branding = await _useCases.getClubBranding(clubId);
      _draft = branding;
      primaryText = branding.primaryColor;
      secondaryText = branding.secondaryColor ?? '';
    } on BrandingFailure catch (failure) {
      _error = messageFor(failure);
    } catch (_) {
      _error = messageFor(const BrandingUnavailableFailure());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setName(String name) => _update(_draft?.copyWith(name: name));

  void setPrimaryText(String value) {
    primaryText = value;
    notifyListeners();
  }

  void setSecondaryText(String value) {
    secondaryText = value;
    notifyListeners();
  }

  Future<void> pickAsset(ClubAssetKind kind) async {
    final picked = await pickImage();
    if (picked == null || _draft == null) return;
    await _busy(() async {
      final stored = await _useCases.uploadClubAsset(
        clubId: clubId,
        kind: kind,
        bytes: picked.bytes,
        contentType: picked.contentType,
      );
      _draft = switch (kind) {
        ClubAssetKind.logo => _draft!.copyWith(
          logoPath: () => stored.path,
          logoUrl: () => stored.url,
        ),
        ClubAssetKind.image => _draft!.copyWith(
          imagePath: () => stored.path,
          imageUrl: () => stored.url,
        ),
      };
    });
  }

  void removeAsset(ClubAssetKind kind) => _update(switch (kind) {
    ClubAssetKind.logo => _draft?.copyWith(
      logoPath: () => null,
      logoUrl: () => null,
    ),
    ClubAssetKind.image => _draft?.copyWith(
      imagePath: () => null,
      imageUrl: () => null,
    ),
  });

  /// Returns true when the changes were saved.
  Future<bool> save() async {
    final draft = _draft;
    if (draft == null) return false;
    final saved = await _busy(() async {
      await _useCases.saveClubBranding(
        draft.copyWith(
          primaryColor: primaryText,
          secondaryColor: () => secondaryText,
        ),
      );
      await onSaved?.call();
    });
    return saved;
  }

  void _update(ClubBranding? branding) {
    if (branding == null) return;
    _draft = branding;
    notifyListeners();
  }

  Future<bool> _busy(Future<void> Function() action) async {
    _isBusy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on BrandingFailure catch (failure) {
      _error = messageFor(failure);
      return false;
    } catch (_) {
      _error = messageFor(const BrandingUnavailableFailure());
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  static String messageFor(BrandingFailure failure) => switch (failure) {
    InvalidBrandingFailure(field: BrandingField.name) =>
      'Escribe el nombre del club',
    InvalidBrandingFailure(field: BrandingField.primaryColor) =>
      'El color principal debe tener el formato #RRGGBB',
    InvalidBrandingFailure(field: BrandingField.secondaryColor) =>
      'El color secundario debe tener el formato #RRGGBB',
    InvalidBrandingFailure(field: BrandingField.asset) ||
    InvalidAssetFailure() =>
      'La imagen debe ser PNG, JPG o WebP y pesar menos de 2 MB',
    BrandingPermissionFailure() =>
      'Solo el administrador del club puede cambiar su identidad',
    BrandingUnavailableFailure() =>
      'No hemos podido conectar. Inténtalo de nuevo en un momento',
  };
}
