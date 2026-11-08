import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/season/season.dart';
import '../../domain/season/season_membership.dart';
import '../../domain/season/season_repository.dart';

class SupabaseSeasonRepository implements SeasonRepository {
  const SupabaseSeasonRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Season>> getSeasons(String clubId) => _guard(() async {
    final rows = await _client
        .from('seasons')
        .select(
          'id, club_id, name, starts_on, ends_on, default_fee_cents, status',
        )
        .eq('club_id', clubId)
        .order('name', ascending: false);
    return rows.map(seasonFromRow).toList();
  });

  @override
  Future<void> createSeason({
    required String clubId,
    required String name,
    DateTime? startsOn,
    DateTime? endsOn,
  }) => _guard(
    () => _client.rpc<void>(
      'create_season',
      params: {
        'p_club_id': clubId,
        'p_name': name,
        'p_starts_on': _date(startsOn),
        'p_ends_on': _date(endsOn),
      },
    ),
  );

  @override
  Future<void> activateSeason({
    required String seasonId,
    required int defaultFeeCents,
  }) => _guard(
    () => _client.rpc<void>(
      'activate_season',
      params: {'p_season_id': seasonId, 'p_default_fee_cents': defaultFeeCents},
    ),
  );

  @override
  Future<List<MemberSeason>> getMemberSeasons(String membershipId) =>
      _guard(() async {
        final rows = await _client.rpc<List<dynamic>>(
          'get_member_seasons',
          params: {'p_membership_id': membershipId},
        );
        return rows
            .cast<Map<String, dynamic>>()
            .map(memberSeasonFromRow)
            .toList();
      });

  @override
  Future<void> setMemberFee({
    required String seasonMembershipId,
    required int feeCents,
  }) => _guard(
    () => _client.rpc<void>(
      'set_member_fee',
      params: {
        'p_season_membership_id': seasonMembershipId,
        'p_fee_cents': feeCents,
      },
    ),
  );

  @override
  Future<void> setSeasonMembershipStatus({
    required String seasonMembershipId,
    required SeasonMembershipStatus status,
  }) => _guard(
    () => _client.rpc<void>(
      'set_season_membership_status',
      params: {
        'p_season_membership_id': seasonMembershipId,
        'p_status': switch (status) {
          SeasonMembershipStatus.active => 'active',
          _ => 'pending_payment',
        },
      },
    ),
  );

  static String? _date(DateTime? date) =>
      date?.toIso8601String().substring(0, 10);

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (error) {
      throw mapSeasonError(error.code, error.message, error.hint);
    } on SeasonFailure {
      rethrow;
    } catch (error) {
      throw SeasonUnavailableFailure(error);
    }
  }
}

Season seasonFromRow(Map<String, dynamic> row) => Season(
  id: row['id'] as String,
  clubId: row['club_id'] as String,
  name: row['name'] as String,
  startsOn: DateTime.parse(row['starts_on'] as String),
  endsOn: DateTime.parse(row['ends_on'] as String),
  status: switch (row['status']) {
    'active' => SeasonStatus.active,
    'closed' => SeasonStatus.closed,
    _ => SeasonStatus.draft,
  },
  defaultFeeCents: row['default_fee_cents'] as int?,
);

MemberSeason memberSeasonFromRow(Map<String, dynamic> row) => MemberSeason(
  seasonMembershipId: row['season_membership_id'] as String?,
  seasonName: row['season_name'] as String,
  seasonStatus: switch (row['season_status']) {
    'active' => SeasonStatus.active,
    'closed' => SeasonStatus.closed,
    _ => SeasonStatus.draft,
  },
  status: seasonMembershipStatusFromName(row['status'] as String?),
  feeCents: row['fee_cents'] as int?,
);

SeasonFailure mapSeasonError(String? code, String message, String? hint) =>
    switch (code) {
      '42501' => const SeasonPermissionFailure(),
      '23505' => const SeasonAlreadyExistsFailure(),
      '22023' when message.contains('fee') || message.contains('invalid fee') =>
        const InvalidSeasonDataFailure(SeasonField.fee),
      '22023' when message.contains('dates') => const InvalidSeasonDataFailure(
        SeasonField.dates,
      ),
      '22023' => const InvalidSeasonDataFailure(SeasonField.name),
      'P0001' when hint == 'season_closed' => const SeasonClosedFailure(),
      _ => SeasonUnavailableFailure('$code $message'),
    };
