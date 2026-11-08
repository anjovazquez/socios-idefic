import 'audit_entry.dart';
import 'club_data.dart';
import 'platform_club.dart';

abstract interface class PlatformRepository {
  Future<bool> isPlatformAdmin();

  Future<List<PlatformClub>> getClubs();

  /// Creates the club and assigns (or invites) its administrator.
  Future<String> createClub({
    required ClubData data,
    required String adminEmail,
    String? adminName,
  });

  Future<void> updateClub({required String clubId, required ClubData data});

  Future<void> setClubActive({required String clubId, required bool active});

  /// Newest first; [beforeId] continues a previous page.
  Future<List<AuditEntry>> getAuditLog({
    String? clubId,
    int? beforeId,
    int limit = 50,
  });
}
