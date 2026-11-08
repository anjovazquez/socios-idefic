/// A perk for the members of a club (RF-024, RN-015), optionally offered by
/// one of its sponsors.
enum PerkStatus { draft, published, archived }

/// What members see today.
enum PerkVisibility { visible, upcoming, expired, draft, archived }

class Perk {
  const Perk({
    required this.id,
    required this.title,
    required this.body,
    required this.status,
    this.sponsorId,
    this.sponsorName,
    this.imagePath,
    this.validFrom,
    this.validUntil,
  });

  final String id;
  final String title;
  final String body;
  final PerkStatus status;
  final String? sponsorId;
  final String? sponsorName;
  final String? imagePath;
  final DateTime? validFrom;
  final DateTime? validUntil;

  PerkVisibility visibilityOn(DateTime today) {
    final day = DateTime(today.year, today.month, today.day);
    return switch (status) {
      PerkStatus.draft => PerkVisibility.draft,
      PerkStatus.archived => PerkVisibility.archived,
      PerkStatus.published when validFrom != null && validFrom!.isAfter(day) =>
        PerkVisibility.upcoming,
      PerkStatus.published
          when validUntil != null && validUntil!.isBefore(day) =>
        PerkVisibility.expired,
      PerkStatus.published => PerkVisibility.visible,
    };
  }
}

enum PerkField { title, body, dates, sponsor, image }

sealed class PerkFailure implements Exception {
  const PerkFailure();
}

final class InvalidPerkFailure extends PerkFailure {
  const InvalidPerkFailure(this.field);

  final PerkField field;
}

final class PerkPermissionFailure extends PerkFailure {
  const PerkPermissionFailure();
}

final class PerkUnavailableFailure extends PerkFailure {
  const PerkUnavailableFailure([this.cause]);

  final Object? cause;
}

abstract interface class PerkRepository {
  /// Admin: every perk of the club.
  Future<List<Perk>> getClubPerks(String clubId);

  /// Creates ([perkId] null) or edits; [publish] or draft. Returns the id.
  Future<String> savePerk({
    String? perkId,
    required String clubId,
    String? sponsorId,
    required String title,
    required String body,
    String? imagePath,
    DateTime? validFrom,
    DateTime? validUntil,
    required bool publish,
  });

  /// Archive or back to draft.
  Future<void> setStatus(String perkId, PerkStatus status);
}
