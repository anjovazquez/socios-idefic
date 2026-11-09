import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/dashboard/club_dashboard.dart';

class SupabaseDashboardRepository implements DashboardRepository {
  const SupabaseDashboardRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<ClubDashboard> getClubDashboard(String clubId) async {
    final rows = await _client.rpc<List<dynamic>>(
      'get_club_dashboard',
      params: {'p_club_id': clubId},
    );
    return rows.isEmpty
        ? const ClubDashboard()
        : clubDashboardFromRow(rows.first as Map<String, dynamic>);
  }
}

ClubDashboard clubDashboardFromRow(Map<String, dynamic> row) => ClubDashboard(
  seasonName: row['season_name'] as String?,
  activeMembers: row['active_members'] as int? ?? 0,
  pendingMembers: row['pending_members'] as int? ?? 0,
  notRenewedMembers: row['not_renewed_members'] as int? ?? 0,
  invitedMembers: row['invited_members'] as int? ?? 0,
  autoRenewMembers: row['auto_renew_members'] as int? ?? 0,
  paidCents: row['paid_cents'] as int? ?? 0,
  pendingCents: row['pending_cents'] as int? ?? 0,
  validPerks: row['valid_perks'] as int? ?? 0,
  seasonSponsors: row['season_sponsors'] as int? ?? 0,
  latestPosts: [
    for (final post in (row['latest_posts'] as List? ?? const []))
      DashboardPost(
        id: (post as Map)['id'] as String,
        title: post['title'] as String,
        publishedAt: DateTime.parse(post['published_at'] as String),
      ),
  ],
);
