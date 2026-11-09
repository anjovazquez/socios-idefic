import '../../domain/dashboard/club_dashboard.dart';

class GetClubDashboard {
  const GetClubDashboard(this._repository);

  final DashboardRepository _repository;

  Future<ClubDashboard> call(String clubId) =>
      _repository.getClubDashboard(clubId);
}
