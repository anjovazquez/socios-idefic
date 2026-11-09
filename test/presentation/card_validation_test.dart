import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/application/card/card_use_cases.dart';
import 'package:socios_idefic/domain/card/card_validation.dart';
import 'package:socios_idefic/domain/card/membership_card.dart';
import 'package:socios_idefic/domain/member/club_member.dart';
import 'package:socios_idefic/domain/season/season_membership.dart';
import 'package:socios_idefic/infrastructure/card/supabase_card_repository.dart';
import 'package:socios_idefic/presentation/app/socios_app.dart';
import 'package:socios_idefic/presentation/card/card_qr.dart';

import '../support/fakes.dart';
import '../support/navigation.dart';

// BDD: tasks/VS-016.md — Validar carnet.
void main() {
  const token = 'Ab3dEfGhIjKlMnOpQrStUv';
  late FakeCardRepository cards;

  setUp(() {
    cards = FakeCardRepository({
      'ana@example.com': const MembershipCard(
        clubName: 'IDEFIC',
        state: CardState.active,
        firstName: 'Ana',
        lastName: 'Pérez',
        memberNumber: 2,
        seasonName: '2026/2027',
        cardToken: token,
      ),
    });
    cards.validations[token] = const CardValidation(
      state: ValidationState.active,
      clubName: 'IDEFIC',
      firstName: 'Ana',
      lastName: 'Pérez',
      memberNumber: 2,
      seasonName: '2026/2027',
    );
    cards.validations['OldSeasonTokenXXXXXXXX'] = const CardValidation(
      state: ValidationState.notCurrent,
      clubName: 'IDEFIC',
      firstName: 'Ana',
      lastName: 'Pérez',
      memberNumber: 2,
      seasonName: '2025/2026',
    );
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    String? initialLocation,
    FakeMembersRepository? members,
  }) async {
    tester.view.physicalSize = const Size(900, 1600);
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
          cards: cards,
          members: members,
        ),
        initialLocation: initialLocation,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> signIn(WidgetTester tester, String email) async {
    await tester.enterText(find.byKey(const Key('login-email')), email);
    await tester.enterText(find.byKey(const Key('login-password')), 'pw');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
  }

  testWidgets('scanning an active card, without a session', (tester) async {
    await pumpApp(tester, initialLocation: '/v/$token');

    expect(find.text('SOCIO ACTIVO'), findsOneWidget);
    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.text('Socio nº 2 · Temporada 2026/2027'), findsOneWidget);
    expect(find.text('IDEFIC'), findsOneWidget);
    expect(find.byKey(const Key('login-email')), findsNothing);
  });

  testWidgets('a card of a previous season', (tester) async {
    await pumpApp(tester, initialLocation: '/v/OldSeasonTokenXXXXXXXX');

    expect(find.text('NO VÁLIDO PARA LA TEMPORADA ACTUAL'), findsOneWidget);
    expect(find.text('Socio nº 2 · Temporada 2025/2026'), findsOneWidget);
  });

  testWidgets('an invented token reveals nothing', (tester) async {
    await pumpApp(tester, initialLocation: '/v/abc123');

    expect(find.text('CARNET NO ENCONTRADO'), findsOneWidget);
    expect(find.text('Ana Pérez'), findsNothing);
    expect(cards.lookups, isEmpty);
  });

  testWidgets('the active card shows the QR', (tester) async {
    await pumpApp(tester);
    await signIn(tester, 'ana@example.com');
    await tester.tap(find.byKey(const Key('open-card')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('card-qr')), findsOneWidget);
  });

  testWidgets('a regenerated card makes the old QR stop working', (
    tester,
  ) async {
    final members = FakeMembersRepository(
      members: {
        ideficAsAdmin.id: [
          const ClubMember(
            membershipId: 'm-ana',
            email: 'ana@example.com',
            firstName: 'Ana',
            memberNumber: 2,
            isClubAdmin: false,
            status: MemberStatus.active,
            seasonMembershipId: 'sm-ana',
            seasonFeeCents: 5000,
            seasonStatus: SeasonMembershipStatus.active,
          ),
        ],
      },
    );
    await pumpApp(tester, members: members);
    await signIn(tester, 'admin@example.com');
    await openAdminSection(tester, 'open-members');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('member-ana@example.com')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('member-regenerate-card')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-regenerate-card')));
    await tester.pumpAndSettle();

    expect(cards.regenerated, ['sm-ana']);
    expect(find.textContaining('el QR anterior ya no sirve'), findsOneWidget);
    expect((await ValidateCard(cards)(token)).state, ValidationState.notFound);
  });

  test('QR url and payload mapping', () {
    expect(
      cardValidationUrl('https://socios.es/', token),
      'https://socios.es/#/v/$token',
    );
    expect(publicAppUrl(), isA<String>());
    final mapped = cardValidationFromJson({
      'state': 'not_current',
      'club': {'name': 'IDEFIC', 'logoUrl': null, 'primaryColor': '#0B3D91'},
      'member': {
        'firstName': 'Ana',
        'lastName': 'Pérez',
        'photoUrl': 'https://signed/p.jpg',
        'memberNumber': 2,
      },
      'seasonName': '2025/2026',
    });
    expect(mapped.state, ValidationState.notCurrent);
    expect(mapped.photoUrl, 'https://signed/p.jpg');
    expect(
      cardValidationFromJson({'state': 'not_found'}).state,
      ValidationState.notFound,
    );
  });
}
