import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/card/card_repository.dart';
import '../../domain/card/card_validation.dart';
import '../../domain/card/membership_card.dart';

class SupabaseCardRepository implements CardRepository {
  const SupabaseCardRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<MembershipCard> getMyCard(String clubId) async {
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'get_my_card',
        params: {'p_club_id': clubId},
      );
      final row = rows.cast<Map<String, dynamic>>().single;
      final logo = row['club_logo_path'] as String?;
      final photo = row['photo_path'] as String?;
      return membershipCardFromRow(
        row,
        logoUrl: logo == null
            ? null
            : _client.storage.from('club-assets').getPublicUrl(logo),
        photoUrl: photo == null
            ? null
            : await _client.storage
                  .from('profile-photos')
                  .createSignedUrl(photo, 3600),
      );
    } on PostgrestException catch (error) {
      throw error.code == '42501'
          ? const NotAMemberFailure()
          : CardUnavailableFailure(error);
    } on CardFailure {
      rethrow;
    } catch (error) {
      throw CardUnavailableFailure(error);
    }
  }

  @override
  Future<CardValidation> validate(String token) async {
    try {
      final response = await _client.functions.invoke(
        'validate-card',
        body: {'token': token},
      );
      return cardValidationFromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } catch (error) {
      throw CardUnavailableFailure(error);
    }
  }

  @override
  Future<void> regenerate(String seasonMembershipId) async {
    try {
      await _client.rpc<void>(
        'regenerate_card_token',
        params: {'p_season_membership_id': seasonMembershipId},
      );
    } on PostgrestException catch (error) {
      throw error.code == '42501'
          ? const NotAMemberFailure()
          : CardUnavailableFailure(error);
    }
  }
}

CardValidation cardValidationFromJson(Map<String, dynamic> json) {
  final club = (json['club'] as Map?)?.cast<String, dynamic>();
  final member = (json['member'] as Map?)?.cast<String, dynamic>();
  return CardValidation(
    state: switch (json['state']) {
      'active' => ValidationState.active,
      'not_current' => ValidationState.notCurrent,
      _ => ValidationState.notFound,
    },
    clubName: club?['name'] as String?,
    clubLogoUrl: club?['logoUrl'] as String?,
    primaryColor: club?['primaryColor'] as String?,
    firstName: member?['firstName'] as String?,
    lastName: member?['lastName'] as String?,
    photoUrl: member?['photoUrl'] as String?,
    memberNumber: member?['memberNumber'] as int?,
    seasonName: json['seasonName'] as String?,
  );
}

MembershipCard membershipCardFromRow(
  Map<String, dynamic> row, {
  String? logoUrl,
  String? photoUrl,
}) => MembershipCard(
  clubName: row['club_name'] as String,
  state: switch (row['state']) {
    'active' => CardState.active,
    'pending_payment' => CardState.pendingPayment,
    'no_season' => CardState.noSeason,
    _ => CardState.notRenewed,
  },
  clubLogoUrl: logoUrl,
  primaryColor: row['club_primary_color'] as String?,
  secondaryColor: row['club_secondary_color'] as String?,
  firstName: row['first_name'] as String?,
  lastName: row['last_name'] as String?,
  photoUrl: photoUrl,
  memberNumber: row['member_number'] as int?,
  seasonName: row['season_name'] as String?,
  cardToken: row['card_token'] as String?,
  seasonMembershipId: row['season_membership_id'] as String?,
  feeCents: row['fee_cents'] as int?,
);
