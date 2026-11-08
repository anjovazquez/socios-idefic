import '../../domain/perk/perk.dart';

class GetClubPerks {
  const GetClubPerks(this._repository);

  final PerkRepository _repository;

  Future<List<Perk>> call(String clubId) => _repository.getClubPerks(clubId);
}

class SavePerk {
  const SavePerk(this._repository);

  final PerkRepository _repository;

  Future<String> call({
    String? perkId,
    required String clubId,
    String? sponsorId,
    required String title,
    required String body,
    String? imagePath,
    DateTime? validFrom,
    DateTime? validUntil,
    required bool publish,
  }) {
    final cleanTitle = title.trim();
    if (cleanTitle.length < 3 || cleanTitle.length > 120) {
      throw const InvalidPerkFailure(PerkField.title);
    }
    if (body.trim().isEmpty || body.trim().length > 4000) {
      throw const InvalidPerkFailure(PerkField.body);
    }
    if (validFrom != null &&
        validUntil != null &&
        validUntil.isBefore(validFrom)) {
      throw const InvalidPerkFailure(PerkField.dates);
    }
    return _repository.savePerk(
      perkId: perkId,
      clubId: clubId,
      sponsorId: sponsorId,
      title: cleanTitle,
      body: body.trim(),
      imagePath: imagePath,
      validFrom: validFrom,
      validUntil: validUntil,
      publish: publish,
    );
  }
}

class SetPerkStatus {
  const SetPerkStatus(this._repository);

  final PerkRepository _repository;

  Future<void> call(String perkId, PerkStatus status) {
    if (status == PerkStatus.published) {
      throw const InvalidPerkFailure(PerkField.title);
    }
    return _repository.setStatus(perkId, status);
  }
}
