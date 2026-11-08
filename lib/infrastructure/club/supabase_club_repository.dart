import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/club/club_repository.dart';
import '../../domain/club/my_club.dart';
import 'my_club_mapper.dart';

class SupabaseClubRepository implements ClubRepository {
  const SupabaseClubRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<MyClub>> getMyClubs() async {
    final rows = await _client.rpc<List<dynamic>>('get_my_clubs');
    return rows.cast<Map<String, dynamic>>().map(myClubFromRow).toList();
  }
}
