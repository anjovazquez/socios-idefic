import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/application/season/season_use_cases.dart';
import 'package:socios_idefic/domain/payment/my_subscription.dart';
import 'package:socios_idefic/domain/season/season.dart';
import 'package:socios_idefic/domain/season/season_membership.dart';
import 'package:socios_idefic/infrastructure/payment/supabase_payments_repository.dart';
import 'package:socios_idefic/infrastructure/season/supabase_season_repository.dart';
import 'package:socios_idefic/presentation/app/socios_app.dart';
import 'package:socios_idefic/presentation/format/money.dart';

import '../support/fakes.dart';
import '../support/navigation.dart';

// BDD: tasks/VS-023.md — Aviso previo (lado app: fecha de cobro y próximo
// cargo; el envío lo hace send-renewal-notices).
void main() {
  final next = Season(
    id: 'season-27',
    clubId: ideficAsAdmin.id,
    name: '2027/2028',
    startsOn: DateTime(2027, 9),
    endsOn: DateTime(2028, 8, 31),
    status: SeasonStatus.draft,
  );

  Future<void> signIn(
    WidgetTester tester,
    String email, {
    FakePaymentsRepository? payments,
    FakeSeasonRepository? seasons,
  }) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      SociosApp(
        useCases: buildUseCases(
          auth: FakeAuthRepository(
            passwords: {'marta@example.com': 'pw', 'admin@example.com': 'pw'},
          ),
          clubs: FakeClubRepository({
            'marta@example.com': [idefic],
            'admin@example.com': [ideficAsAdmin],
          }),
          payments: payments,
          seasons: seasons,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('login-email')), email);
    await tester.enterText(find.byKey(const Key('login-password')), 'pw');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
  }

  testWidgets('Mi suscripción shows the next charge: 50 € on 1 September', (
    tester,
  ) async {
    final payments = FakePaymentsRepository()
      ..subscriptions[idefic.id] = MySubscription(
        seasonName: '2026/2027',
        seasonMembershipId: 'sm-26',
        feeCents: 5000,
        status: SeasonMembershipStatus.active,
        onlinePayments: true,
        nextChargeCents: 5000,
        nextChargeOn: DateTime(2027, 9),
        nextChargeSeason: '2027/2028',
      );
    await signIn(tester, 'marta@example.com', payments: payments);
    await tester.tap(find.byKey(const Key('open-subscription')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Próximo cargo: 50,00 € el 1 de septiembre de 2027 · Temporada '
        '2027/2028. Te avisaremos antes.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the admin sets the charge date and the notice days', (
    tester,
  ) async {
    final seasons = FakeSeasonRepository({
      ideficAsAdmin.id: [next],
    });
    await signIn(tester, 'admin@example.com', seasons: seasons);
    await openAdminSection(tester, 'open-seasons');
    await tester.pumpAndSettle();

    expect(
      find.text('Cobro automático: 01/09/2027 · aviso 15 días antes'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('season-renewal-2027/2028')));
    await tester.pumpAndSettle();
    expect(find.text('El aviso se enviará el 17/08/2027'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('renewal-notice-days')), '10');
    await tester.pumpAndSettle();
    expect(find.text('El aviso se enviará el 22/08/2027'), findsOneWidget);
    await tester.tap(find.byKey(const Key('renewal-charge-save')));
    await tester.pumpAndSettle();

    expect(
      find.text('Cobro automático: 01/09/2027 · aviso 10 días antes'),
      findsOneWidget,
    );
    expect(
      find.text('Cobro automático de 2027/2028 actualizado'),
      findsOneWidget,
    );
  });

  testWidgets('notice days out of range are explained', (tester) async {
    await signIn(
      tester,
      'admin@example.com',
      seasons: FakeSeasonRepository({
        ideficAsAdmin.id: [next],
      }),
    );
    await openAdminSection(tester, 'open-seasons');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('season-renewal-2027/2028')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('renewal-notice-days')), '0');
    await tester.tap(find.byKey(const Key('renewal-charge-save')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'El aviso debe ser de 1 a 60 días y el cobro, dentro de la temporada',
      ),
      findsOneWidget,
    );
  });

  test('closed seasons and charges after the season are rejected', () {
    final useCase = SetSeasonRenewal(FakeSeasonRepository());
    final closed = Season(
      id: 's',
      clubId: 'c',
      name: '2025/2026',
      startsOn: DateTime(2025, 9),
      endsOn: DateTime(2026, 8, 31),
      status: SeasonStatus.closed,
    );
    expect(
      () => useCase(
        season: closed,
        chargeOn: DateTime(2025, 9),
        noticeDays: '15',
      ),
      throwsA(isA<SeasonClosedFailure>()),
    );
    expect(
      () =>
          useCase(season: next, chargeOn: DateTime(2028, 9), noticeDays: '15'),
      throwsA(isA<InvalidSeasonDataFailure>()),
    );
    expect(next.noticeOn, DateTime(2027, 8, 17));
  });

  test('maps renewal fields and the next charge', () {
    final season = seasonFromRow({
      'id': 's',
      'club_id': 'c',
      'name': '2027/2028',
      'starts_on': '2027-09-01',
      'ends_on': '2028-08-31',
      'default_fee_cents': 5000,
      'status': 'draft',
      'renewal_charge_on': '2027-09-15',
      'renewal_notice_days': 10,
    });
    expect(season.chargeOn, DateTime(2027, 9, 15));
    expect(season.renewalNoticeDays, 10);
    final subscription = mySubscriptionFromRow({
      'season_name': '2026/2027',
      'status': 'active',
      'next_charge_cents': 5000,
      'next_charge_on': '2027-09-01',
      'next_charge_season': '2027/2028',
    });
    expect(subscription.hasNextCharge, isTrue);
    expect(
      formatLongDate(subscription.nextChargeOn!),
      '1 de septiembre de 2027',
    );
  });
}
