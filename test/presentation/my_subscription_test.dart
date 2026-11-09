import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/domain/payment/my_subscription.dart';
import 'package:socios_idefic/domain/payment/payment.dart';
import 'package:socios_idefic/domain/payment/receipt.dart';
import 'package:socios_idefic/domain/season/season_membership.dart';
import 'package:socios_idefic/presentation/app/socios_app.dart';

import '../support/fakes.dart';

// BDD: tasks/VS-018.md — Mi suscripción e histórico de pagos.
void main() {
  Future<void> openSubscription(
    WidgetTester tester,
    FakePaymentsRepository payments, {
    FakeReceiptRenderer? renderer,
  }) async {
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
          payments: payments,
          receiptRenderer: renderer,
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
    await tester.tap(find.byKey(const Key('open-subscription')));
    await tester.pumpAndSettle();
  }

  testWidgets('a member sees her season, fee, status, method and history', (
    tester,
  ) async {
    final payments = FakePaymentsRepository()
      ..subscriptions[idefic.id] = const MySubscription(
        seasonName: '2026/2027',
        seasonMembershipId: 'sm-ana',
        feeCents: 5000,
        status: SeasonMembershipStatus.active,
        lastMethod: PaymentMethod.transfer,
      )
      ..myPayments[idefic.id] = [
        MyPayment(
          id: 'p2',
          seasonName: '2026/2027',
          concept: 'Cuota de socio 2026/2027',
          amountCents: 5000,
          date: DateTime(2026, 9, 10),
          status: PaymentStatus.paid,
          method: PaymentMethod.transfer,
        ),
        MyPayment(
          id: 'p1',
          seasonName: '2025/2026',
          concept: 'Cuota de socio 2025/2026',
          amountCents: 4500,
          date: DateTime(2025, 9, 10),
          status: PaymentStatus.paid,
          method: PaymentMethod.cash,
        ),
      ];
    await openSubscription(tester, payments);

    expect(find.text('Temporada 2026/2027'), findsOneWidget);
    expect(find.text('Socio'), findsOneWidget);
    expect(find.text('50,00 €'), findsWidgets);
    expect(find.text('Transferencia'), findsOneWidget);
    expect(find.text('No tienes cargos programados.'), findsOneWidget);
    expect(find.byKey(const Key('subscription-how-to-pay')), findsNothing);

    expect(find.byKey(const Key('my-payment-p2')), findsOneWidget);
    expect(find.byKey(const Key('my-payment-p1')), findsOneWidget);
    expect(
      find.text('Temporada 2025/2026 · 10/09/2025 · Efectivo'),
      findsOneWidget,
    );
    expect(find.text('45,00 €'), findsOneWidget);
    expect(find.text('Pagado'), findsNWidgets(2));
    // Newest first.
    expect(
      tester.getTopLeft(find.byKey(const Key('my-payment-p2'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('my-payment-p1'))).dy),
    );
  });

  testWidgets('a pending fee shows how to pay with the club instructions', (
    tester,
  ) async {
    final payments = FakePaymentsRepository()
      ..instructions[idefic.id] = 'Bizum al 600 000 000'
      ..subscriptions[idefic.id] = const MySubscription(
        seasonName: '2026/2027',
        seasonMembershipId: 'sm-ana',
        feeCents: 5000,
        status: SeasonMembershipStatus.pendingPayment,
      );
    await openSubscription(tester, payments);

    expect(find.text('Pendiente de pago'), findsOneWidget);
    expect(find.text('Sin método registrado'), findsOneWidget);
    expect(find.byKey(const Key('payments-empty')), findsOneWidget);

    await tester.tap(find.byKey(const Key('subscription-how-to-pay')));
    await tester.pumpAndSettle();
    expect(find.text('Cómo pagar tu cuota de 50,00 €'), findsOneWidget);
    expect(find.text('Bizum al 600 000 000'), findsOneWidget);
  });

  testWidgets('without an active season it says so', (tester) async {
    await openSubscription(tester, FakePaymentsRepository());

    expect(find.byKey(const Key('subscription-no-season')), findsOneWidget);
    expect(find.byKey(const Key('payments-empty')), findsOneWidget);

    // «Mi suscripción» is a bottom bar section: back to Inicio from the bar.
    expect(find.byType(BackButton), findsNothing);
    await tester.tap(find.byKey(const Key('open-home')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-show-card')), findsOneWidget);
  });

  // BDD: tasks/VS-019.md — Recibo.
  testWidgets('a paid payment offers its receipt; a pending one does not', (
    tester,
  ) async {
    final renderer = FakeReceiptRenderer();
    final payments = FakePaymentsRepository()
      ..subscriptions[idefic.id] = const MySubscription(
        seasonName: '2026/2027',
        seasonMembershipId: 'sm-ana',
        feeCents: 5000,
        status: SeasonMembershipStatus.active,
      )
      ..myPayments[idefic.id] = [
        MyPayment(
          id: 'p-pending',
          seasonName: '2026/2027',
          concept: 'Cuota de socio 2026/2027',
          amountCents: 5000,
          date: DateTime(2026, 9, 1),
          status: PaymentStatus.pending,
        ),
        MyPayment(
          id: 'p-paid',
          seasonName: '2026/2027',
          concept: 'Cuota de socio 2026/2027',
          amountCents: 5000,
          date: DateTime(2026, 9, 10),
          status: PaymentStatus.paid,
          method: PaymentMethod.bizum,
          receiptNumber: 2,
        ),
      ]
      ..receipts['p-paid'] = Receipt(
        paymentId: 'p-paid',
        number: 2,
        clubName: 'IDEFIC',
        clubCode: 'IDEFIC',
        memberName: 'Ana Pérez',
        memberNumber: 2,
        seasonName: '2026/2027',
        concept: 'Cuota de socio 2026/2027',
        amountCents: 5000,
        paidAt: DateTime(2026, 9, 10),
      );
    await openSubscription(tester, payments, renderer: renderer);

    expect(find.byKey(const Key('receipt-p-pending')), findsNothing);
    await tester.tap(find.byKey(const Key('receipt-p-paid')));
    await tester.pumpAndSettle();

    expect(renderer.delivered.single.code, 'IDEFIC-0002');
    expect(renderer.delivered.single.memberName, 'Ana Pérez');
    expect(find.text('Recibo IDEFIC-0002 listo'), findsOneWidget);
  });

  testWidgets('a receipt the server refuses explains why', (tester) async {
    final payments = FakePaymentsRepository()
      ..subscriptions[idefic.id] = const MySubscription(
        seasonName: '2026/2027',
        status: SeasonMembershipStatus.active,
      )
      ..myPayments[idefic.id] = [
        MyPayment(
          id: 'p-gone',
          seasonName: '2026/2027',
          concept: 'Cuota de socio 2026/2027',
          amountCents: 5000,
          date: DateTime(2026, 9, 10),
          status: PaymentStatus.paid,
          receiptNumber: 1,
        ),
      ];
    await openSubscription(tester, payments);

    await tester.tap(find.byKey(const Key('receipt-p-gone')));
    await tester.pumpAndSettle();
    expect(find.text('Este pago no tiene recibo'), findsOneWidget);
  });
}
