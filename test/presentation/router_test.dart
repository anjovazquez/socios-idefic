import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/presentation/app/router.dart';
import 'package:socios_idefic/presentation/session/session_view_model.dart';

void main() {
  test('each session status owns one route', () {
    expect(routeFor(SessionStatus.signedOut), AppRoutes.login);
    expect(routeFor(SessionStatus.choosingClub), AppRoutes.clubs);
    expect(routeFor(SessionStatus.inClub), AppRoutes.club);
    expect(routeFor(SessionStatus.noClubs), AppRoutes.noClubs);
    expect(routeFor(SessionStatus.loading), AppRoutes.loading);
    expect(routeFor(SessionStatus.error), AppRoutes.error);
  });
}
