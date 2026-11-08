import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/presentation/app/socios_app.dart';
import 'package:socios_idefic/presentation/sponsor/sponsor_widgets.dart';

import '../support/fakes.dart';

// BDD: tasks/VS-028.md — Patrocinadores del club.
void main() {
  late FakeSponsorRepository sponsors;
  late List<Uri> opened;

  setUp(() async {
    opened = [];
    sponsors = FakeSponsorRepository()..activeSeasonId = 's26';
    await sponsors.saveSponsor(
      clubId: idefic.id,
      name: 'Restaurante X',
      logoPath: 'club-idefic/sponsor-x.png',
      websiteUrl: 'https://restaurantex.es',
    );
    await sponsors.setSeasons('sponsor-1', ['s26']);
    await sponsors.saveSponsor(clubId: idefic.id, name: 'Antiguo');
    await sponsors.setSeasons('sponsor-2', ['s25']);
    await sponsors.saveSponsor(clubId: idefic.id, name: 'Desactivado');
    await sponsors.setSeasons('sponsor-3', ['s26']);
    await sponsors.setActive('sponsor-3', false);
  });

  Future<void> openHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      SociosApp(
        useCases: buildUseCases(
          auth: FakeAuthRepository(passwords: {'ana@example.com': 'pw'}),
          clubs: FakeClubRepository({
            'ana@example.com': [idefic],
          }),
          sponsors: sponsors,
        ),
        openWebsite: (url) async => opened.add(url),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('login-email')),
      'ana@example.com',
    );
    await tester.enterText(find.byKey(const Key('login-password')), 'pw');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
  }

  testWidgets('Ana sees the active sponsors of the season with logo, name '
      'and link', (tester) async {
    await openHome(tester);

    expect(find.byKey(const Key('home-sponsors')), findsOneWidget);
    expect(find.text('Restaurante X'), findsOneWidget);
    expect(find.text('restaurantex.es'), findsOneWidget);
    expect(find.byType(SponsorLogo), findsOneWidget);
    expect(find.text('Antiguo'), findsNothing);
    expect(find.text('Desactivado'), findsNothing);
  });

  testWidgets('tapping a sponsor opens its website', (tester) async {
    await openHome(tester);
    await tester.tap(find.byKey(const Key('home-sponsor-Restaurante X')));
    await tester.pumpAndSettle();
    expect(opened, [Uri.parse('https://restaurantex.es')]);
  });

  testWidgets('without sponsors there is no section', (tester) async {
    sponsors.activeSeasonId = 'other';
    await openHome(tester);
    expect(find.byKey(const Key('home-sponsors')), findsNothing);
  });
}
