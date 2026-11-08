import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/domain/perk/perk.dart';
import 'package:socios_idefic/infrastructure/perk/supabase_perk_repository.dart';
import 'package:socios_idefic/presentation/app/socios_app.dart';

import '../support/fakes.dart';

// BDD: tasks/VS-030.md — Mis ventajas.
void main() {
  late FakePerkRepository perks;
  late FakeSponsorRepository sponsors;
  late List<Uri> opened;

  setUp(() async {
    opened = [];
    sponsors = FakeSponsorRepository();
    await sponsors.saveSponsor(
      clubId: idefic.id,
      name: 'Restaurante X',
      websiteUrl: 'https://restaurantex.es',
    );
    perks = FakePerkRepository(today: DateTime(2026, 11, 9))
      ..sponsors = sponsors;
    await perks.savePerk(
      clubId: idefic.id,
      sponsorId: 'sponsor-1',
      title: '10 % en Restaurante X',
      body: 'Presentando tu carnet obtendrás un 10 % de descuento.',
      publish: true,
    );
    await perks.savePerk(
      clubId: idefic.id,
      title: 'Torneo de verano',
      body: 'Entrada gratis.',
      validUntil: DateTime(2026, 8, 31),
      publish: true,
    );
  });

  Future<void> openPerks(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1800);
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
          perks: perks,
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
    await tester.tap(find.byKey(const Key('open-my-perks')));
    await tester.pumpAndSettle();
  }

  testWidgets('Ana only sees the valid perk', (tester) async {
    await openPerks(tester);
    expect(find.text('10 % en Restaurante X'), findsOneWidget);
    expect(find.text('Restaurante X'), findsOneWidget);
    expect(find.text('Torneo de verano'), findsNothing);
  });

  testWidgets('a perk opens with the sponsor and «Mostrar mi carnet»', (
    tester,
  ) async {
    await openPerks(tester);
    await tester.tap(find.text('10 % en Restaurante X'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('perk-detail-title')), findsOneWidget);
    expect(
      find.text('Presenta tu carnet de socio para disfrutar de esta ventaja.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('perk-detail-sponsor')));
    await tester.pumpAndSettle();
    expect(opened, [Uri.parse('https://restaurantex.es')]);

    await tester.tap(find.byKey(const Key('perk-show-card')));
    await tester.pumpAndSettle();
    expect(find.text('Mi carnet'), findsWidgets);
  });

  testWidgets('without valid perks it says so', (tester) async {
    perks.today = DateTime(2030);
    await perks.setStatus('perk-1', PerkStatus.archived);
    await openPerks(tester);
    expect(find.byKey(const Key('my-perks-empty')), findsOneWidget);
  });

  test('maps member perks with the sponsor logo', () {
    final perk = myPerkFromRow({
      'id': 'p',
      'title': 't',
      'body': 'b',
      'image_path': null,
      'valid_from': null,
      'valid_until': '2026-12-31',
      'sponsor_name': 'Restaurante X',
      'sponsor_logo_path': 'c/sponsor.png',
      'sponsor_website_url': 'https://restaurantex.es',
    }, logoUrl: (path) => 'https://cdn/$path');
    expect(perk.sponsorLogoUrl, 'https://cdn/c/sponsor.png');
    expect(perk.validUntil, DateTime(2026, 12, 31));
  });
}
