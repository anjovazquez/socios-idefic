import '../../domain/club/my_club.dart';

/// Maps a row of the `get_my_clubs` RPC. [publicUrl] resolves storage paths.
MyClub myClubFromRow(
  Map<String, dynamic> row, {
  String Function(String path)? publicUrl,
}) {
  String? url(Object? path) =>
      path is String && publicUrl != null ? publicUrl(path) : null;
  return MyClub(
    id: row['club_id'] as String,
    name: row['name'] as String,
    code: row['code'] as String,
    role: switch (row['role']) {
      'club_admin' => ClubRole.clubAdmin,
      'platform_admin' => ClubRole.platformAdmin,
      _ => ClubRole.member,
    },
    logoUrl: url(row['logo_path']),
    imageUrl: url(row['image_path']),
    primaryColor: row['primary_color'] as String?,
    secondaryColor: row['secondary_color'] as String?,
    memberNumber: row['member_number'] as int?,
    activeSeasonName: row['active_season_name'] as String?,
  );
}
