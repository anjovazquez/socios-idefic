import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/domain/season/season.dart';
import 'package:socios_idefic/domain/sponsor/sponsor.dart';
import 'package:socios_idefic/infrastructure/sponsor/supabase_sponsor_repository.dart';
import 'package:socios_idefic/presentation/app/socios_app.dart';
import 'package:socios_idefic/presentation/club/image_picking.dart';

import '../support/fakes.dart';

// BDD: tasks/VS-027.md — Patrocinadores.
void main() {
  Season season(String id, String name, SeasonStatus status) => Season(
    id: id,
    clubId: ideficAsAdmin.id,
    name: name,
    startsOn: DateTime(int.parse(name.substring(0, 4)), 9),
    endsOn: DateTime(int.parse(name.substring(5)), 8, 31),
    status: status,
  );

  late FakeSponsorRepository sponsors;
  late FakeSeasonRepository seasons;

  setUp(() {
    seasons = FakeSeasonRepository({
      ideficAsAdmin.id: [
        season('s26', '2026/2027', SeasonStatus.active),
        season('s25', '2025/2026', SeasonStatus.closed),
      ],
    });
    sponsors = FakeSponsorRepository(
      seasonNames: {'s26': '2026/2027', 's25': '2025/2026', 's27': '2027/2028'},
    );
  });

  Future<void> openSponsors(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      SociosApp(
        useCases: buildUseCases(
          auth: FakeAuthRepository(passwords: {'admin@example.com': 'pw'}),
          clubs: FakeClubRepository({
            'admin@example.com': [ideficAsAdmin],
          }),
          seasons: seasons,
          sponsors: sponsors,
        ),
        pickImage: () async => PickedImage(
          bytes: Uint8List.fromList(_png),
          contentType: 'image/png',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('login-email')),
      'admin@example.com',
    );
    await tester.enterText(find.byKey(const Key('login-password')), 'pw');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-sponsors')));
    await tester.pumpAndSettle();
  }

  testWidgets('new «Restaurante X» with logo and web, sponsor of 2026/2027', (
    tester,
  ) async {
    await openSponsors(tester);
    await tester.tap(find.byKey(const Key('new-sponsor')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('sponsor-name')),
      'Restaurante X',
    );
    await tester.enterText(
      find.byKey(const Key('sponsor-website')),
      'https://restaurantex.es',
    );
    await tester.tap(find.byKey(const Key('sponsor-logo')));
    await tester.pumpAndSettle();
    // The active season comes selected.
    final chip = tester.widget<FilterChip>(
      find.byKey(const Key('sponsor-season-2026/2027')),
    );
    expect(chip.selected, isTrue);
    await tester.tap(find.byKey(const Key('sponsor-save')));
    await tester.pumpAndSettle();

    expect(
      find.text('Patrocinador Restaurante X dado de alta'),
      findsOneWidget,
    );
    expect(find.text('Temporadas: 2026/2027'), findsOneWidget);
    final saved = sponsors.sponsors[ideficAsAdmin.id]!.single;
    expect(saved.logoPath, 'club-idefic/sponsor-1.png');
    expect(saved.websiteUrl, 'https://restaurantex.es');
  });

  testWidgets('a website without https is rejected inline', (tester) async {
    await openSponsors(tester);
    await tester.tap(find.byKey(const Key('new-sponsor')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('sponsor-name')), 'Bar Y');
    await tester.enterText(
      find.byKey(const Key('sponsor-website')),
      'http://bary.es',
    );
    await tester.tap(find.byKey(const Key('sponsor-save')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'La web debe empezar por https://, por ejemplo https://restaurante.es',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a sponsor does not pass alone to the new season: renew it', (
    tester,
  ) async {
    seasons.seasons[ideficAsAdmin.id] = [
      season('s27', '2027/2028', SeasonStatus.active),
      season('s26', '2026/2027', SeasonStatus.closed),
    ];
    await sponsors.saveSponsor(clubId: ideficAsAdmin.id, name: 'Restaurante X');
    await sponsors.setSeasons('sponsor-1', ['s26']);
    await openSponsors(tester);

    expect(find.text('Temporadas: 2026/2027'), findsOneWidget);
    expect(find.byKey(const Key('sponsors-renewal')), findsOneWidget);
    await tester.tap(find.byKey(const Key('sponsors-renew')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('renew-Restaurante X')), findsOneWidget);
    await tester.tap(find.byKey(const Key('sponsors-renew-save')));
    await tester.pumpAndSettle();

    expect(find.text('1 patrocinador renovado para 2027/2028'), findsOneWidget);
    expect(find.text('Temporadas: 2026/2027, 2027/2028'), findsOneWidget);
    expect(find.byKey(const Key('sponsors-renewal')), findsNothing);
  });

  testWidgets('deactivating hides it from members but keeps its season', (
    tester,
  ) async {
    await sponsors.saveSponsor(clubId: ideficAsAdmin.id, name: 'Restaurante X');
    await sponsors.setSeasons('sponsor-1', ['s26']);
    await openSponsors(tester);

    await tester.tap(find.byKey(const Key('sponsor-active-Restaurante X')));
    await tester.pumpAndSettle();

    expect(
      find.text('Restaurante X ya no se muestra a los socios'),
      findsOneWidget,
    );
    expect(
      find.text('Desactivado: no se muestra a los socios'),
      findsOneWidget,
    );
    final s = sponsors.sponsors[ideficAsAdmin.id]!.single;
    expect(
      [s.isActive, s.seasonIds],
      [
        false,
        ['s26'],
      ],
    );
  });

  test('website rule and mapping', () {
    expect(isValidSponsorWebsite(''), isTrue);
    expect(isValidSponsorWebsite('https://bar.es/carta'), isTrue);
    expect(isValidSponsorWebsite('http://bar.es'), isFalse);
    expect(isValidSponsorWebsite('https://bar'), isFalse);
    final sponsor = sponsorFromRow({
      'id': 's',
      'name': 'Bar',
      'logo_path': 'c/sponsor.png',
      'website_url': null,
      'is_active': true,
      'season_ids': ['x'],
      'season_names': ['2026/2027'],
    }, logoUrl: (path) => 'https://cdn/$path');
    expect(sponsor.logoUrl, 'https://cdn/c/sponsor.png');
    expect(sponsor.seasonNames, ['2026/2027']);
    expect(mapSponsorError('23505', 'x'), isA<SponsorAlreadyExistsFailure>());
  });
}

// 1×1 transparent PNG.
const _png = [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];
