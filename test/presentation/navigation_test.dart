import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/presentation/app/socios_app.dart';
import 'package:socios_idefic/presentation/club/club_shell.dart';

import '../support/fakes.dart';

// BDD: tasks/VS-032.md — Navegación del socio.
void main() {
  Future<void> signIn(
    WidgetTester tester,
    Size size, {
    String email = 'ana@example.com',
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      SociosApp(
        useCases: buildUseCases(
          auth: FakeAuthRepository(
            passwords: {'ana@example.com': 'pw', 'admin@example.com': 'pw'},
          ),
          clubs: FakeClubRepository({
            'ana@example.com': [idefic],
            'admin@example.com': [ideficAsAdmin],
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('login-email')), email);
    await tester.enterText(find.byKey(const Key('login-password')), 'pw');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
  }

  testWidgets('Ana sees Inicio, Mi carnet, Mis ventajas, Mi suscripción and '
      'Mis datos with the IDEFIC colors', (tester) async {
    await signIn(tester, const Size(420, 900));

    final bar = find.byKey(const Key('club-navigation'));
    expect(bar, findsOneWidget);
    for (final label in [
      'Inicio',
      'Mi carnet',
      'Mis ventajas',
      'Mi suscripción',
      'Mis datos',
    ]) {
      expect(
        find.descendant(of: bar, matching: find.text(label)),
        findsOneWidget,
      );
    }
    final scheme = Theme.of(tester.element(bar)).colorScheme;
    expect(scheme.primary, const Color(0xFF0B3D91));

    for (final (key, title) in [
      ('open-card', 'Mi carnet'),
      ('open-my-perks', 'Mis ventajas'),
      ('open-subscription', 'Mi suscripción'),
      ('open-my-data', 'Mis datos'),
    ]) {
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, title), findsOneWidget, reason: title);
      expect(find.byType(BackButton), findsNothing, reason: title);
      expect(
        tester.widget<NavigationBar>(bar).selectedIndex,
        ClubShell.sections.indexWhere((s) => s.label == title),
      );
    }
    await tester.tap(find.byKey(const Key('open-home')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-show-card')), findsOneWidget);
  });

  testWidgets('on wide screens (admin web) the sections are a side rail', (
    tester,
  ) async {
    await signIn(tester, const Size(1280, 900), email: 'admin@example.com');
    expect(find.byKey(const Key('club-rail')), findsOneWidget);
    expect(find.byKey(const Key('club-navigation')), findsNothing);
  });

  testWidgets('the admin manages the club from a single «Gestión» menu', (
    tester,
  ) async {
    await signIn(tester, const Size(420, 900), email: 'admin@example.com');
    await tester.tap(find.byKey(const Key('open-admin-menu')));
    await tester.pumpAndSettle();
    for (final label in [
      'Socios',
      'Pagos',
      'Temporadas',
      'Noticias',
      'Patrocinadores',
      'Ventajas',
      'Configuración del club',
    ]) {
      expect(find.text(label), findsWidgets, reason: label);
    }
  });

  test('management pages and details belong to Inicio; sections to theirs', () {
    expect(ClubShell.indexOf('/club'), 0);
    expect(ClubShell.indexOf('/club/members'), 0);
    expect(ClubShell.indexOf('/club/card'), 1);
    expect(ClubShell.indexOf('/club/benefits/detail'), 2);
    expect(ClubShell.indexOf('/club/subscription'), 3);
    expect(ClubShell.indexOf('/club/me'), 4);
  });
}
