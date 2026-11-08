enum ValidationState { active, notCurrent, notFound }

/// What the public validation screen shows after scanning a QR (RF-020).
/// Never phone, email, birth date or payment data.
class CardValidation {
  const CardValidation({
    required this.state,
    this.clubName,
    this.clubLogoUrl,
    this.primaryColor,
    this.firstName,
    this.lastName,
    this.photoUrl,
    this.memberNumber,
    this.seasonName,
  });

  const CardValidation.notFound() : this(state: ValidationState.notFound);

  final ValidationState state;
  final String? clubName;
  final String? clubLogoUrl;
  final String? primaryColor;
  final String? firstName;
  final String? lastName;
  final String? photoUrl;
  final int? memberNumber;
  final String? seasonName;

  String get fullName => [
    firstName,
    lastName,
  ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
}

/// URL encoded in the QR: `<app>/#/v/<token>`.
String cardValidationUrl(String appUrl, String token) =>
    '${appUrl.replaceAll(RegExp(r'/+$'), '')}/#/v/$token';
