import 'platform_failures.dart';

/// Validated club data. The server repeats these rules.
class ClubData {
  ClubData._(this.name, this.code);

  factory ClubData({required String name, required String code}) {
    final trimmedName = name.trim();
    final normalizedCode = normalizeClubCode(code);
    if (trimmedName.isEmpty) {
      throw const InvalidClubDataFailure(ClubField.name);
    }
    if (!_codePattern.hasMatch(normalizedCode)) {
      throw const InvalidClubDataFailure(ClubField.code);
    }
    return ClubData._(trimmedName, normalizedCode);
  }

  static final _codePattern = RegExp(r'^[A-Z0-9_-]{2,20}$');

  final String name;
  final String code;
}

String normalizeClubCode(String code) =>
    code.replaceAll(RegExp(r'\s+'), '').toUpperCase();

/// Lowercase email or [InvalidClubDataFailure] for the admin field.
String normalizeAdminEmail(String email) {
  final normalized = email.trim().toLowerCase();
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalized)) {
    throw const InvalidClubDataFailure(ClubField.adminEmail);
  }
  return normalized;
}
