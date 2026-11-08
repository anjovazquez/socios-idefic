import '../../domain/card/card_repository.dart';
import '../../domain/card/membership_card.dart';

class GetMyCard {
  const GetMyCard(this._repository);

  final CardRepository _repository;

  Future<MembershipCard> call(String clubId) => _repository.getMyCard(clubId);
}
