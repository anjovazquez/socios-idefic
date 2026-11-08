import '../../domain/club/my_club.dart';

/// Maps a row of the `get_my_clubs` RPC.
MyClub myClubFromRow(Map<String, dynamic> row) => MyClub(
  id: row['club_id'] as String,
  name: row['name'] as String,
  code: row['code'] as String,
  role: switch (row['role']) {
    'club_admin' => ClubRole.clubAdmin,
    _ => ClubRole.member,
  },
  logoPath: row['logo_path'] as String?,
  primaryColor: row['primary_color'] as String?,
  secondaryColor: row['secondary_color'] as String?,
  memberNumber: row['member_number'] as int?,
);
