import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/domain/card/membership_card.dart';
import 'package:socios_idefic/infrastructure/card/supabase_card_repository.dart';
import 'package:socios_idefic/presentation/app/socios_app.dart';

import '../support/fakes.dart';

// BDD: tasks/VS-015.md — Mi carnet.
void main() {
  MembershipCard card(CardState state, {String season = '2026/2027'}) =>
      MembershipCard(
        clubName: 'IDEFIC',
        state: state,
        primaryColor: '#0B3D91',
        firstName: 'Ana',
        lastName: 'Pérez',
        memberNumber: 2,
        seasonName: state == CardState.noSeason ? null : season,
        cardToken: state == CardState.active ? 'token-ana-123' : null,
      );

  Future<void> openCard(WidgetTester tester, MembershipCard value) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = FakeAuthRepository(passwords: {'ana@example.com': 'pw'});
    await tester.pumpWidget(
      SociosApp(
        useCases: buildUseCases(
          auth: auth,
          clubs: FakeClubRepository({
            'ana@example.com': [idefic],
          }),
          cards: FakeCardRepository({'ana@example.com': value}),
        ),
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
    await tester.tap(find.byKey(const Key('open-card')));
    await tester.pumpAndSettle();
  }

  testWidgets('an active member sees her card and can enlarge it', (
    tester,
  ) async {
    await openCard(tester, card(CardState.active));

    expect(find.byKey(const Key('membership-card')), findsOneWidget);
    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.text('Socio nº 2'), findsOneWidget);
    expect(find.text('Temporada 2026/2027'), findsOneWidget);
    expect(find.text('IDEFIC'), findsWidgets);
    expect(find.byKey(const Key('card-qr')), findsOneWidget);

    await tester.tap(find.byKey(const Key('card-fullscreen')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('membership-card')), findsOneWidget);
    expect(find.byKey(const Key('card-fullscreen')), findsNothing);
  });

  testWidgets('pending payment explains when the card will be active', (
    tester,
  ) async {
    await openCard(tester, card(CardState.pendingPayment));

    expect(
      find.textContaining('se activará cuando se complete el pago'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('card-fullscreen')), findsNothing);
  });

  testWidgets('not renewed members are not active in the new season', (
    tester,
  ) async {
    await openCard(tester, card(CardState.notRenewed, season: '2027/2028'));

    expect(
      find.text(
        'No eres socio de la temporada 2027/2028. Habla con tu club si '
        'quieres renovar.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('without an active season the card is announced', (tester) async {
    await openCard(tester, card(CardState.noSeason));

    expect(find.byKey(const Key('card-no-season')), findsOneWidget);
  });

  test('maps the card row', () {
    final mapped = membershipCardFromRow(
      {
        'club_name': 'IDEFIC',
        'club_primary_color': '#0B3D91',
        'club_secondary_color': null,
        'first_name': 'Ana',
        'last_name': 'Pérez',
        'member_number': 2,
        'season_name': '2026/2027',
        'state': 'pending_payment',
        'card_token': null,
      },
      logoUrl: 'https://cdn/logo.png',
      photoUrl: 'https://signed/photo.jpg',
    );
    expect(mapped.state, CardState.pendingPayment);
    expect(mapped.fullName, 'Ana Pérez');
    expect(mapped.photoUrl, 'https://signed/photo.jpg');
  });
}
