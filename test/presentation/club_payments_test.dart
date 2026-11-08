import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/domain/payment/club_payments.dart';
import 'package:socios_idefic/domain/payment/payment.dart';
import 'package:socios_idefic/domain/payment/receipt.dart';
import 'package:socios_idefic/domain/season/season.dart';
import 'package:socios_idefic/infrastructure/payment/supabase_payments_repository.dart';
import 'package:socios_idefic/presentation/app/socios_app.dart';

import '../support/fakes.dart';

// BDD: tasks/VS-020.md — Pagos del club.
void main() {
  ClubPaymentLine line(
    String id, {
    required String name,
    required String season,
    required PaymentStatus status,
    int amount = 5000,
    int? number,
    bool fee = false,
  }) => ClubPaymentLine(
    paymentId: fee ? null : id,
    seasonMembershipId: 'sm-$id',
    seasonId: 'season-$season',
    seasonName: season == '26' ? '2026/2027' : '2025/2026',
    memberName: name,
    memberEmail: '${name.toLowerCase()}@example.com',
    memberNumber: number,
    concept: 'Cuota de socio',
    amountCents: amount,
    date: fee ? null : DateTime(2026, 9, 10),
    status: status,
    method: status == PaymentStatus.paid ? PaymentMethod.bizum : null,
    receiptNumber: status == PaymentStatus.paid ? 1 : null,
  );

  late FakePaymentsRepository payments;
  late FakeReceiptRenderer renderer;

  setUp(() {
    renderer = FakeReceiptRenderer();
    payments = FakePaymentsRepository()
      ..clubLines[ideficAsAdmin.id] = [
        line(
          'p-marta-26',
          name: 'Marta',
          season: '26',
          status: PaymentStatus.paid,
          number: 3,
        ),
        line(
          'p-pablo-26',
          name: 'Pablo',
          season: '26',
          status: PaymentStatus.pending,
          fee: true,
        ),
        line(
          'p-marta-25',
          name: 'Marta',
          season: '25',
          status: PaymentStatus.paid,
          amount: 4500,
          number: 3,
        ),
        line(
          'p-luis-25',
          name: 'Luis',
          season: '25',
          status: PaymentStatus.cancelled,
          amount: 4500,
        ),
      ]
      ..receipts['p-marta-26'] = Receipt(
        paymentId: 'p-marta-26',
        number: 1,
        clubName: 'IDEFIC',
        clubCode: 'IDEFIC',
        memberName: 'Marta',
        seasonName: '2026/2027',
        concept: 'Cuota de socio',
        amountCents: 5000,
        paidAt: DateTime(2026, 9, 10),
      );
  });

  Future<void> openPayments(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final seasons = FakeSeasonRepository({
      ideficAsAdmin.id: [
        Season(
          id: 'season-26',
          clubId: ideficAsAdmin.id,
          name: '2026/2027',
          startsOn: DateTime(2026, 9),
          endsOn: DateTime(2027, 8, 31),
          status: SeasonStatus.active,
          defaultFeeCents: 5000,
        ),
        Season(
          id: 'season-25',
          clubId: ideficAsAdmin.id,
          name: '2025/2026',
          startsOn: DateTime(2025, 9),
          endsOn: DateTime(2026, 8, 31),
          status: SeasonStatus.closed,
          defaultFeeCents: 4500,
        ),
      ],
    });
    await tester.pumpWidget(
      SociosApp(
        useCases: buildUseCases(
          auth: FakeAuthRepository(passwords: {'admin@example.com': 'pw'}),
          clubs: FakeClubRepository({
            'admin@example.com': [ideficAsAdmin],
          }),
          seasons: seasons,
          payments: payments,
          receiptRenderer: renderer,
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
    await tester.tap(find.byKey(const Key('open-payments')));
    await tester.pumpAndSettle();
  }

  testWidgets('starts on the active season with collected and pending totals', (
    tester,
  ) async {
    await openPayments(tester);

    expect(find.text('2026/2027'), findsOneWidget);
    expect(find.byKey(const Key('club-payment-p-marta-26')), findsOneWidget);
    expect(
      find.byKey(const Key('club-payment-fee-sm-p-pablo-26')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('club-payment-p-marta-25')), findsNothing);
    expect(find.text('2 movimientos'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('payments-paid-total')),
        matching: find.text('50,00 €'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Cuota sin pagar'), findsOneWidget);
  });

  testWidgets(
    'filter by status: only the pending ones of that season and their total',
    (tester) async {
      await openPayments(tester);

      await tester.tap(find.byKey(const Key('payments-filter-pending')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('club-payment-fee-sm-p-pablo-26')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('club-payment-p-marta-26')), findsNothing);
      expect(find.text('1 movimiento'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('payments-pending-total')),
          matching: find.text('50,00 €'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('payments-paid-total')),
          matching: find.text('0,00 €'),
        ),
        findsOneWidget,
      );
      expect(payments.clubQueries.last.seasonId, 'season-26');
      expect(payments.clubQueries.last.status, PaymentStatus.pending);
    },
  );

  testWidgets('filter by member across all seasons', (tester) async {
    await openPayments(tester);

    await tester.tap(find.byKey(const Key('payments-season')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Todas las temporadas').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('payments-search')), 'marta');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('club-payment-p-marta-26')), findsOneWidget);
    expect(find.byKey(const Key('club-payment-p-marta-25')), findsOneWidget);
    expect(
      find.byKey(const Key('club-payment-fee-sm-p-pablo-26')),
      findsNothing,
    );
    expect(find.text('2 movimientos'), findsOneWidget);
    expect(payments.clubQueries.last.seasonId, isNull);
  });

  testWidgets('the admin downloads the receipt of a paid payment', (
    tester,
  ) async {
    await openPayments(tester);

    expect(
      find.byKey(const Key('club-receipt-fee-sm-p-pablo-26')),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('club-receipt-p-marta-26')));
    await tester.pumpAndSettle();

    expect(renderer.delivered.single.paymentId, 'p-marta-26');
    expect(find.text('Recibo IDEFIC-0001 listo'), findsOneWidget);
  });

  test('maps get_club_payments rows with totals and pending fees', () {
    final page = clubPaymentsPageFromRows([
      {
        'payment_id': null,
        'season_membership_id': 'sm1',
        'season_id': 's1',
        'season_name': '2026/2027',
        'member_first_name': null,
        'member_last_name': null,
        'member_email': 'pablo@example.com',
        'member_number': 3,
        'concept': 'Cuota de socio 2026/2027',
        'amount_cents': 5000,
        'payment_date': null,
        'status': 'pending',
        'provider': null,
        'method': null,
        'receipt_number': null,
        'total_count': 7,
        'paid_cents': 10000,
        'pending_cents': 5000,
      },
    ]);
    expect(page.total, 7);
    expect(page.paidCents, 10000);
    expect(page.pendingCents, 5000);
    final pending = page.lines.single;
    expect(pending.memberName, 'pablo@example.com');
    expect(pending.id, 'fee-sm1');
    expect(pending.hasReceipt, isFalse);
    expect(clubPaymentsPageFromRows([]).total, 0);
  });
}
