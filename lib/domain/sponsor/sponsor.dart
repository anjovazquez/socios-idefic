import 'dart:typed_data';

/// A sponsor of the club, linked to seasons (RF-026…RF-028, RN-016).
class Sponsor {
  const Sponsor({
    required this.id,
    required this.name,
    this.logoPath,
    this.logoUrl,
    this.websiteUrl,
    this.isActive = true,
    this.seasonIds = const [],
    this.seasonNames = const [],
  });

  final String id;
  final String name;
  final String? logoPath;

  /// Public URL of [logoPath] (club-assets).
  final String? logoUrl;
  final String? websiteUrl;
  final bool isActive;
  final List<String> seasonIds;
  final List<String> seasonNames;
}

final _httpsUrl = RegExp(r'^https://[^\s/?#]+\.[^\s]+$');

/// Only https web addresses (empty is fine).
bool isValidSponsorWebsite(String value) =>
    value.trim().isEmpty || _httpsUrl.hasMatch(value.trim());

enum SponsorField { name, website, logo, seasons }

sealed class SponsorFailure implements Exception {
  const SponsorFailure();
}

final class InvalidSponsorFailure extends SponsorFailure {
  const InvalidSponsorFailure(this.field);

  final SponsorField field;
}

final class SponsorAlreadyExistsFailure extends SponsorFailure {
  const SponsorAlreadyExistsFailure();
}

final class SponsorPermissionFailure extends SponsorFailure {
  const SponsorPermissionFailure();
}

final class SponsorUnavailableFailure extends SponsorFailure {
  const SponsorUnavailableFailure([this.cause]);

  final Object? cause;
}

abstract interface class SponsorRepository {
  Future<List<Sponsor>> getClubSponsors(String clubId);

  /// Creates ([sponsorId] null) or edits; returns the id.
  Future<String> saveSponsor({
    String? sponsorId,
    required String clubId,
    required String name,
    String? logoPath,
    String? websiteUrl,
  });

  Future<void> setActive(String sponsorId, bool active);

  /// Replaces the seasons of a sponsor.
  Future<void> setSeasons(String sponsorId, List<String> seasonIds);

  /// Adds the sponsors to a season; returns how many were new.
  Future<int> renew(String seasonId, List<String> sponsorIds);

  Future<String> uploadLogo({
    required String clubId,
    required Uint8List bytes,
    required String contentType,
  });

  String logoUrl(String path);
}
