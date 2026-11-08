import '../../domain/card/card_repository.dart';
import '../../domain/card/card_validation.dart';
import '../../domain/card/membership_card.dart';

class GetMyCard {
  const GetMyCard(this._repository);

  final CardRepository _repository;

  Future<MembershipCard> call(String clubId) => _repository.getMyCard(clubId);
}

class ValidateCard {
  const ValidateCard(this._repository);

  final CardRepository _repository;

  Future<CardValidation> call(String token) async {
    final trimmed = token.trim();
    if (!RegExp(r'^[A-Za-z0-9_-]{16,64}$').hasMatch(trimmed)) {
      return const CardValidation.notFound();
    }
    return _repository.validate(trimmed);
  }
}

class RegenerateCard {
  const RegenerateCard(this._repository);

  final CardRepository _repository;

  Future<void> call(String seasonMembershipId) =>
      _repository.regenerate(seasonMembershipId);
}
