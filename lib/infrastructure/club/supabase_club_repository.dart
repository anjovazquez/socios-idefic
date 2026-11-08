import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/club/club_repository.dart';
import '../../domain/club/my_club.dart';
import 'my_club_mapper.dart';
import 'supabase_club_branding_repository.dart';

class SupabaseClubRepository implements ClubRepository {
  const SupabaseClubRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<MyClub>> getMyClubs() async {
    final rows = await _client.rpc<List<dynamic>>('get_my_clubs');
    final storage = _client.storage.from(SupabaseClubBrandingRepository.bucket);
    return rows
        .cast<Map<String, dynamic>>()
        .map((row) => myClubFromRow(row, publicUrl: storage.getPublicUrl))
        .toList();
  }
}
