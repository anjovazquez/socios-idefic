import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/domain/payment/my_subscription.dart';
import 'package:socios_idefic/domain/payment/payment.dart';
import 'package:socios_idefic/domain/season/season_membership.dart';
import 'package:socios_idefic/infrastructure/payment/supabase_payments_repository.dart';
import 'package:socios_idefic/presentation/app/socios_app.dart';

import '../support/fakes.dart';

// BDD: tasks/VS-024.md — Renovación automática (lado app; el cobro lo hace
// charge-renewals).
void main() {
  late FakePaymentsRepository payments;

  setUp(() {
    payments = FakePaymentsRepository()
      ..subscriptions[idefic.id] = MySubscription(
        seasonName: '2026/2027',
        seasonMembershipId: 'sm-26',
        feeCents: 5000,
        status: SeasonMembershipStatus.active,
        onlinePayments: true,
        nextChargeCents: 5000,
        nextChargeOn: DateTime(2027, 9),
        nextChargeSeason: '2027/2028',
        nextChargeSeasonMembershipId: 'sm-27',
        nextChargeCancellable: true,
      );
  });

  Future<void> openSubscription(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      SociosApp(
        useCases: buildUseCases(
          auth: FakeAuthRepository(passwords: {'marta@example.com': 'pw'}),
          clubs: FakeClubRepository({
            'marta@example.com': [idefic],
          }),
          payments: payments,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('login-email')),
      'marta@example.com',
    );
    await tester.enterText(find.byKey(const Key('login-password')), 'pw');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-subscription')));
    await tester.pumpAndSettle();
  }

  testWidgets('Marta cancels the renewal before the charge: no charge', (
    tester,
  ) async {
    await openSubscription(tester);

    await tester.tap(find.byKey(const Key('cancel-renewal')));
    await tester.pumpAndSettle();
    expect(find.text('¿Cancelar la renovación de 2027/2028?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cancel-renewal-confirm')));
    await tester.pumpAndSettle();

    expect(payments.cancelledRenewals, ['sm-27']);
    expect(
      find.text('Renovación de 2027/2028 cancelada. No se te cobrará'),
      findsOneWidget,
    );
    expect(find.text('No tienes cargos programados.'), findsOneWidget);
    expect(find.byKey(const Key('cancel-renewal')), findsNothing);
  });

  testWidgets('late cancellation: the server refuses and says to contact '
      'the club', (tester) async {
    payments.chargedRenewals.add('sm-27');
    await openSubscription(tester);

    await tester.tap(find.byKey(const Key('cancel-renewal')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cancel-renewal-confirm')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'La renovación ya se ha cobrado o se está cobrando. Si necesitas '
        'cambiarla, contacta con tu club',
      ),
      findsOneWidget,
    );
  });

  testWidgets('on the charge date it can no longer be cancelled', (
    tester,
  ) async {
    final s = payments.subscriptions[idefic.id]!;
    payments.subscriptions[idefic.id] = MySubscription(
      seasonName: s.seasonName,
      seasonMembershipId: s.seasonMembershipId,
      feeCents: s.feeCents,
      status: s.status,
      nextChargeCents: 5000,
      nextChargeOn: DateTime(2027, 9),
      nextChargeSeason: '2027/2028',
      nextChargeSeasonMembershipId: 'sm-27',
    );
    await openSubscription(tester);

    expect(find.byKey(const Key('next-charge')), findsOneWidget);
    expect(find.byKey(const Key('cancel-renewal')), findsNothing);
  });

  test('maps the late cancellation error', () {
    expect(
      mapPaymentError(
        'P0001',
        'renewal can no longer be cancelled',
        'renewal_too_late',
      ),
      isA<RenewalTooLateFailure>(),
    );
  });
}
