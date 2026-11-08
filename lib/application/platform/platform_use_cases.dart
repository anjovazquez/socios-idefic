import '../../domain/platform/audit_entry.dart';
import '../../domain/platform/club_data.dart';
import '../../domain/platform/platform_club.dart';
import '../../domain/platform/platform_repository.dart';

class IsPlatformAdmin {
  const IsPlatformAdmin(this._repository);

  final PlatformRepository _repository;

  Future<bool> call() => _repository.isPlatformAdmin();
}

class GetPlatformClubs {
  const GetPlatformClubs(this._repository);

  final PlatformRepository _repository;

  Future<List<PlatformClub>> call() => _repository.getClubs();
}

class CreateClub {
  const CreateClub(this._repository);

  final PlatformRepository _repository;

  Future<String> call({
    required String name,
    required String code,
    required String adminEmail,
    String? adminName,
  }) {
    final data = ClubData(name: name, code: code);
    final email = normalizeAdminEmail(adminEmail);
    final trimmedName = adminName?.trim();
    return _repository.createClub(
      data: data,
      adminEmail: email,
      adminName: trimmedName == null || trimmedName.isEmpty
          ? null
          : trimmedName,
    );
  }
}

class UpdateClub {
  const UpdateClub(this._repository);

  final PlatformRepository _repository;

  Future<void> call({
    required String clubId,
    required String name,
    required String code,
  }) => _repository.updateClub(
    clubId: clubId,
    data: ClubData(name: name, code: code),
  );
}

class SetClubActive {
  const SetClubActive(this._repository);

  final PlatformRepository _repository;

  Future<void> call({required String clubId, required bool active}) =>
      _repository.setClubActive(clubId: clubId, active: active);
}

class GetAuditLog {
  const GetAuditLog(this._repository);

  static const pageSize = 50;

  final PlatformRepository _repository;

  Future<List<AuditEntry>> call({String? clubId, int? beforeId}) => _repository
      .getAuditLog(clubId: clubId, beforeId: beforeId, limit: pageSize);
}
