import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/platform/audit_entry.dart';
import '../../domain/platform/club_data.dart';
import '../../domain/platform/platform_club.dart';
import '../../domain/platform/platform_failures.dart';
import '../../domain/platform/platform_repository.dart';

class SupabasePlatformRepository implements PlatformRepository {
  const SupabasePlatformRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<bool> isPlatformAdmin() =>
      _guard(() async => await _client.rpc<bool>('is_platform_admin'));

  @override
  Future<List<PlatformClub>> getClubs() => _guard(() async {
    final rows = await _client.rpc<List<dynamic>>('get_platform_clubs');
    return rows.cast<Map<String, dynamic>>().map(platformClubFromRow).toList();
  });

  @override
  Future<String> createClub({
    required ClubData data,
    required String adminEmail,
    String? adminName,
  }) => _guard(
    () async => await _client.rpc<String>(
      'create_club',
      params: {
        'p_name': data.name,
        'p_code': data.code,
        'p_admin_email': adminEmail,
        'p_admin_name': adminName,
      },
    ),
  );

  @override
  Future<void> updateClub({required String clubId, required ClubData data}) =>
      _guard(
        () => _client.rpc<void>(
          'update_club',
          params: {
            'p_club_id': clubId,
            'p_name': data.name,
            'p_code': data.code,
          },
        ),
      );

  @override
  Future<void> setClubActive({required String clubId, required bool active}) =>
      _guard(
        () => _client.rpc<void>(
          'set_club_active',
          params: {'p_club_id': clubId, 'p_active': active},
        ),
      );

  @override
  Future<List<AuditEntry>> getAuditLog({
    String? clubId,
    int? beforeId,
    int limit = 50,
  }) => _guard(() async {
    final rows = await _client.rpc<List<dynamic>>(
      'get_audit_log',
      params: {'p_club_id': clubId, 'p_before_id': beforeId, 'p_limit': limit},
    );
    return rows.cast<Map<String, dynamic>>().map(auditEntryFromRow).toList();
  });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (error) {
      throw mapPlatformError(error);
    } on PlatformFailure {
      rethrow;
    } catch (error) {
      throw PlatformUnavailableFailure(error);
    }
  }
}

PlatformClub platformClubFromRow(Map<String, dynamic> row) => PlatformClub(
  id: row['club_id'] as String,
  name: row['name'] as String,
  code: row['code'] as String,
  isActive: row['is_active'] as bool,
  memberCount: (row['member_count'] as int?) ?? 0,
  adminEmail: row['admin_email'] as String?,
  pendingAdminEmail: row['pending_admin_email'] as String?,
);

AuditEntry auditEntryFromRow(Map<String, dynamic> row) => AuditEntry(
  id: (row['id'] as num).toInt(),
  action: row['action'] as String,
  asPlatformAdmin: row['as_platform_admin'] as bool? ?? false,
  createdAt: DateTime.parse(row['created_at'] as String),
  clubId: row['club_id'] as String?,
  clubName: row['club_name'] as String?,
  actorEmail: row['actor_email'] as String?,
  payload: (row['payload'] as Map<String, dynamic>?) ?? const {},
);

PlatformFailure mapPlatformError(PostgrestException error) {
  final text = '${error.message} ${error.details ?? ''} ${error.hint ?? ''}';
  return switch (error.code) {
    '23505' when text.contains('admin') => const ClubAlreadyHasAdminFailure(),
    '23505' => const DuplicateClubCodeFailure(),
    'P0001' when text.contains('admin') => const ClubAlreadyHasAdminFailure(),
    '42501' => const NotPlatformAdminFailure(),
    '22023' when text.contains('email') => const InvalidClubDataFailure(
      ClubField.adminEmail,
    ),
    '22023' when text.contains('code') => const InvalidClubDataFailure(
      ClubField.code,
    ),
    '22023' => const InvalidClubDataFailure(ClubField.name),
    _ => PlatformUnavailableFailure(error),
  };
}
