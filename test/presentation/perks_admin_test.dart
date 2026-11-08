import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/domain/perk/perk.dart';
import 'package:socios_idefic/infrastructure/perk/supabase_perk_repository.dart';
import 'package:socios_idefic/presentation/app/socios_app.dart';

import '../support/fakes.dart';

// BDD: tasks/VS-029.md — Gestionar ventajas.
void main() {
  late FakeSponsorRepository sponsors;
  late FakePerkRepository perks;

  setUp(() async {
    sponsors = FakeSponsorRepository();
    await sponsors.saveSponsor(clubId: ideficAsAdmin.id, name: 'Restaurante X');
    perks = FakePerkRepository();
  });

  Future<void> openPerks(WidgetTester tester) async {
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
          sponsors: sponsors,
          perks: perks,
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
    await tester.tap(find.byKey(const Key('open-perks-admin')));
    await tester.pumpAndSettle();
  }

  testWidgets('publish «10 % de descuento en Restaurante X» linked to it', (
    tester,
  ) async {
    await openPerks(tester);
    await tester.tap(find.byKey(const Key('new-perk')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('perk-title')),
      '10 % de descuento en Restaurante X',
    );
    await tester.enterText(
      find.byKey(const Key('perk-body')),
      'Presentando tu carnet de socio obtendrás un 10 % de descuento.',
    );
    await tester.tap(find.byKey(const Key('perk-sponsor')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restaurante X').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('perk-publish')));
    await tester.pumpAndSettle();

    expect(find.text('Ventaja publicada'), findsOneWidget);
    expect(find.text('Patrocinador: Restaurante X'), findsOneWidget);
    expect(find.text('Vigente'), findsOneWidget);
    expect(find.text('Sin fecha de fin'), findsOneWidget);
    final perk = perks.perks[ideficAsAdmin.id]!.single;
    expect([perk.status, perk.sponsorId], [PerkStatus.published, 'sponsor-1']);
  });

  testWidgets('a draft and archiving', (tester) async {
    await perks.savePerk(
      clubId: ideficAsAdmin.id,
      title: 'Entrada gratis',
      body: 'Con el carnet',
      publish: true,
    );
    await openPerks(tester);
    await tester.tap(find.byKey(const Key('perk-menu-Entrada gratis')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archivar (retirar)'));
    await tester.pumpAndSettle();
    expect(find.text('Archivada'), findsOneWidget);

    await tester.tap(find.byKey(const Key('new-perk')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('perk-title')), 'Cena');
    await tester.enterText(find.byKey(const Key('perk-body')), 'Pronto');
    await tester.tap(find.byKey(const Key('perk-save-draft')));
    await tester.pumpAndSettle();
    expect(find.text('Borrador'), findsOneWidget);
  });

  test('a sponsor of another club is rejected (server error mapping)', () {
    expect(
      mapPerkError('22023', 'invalid sponsor'),
      isA<InvalidPerkFailure>().having(
        (f) => f.field,
        'field',
        PerkField.sponsor,
      ),
    );
  });

  test('visibility follows the validity dates', () {
    final today = DateTime(2026, 11, 9);
    Perk perk({DateTime? from, DateTime? until}) => Perk(
      id: 'p',
      title: 't',
      body: 'b',
      status: PerkStatus.published,
      validFrom: from,
      validUntil: until,
    );
    expect(perk().visibilityOn(today), PerkVisibility.visible);
    expect(
      perk(from: DateTime(2026, 11, 10)).visibilityOn(today),
      PerkVisibility.upcoming,
    );
    expect(
      perk(until: DateTime(2026, 11, 8)).visibilityOn(today),
      PerkVisibility.expired,
    );
    expect(
      perk(until: DateTime(2026, 11, 9)).visibilityOn(today),
      PerkVisibility.visible,
    );
  });

  test('maps rows', () {
    final perk = perkFromRow({
      'id': 'p',
      'sponsor_id': 's',
      'sponsor_name': 'Restaurante X',
      'title': 't',
      'body': 'b',
      'image_path': null,
      'valid_from': '2026-12-01',
      'valid_until': null,
      'status': 'published',
    });
    expect(perk.validFrom, DateTime(2026, 12, 1));
    expect(perk.sponsorName, 'Restaurante X');
  });
}
