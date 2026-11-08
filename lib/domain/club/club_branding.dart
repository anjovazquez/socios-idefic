/// Visual identity of a club (§20).
class ClubBranding {
  const ClubBranding({
    required this.clubId,
    required this.name,
    required this.primaryColor,
    this.secondaryColor,
    this.logoPath,
    this.imagePath,
    this.logoUrl,
    this.imageUrl,
  });

  final String clubId;
  final String name;

  /// `#RRGGBB`, upper case.
  final String primaryColor;
  final String? secondaryColor;

  /// Storage paths inside the club folder.
  final String? logoPath;
  final String? imagePath;

  /// Public URLs resolved from the paths.
  final String? logoUrl;
  final String? imageUrl;

  /// Default color for clubs that never chose one.
  static const defaultPrimaryColor = '#0B3D91';

  ClubBranding copyWith({
    String? name,
    String? primaryColor,
    String? Function()? secondaryColor,
    String? Function()? logoPath,
    String? Function()? imagePath,
    String? Function()? logoUrl,
    String? Function()? imageUrl,
  }) => ClubBranding(
    clubId: clubId,
    name: name ?? this.name,
    primaryColor: primaryColor ?? this.primaryColor,
    secondaryColor: secondaryColor == null
        ? this.secondaryColor
        : secondaryColor(),
    logoPath: logoPath == null ? this.logoPath : logoPath(),
    imagePath: imagePath == null ? this.imagePath : imagePath(),
    logoUrl: logoUrl == null ? this.logoUrl : logoUrl(),
    imageUrl: imageUrl == null ? this.imageUrl : imageUrl(),
  );
}

enum BrandingField { name, primaryColor, secondaryColor, asset }

sealed class BrandingFailure implements Exception {
  const BrandingFailure();
}

final class InvalidBrandingFailure extends BrandingFailure {
  const InvalidBrandingFailure(this.field);

  final BrandingField field;
}

/// Image too big or not PNG/JPEG/WebP.
final class InvalidAssetFailure extends BrandingFailure {
  const InvalidAssetFailure();
}

final class BrandingPermissionFailure extends BrandingFailure {
  const BrandingPermissionFailure();
}

final class BrandingUnavailableFailure extends BrandingFailure {
  const BrandingUnavailableFailure([this.cause]);

  final Object? cause;
}

final _hexColor = RegExp(r'^#[0-9A-Fa-f]{6}$');

/// Normalizes `#rrggbb` (with or without `#`) or returns null if invalid.
String? normalizeHexColor(String? value) {
  if (value == null) return null;
  var hex = value.trim();
  if (!hex.startsWith('#')) hex = '#$hex';
  return _hexColor.hasMatch(hex) ? hex.toUpperCase() : null;
}
