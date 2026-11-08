import 'dart:typed_data';

import '../../domain/sponsor/sponsor.dart';

class GetClubSponsors {
  const GetClubSponsors(this._repository);

  final SponsorRepository _repository;

  Future<List<Sponsor>> call(String clubId) =>
      _repository.getClubSponsors(clubId);
}

/// Creates or edits a sponsor and its seasons in one step.
class SaveSponsor {
  const SaveSponsor(this._repository);

  final SponsorRepository _repository;

  Future<String> call({
    String? sponsorId,
    required String clubId,
    required String name,
    String? logoPath,
    String website = '',
    required List<String> seasonIds,
  }) async {
    final cleanName = name.trim();
    if (cleanName.length < 2 || cleanName.length > 80) {
      throw const InvalidSponsorFailure(SponsorField.name);
    }
    if (!isValidSponsorWebsite(website)) {
      throw const InvalidSponsorFailure(SponsorField.website);
    }
    final id = await _repository.saveSponsor(
      sponsorId: sponsorId,
      clubId: clubId,
      name: cleanName,
      logoPath: logoPath,
      websiteUrl: website.trim().isEmpty ? null : website.trim(),
    );
    await _repository.setSeasons(id, seasonIds);
    return id;
  }
}

class SetSponsorActive {
  const SetSponsorActive(this._repository);

  final SponsorRepository _repository;

  Future<void> call(String sponsorId, bool active) =>
      _repository.setActive(sponsorId, active);
}

class RenewSponsors {
  const RenewSponsors(this._repository);

  final SponsorRepository _repository;

  Future<int> call(String seasonId, List<String> sponsorIds) {
    if (sponsorIds.isEmpty) {
      throw const InvalidSponsorFailure(SponsorField.seasons);
    }
    return _repository.renew(seasonId, sponsorIds);
  }
}

class UploadSponsorLogo {
  const UploadSponsorLogo(this._repository);

  final SponsorRepository _repository;

  Future<String> call({
    required String clubId,
    required Uint8List bytes,
    required String contentType,
  }) {
    if (bytes.length > 2 * 1024 * 1024 ||
        !const [
          'image/png',
          'image/jpeg',
          'image/webp',
        ].contains(contentType)) {
      throw const InvalidSponsorFailure(SponsorField.logo);
    }
    return _repository.uploadLogo(
      clubId: clubId,
      bytes: bytes,
      contentType: contentType,
    );
  }
}

class GetActiveSponsors {
  const GetActiveSponsors(this._repository);

  final SponsorRepository _repository;

  Future<List<Sponsor>> call(String clubId) =>
      _repository.getActiveSponsors(clubId);
}
