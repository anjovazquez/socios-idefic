sealed class PlatformFailure implements Exception {
  const PlatformFailure();
}

enum ClubField { name, code, adminEmail }

final class InvalidClubDataFailure extends PlatformFailure {
  const InvalidClubDataFailure(this.field);

  final ClubField field;
}

final class DuplicateClubCodeFailure extends PlatformFailure {
  const DuplicateClubCodeFailure();
}

/// MVP rule: one administrator per club (§3.2).
final class ClubAlreadyHasAdminFailure extends PlatformFailure {
  const ClubAlreadyHasAdminFailure();
}

final class NotPlatformAdminFailure extends PlatformFailure {
  const NotPlatformAdminFailure();
}

final class PlatformUnavailableFailure extends PlatformFailure {
  const PlatformUnavailableFailure([this.cause]);

  final Object? cause;
}
