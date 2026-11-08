import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/application/season/season_use_cases.dart';
import 'package:socios_idefic/domain/season/renewal.dart';
import 'package:socios_idefic/domain/season/season.dart';
import 'package:socios_idefic/infrastructure/season/supabase_season_repository.dart';
import 'package:socios_idefic/presentation/app/socios_app.dart';

import '../support/fakes.dart';

// BDD: tasks/VS-014.md — Renovación masiva.
void main() {
  late FakeSeasonRepository seasons;

  RenewalCandidate candidate(
    int number,
    String name, {
    int previous = 5000,
    bool custom = false,
  }) => RenewalCandidate(
    membershipId: 'm$number',
    email: '${name.toLowerCase()}@example.com',
    firstName: name,
    memberNumber: number,
    previousSeasonName: '2026/2027',
    previousFeeCents: previous,
    previousWasCustom: custom,
    proposedFeeCents: custom ? previous : 5500,
    alreadyRenewed: false,
  );

  setUp(() {
    seasons = FakeSeasonRepository({
      'club-idefic': [
        Season(
          id: 'season-2027/2028',
          clubId: 'club-idefic',
          name: '2027/2028',
          startsOn: DateTime(2027, 9),
          endsOn: DateTime(2028, 8, 31),
          status: SeasonStatus.active,
          defaultFeeCents: 5500,
        ),
      ],
    });
    seasons.candidates['season-2027/2028'] = [
      candidate(1, 'Admin', previous: 0, custom: true),
      candidate(2, 'Ana'),
      candidate(3, 'Marta'),
      candidate(4, 'Luis'),
    ];
  });

  Future<void> openRenewal(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = FakeAuthRepository(passwords: {'admin@example.com': 'pw'});
    await tester.pumpWidget(
      SociosApp(
        useCases: buildUseCases(
          auth: auth,
          clubs: FakeClubRepository({
            'admin@example.com': [ideficAsAdmin],
          }),
          seasons: seasons,
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
    await tester.tap(find.byKey(const Key('open-seasons')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('season-renew-2027/2028')));
    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('renewal-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-renewal')));
    await tester.pumpAndSettle();
  }

  testWidgets('renew everybody', (tester) async {
    await openRenewal(tester);
    expect(find.text('Renovar socios · 2027/2028'), findsOneWidget);
    expect(
      find.text('4 a renovar · 0 excluidos\nTotal previsto: 165,00 €'),
      findsOneWidget,
    );

    await confirm(tester);

    expect(find.text('4 socios renovados'), findsOneWidget);
    expect(seasons.renewals.single, hasLength(4));
    expect(find.text('Ya renovado'), findsNWidgets(4));
  });

  testWidgets('exclude some and adjust a fee', (tester) async {
    await openRenewal(tester);

    await tester.tap(find.byKey(const Key('renewal-luis@example.com')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('renewal-fee-marta@example.com')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('renewal-fee-field')), '25');
    await tester.tap(find.byKey(const Key('renewal-fee-save')));
    await tester.pumpAndSettle();

    expect(
      find.text('3 a renovar · 1 excluidos\nTotal previsto: 80,00 €'),
      findsOneWidget,
    );
    await confirm(tester);

    final items = seasons.renewals.single;
    expect(items.map((i) => i.membershipId), ['m1', 'm2', 'm3']);
    expect(items.firstWhere((i) => i.membershipId == 'm3').feeCents, 2500);
    expect(items.firstWhere((i) => i.membershipId == 'm1').feeCents, 0);
  });

  testWidgets('custom fees can be reset to the ordinary fee', (tester) async {
    await openRenewal(tester);

    await tester.tap(find.byKey(const Key('renewal-keep-custom')));
    await tester.pumpAndSettle();

    expect(
      find.text('4 a renovar · 0 excluidos\nTotal previsto: 220,00 €'),
      findsOneWidget,
    );
  });

  testWidgets('renewing again does not duplicate', (tester) async {
    await openRenewal(tester);
    await confirm(tester);

    expect(find.byKey(const Key('renewal-submit')), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('renewal-submit')),
    );
    expect(button.onPressed, isNull);
    expect(find.text('4 ya renovados'), findsOneWidget);
  });

  test('BulkRenew needs someone and valid fees', () {
    final renew = BulkRenew(FakeSeasonRepository());
    expect(() => renew('s', []), throwsA(isA<NothingToRenewFailure>()));
    expect(
      () => renew('s', [const RenewalItem(membershipId: 'm', feeCents: -1)]),
      throwsA(isA<InvalidSeasonDataFailure>()),
    );
  });

  test('maps candidates and the not renewable error', () {
    final c = renewalCandidateFromRow({
      'membership_id': 'm1',
      'email': 'a@b.es',
      'first_name': 'Ana',
      'last_name': null,
      'member_number': 2,
      'previous_season_name': '2026/2027',
      'previous_fee_cents': 0,
      'previous_was_custom': true,
      'proposed_fee_cents': 0,
      'already_renewed': false,
    });
    expect(c.previousWasCustom, isTrue);
    expect(
      mapSeasonError('P0001', 'member not renewable', 'not_renewable'),
      isA<NotRenewableFailure>(),
    );
  });
}
