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

  test('sub-routes of the current area are allowed', () {
    expect(redirectFor(SessionStatus.inClub, '/club/settings'), isNull);
    expect(redirectFor(SessionStatus.inClub, '/club'), isNull);
    expect(redirectFor(SessionStatus.signedOut, '/club/settings'), '/login');
    expect(redirectFor(SessionStatus.choosingClub, '/club/settings'), '/clubs');
    expect(redirectFor(SessionStatus.loading, '/club'), '/');
  });

  test('the first access cannot be skipped', () {
    expect(routeFor(SessionStatus.onboarding), '/primer-acceso');
    expect(redirectFor(SessionStatus.onboarding, '/club'), '/primer-acceso');
    expect(redirectFor(SessionStatus.onboarding, '/clubs'), '/primer-acceso');
  });

  test('invitation links open without a session', () {
    expect(redirectFor(SessionStatus.signedOut, '/activar'), isNull);
    expect(redirectFor(SessionStatus.loading, '/activar'), isNull);
    expect(redirectFor(SessionStatus.onboarding, '/activar'), '/primer-acceso');
  });

  test('a link opened while the session loads is restored afterwards', () {
    final keeper = DeepLinkKeeper();
    final link = Uri.parse('/club/subscription?pago=ok');

    expect(keeper.redirect(SessionStatus.loading, link), '/');
    expect(keeper.redirect(SessionStatus.loading, Uri.parse('/')), isNull);
    expect(
      keeper.redirect(SessionStatus.inClub, Uri.parse('/')),
      '/club/subscription?pago=ok',
    );
    expect(keeper.redirect(SessionStatus.inClub, link), isNull);
    // Only once.
    expect(keeper.redirect(SessionStatus.inClub, Uri.parse('/')), '/club');
  });

  test('a kept link outside the session area is dropped', () {
    final keeper = DeepLinkKeeper();
    keeper.redirect(SessionStatus.loading, Uri.parse('/club/payments'));
    expect(keeper.redirect(SessionStatus.signedOut, Uri.parse('/')), '/login');
    expect(keeper.redirect(SessionStatus.inClub, Uri.parse('/')), '/club');
  });
}
