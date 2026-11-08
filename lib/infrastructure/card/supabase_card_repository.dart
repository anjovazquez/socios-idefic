import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/card/card_repository.dart';
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
);
