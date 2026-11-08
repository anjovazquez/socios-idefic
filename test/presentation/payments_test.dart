import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/application/payment/payment_use_cases.dart';
import 'package:socios_idefic/domain/card/membership_card.dart';
import 'package:socios_idefic/domain/member/club_member.dart';
import 'package:socios_idefic/domain/payment/payment.dart';
import 'package:socios_idefic/domain/season/season_membership.dart';
import 'package:socios_idefic/infrastructure/payment/supabase_payments_repository.dart';
import 'package:socios_idefic/presentation/app/socios_app.dart';

import '../support/fakes.dart';

// BDD: tasks/VS-017.md — Pago de cuota.
void main() {
  late FakeMembersRepository members;
  late FakePaymentsRepository payments;

  setUp(() {
    members = FakeMembersRepository(
      members: {
        ideficAsAdmin.id: [
          const ClubMember(
            membershipId: 'm-marta',
            email: 'marta@example.com',
            firstName: 'Marta',
            memberNumber: 3,
            isClubAdmin: false,
            status: MemberStatus.active,
            seasonMembershipId: 'sm-marta',
            seasonFeeCents: 5000,
            seasonStatus: SeasonMembershipStatus.pendingPayment,
          ),
        ],
      },
    );
    payments = FakePaymentsRepository()
      ..instructions[ideficAsAdmin.id] = 'Bizum al 600 000 000';
  });

  Future<void> signIn(
    WidgetTester tester,
    String email, {
    FakeCardRepository? cards,
  }) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      SociosApp(
        useCases: buildUseCases(
          auth: FakeAuthRepository(
            passwords: {'admin@example.com': 'pw', 'marta@example.com': 'pw'},
          ),
          clubs: FakeClubRepository({
            'admin@example.com': [ideficAsAdmin],
            'marta@example.com': [idefic],
          }),
          members: members,
          payments: payments,
          cards: cards,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('login-email')), email);
    await tester.enterText(find.byKey(const Key('login-password')), 'pw');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
  }

  Future<void> openMarta(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('open-members')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('member-marta@example.com')));
    await tester.pumpAndSettle();
  }

  Future<void> record(WidgetTester tester, {String? amount}) async {
    await tester.tap(find.byKey(const Key('member-record-payment')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('record-payment-method-bizum')));
    await tester.pumpAndSettle();
    if (amount != null) {
      await tester.enterText(
        find.byKey(const Key('record-payment-amount')),
        amount,
      );
    }
    await tester.enterText(
      find.byKey(const Key('record-payment-reference')),
      'BZ-77',
    );
    await tester.tap(find.byKey(const Key('record-payment-save')));
    await tester.pumpAndSettle();
  }

  ClubMember marta() => members.members[ideficAsAdmin.id]!.single;

  testWidgets('a manual payment makes Marta an active member', (tester) async {
    await signIn(tester, 'admin@example.com');
    await openMarta(tester);

    await record(tester);

    expect(find.text('Pago de Marta registrado'), findsOneWidget);
    expect(marta().seasonStatus, SeasonMembershipStatus.active);
    final payment = payments.payments['sm-marta']!.single;
    expect(payment.amountCents, 5000);
    expect(payment.method, PaymentMethod.bizum);
    expect(payment.reference, 'BZ-77');
    expect(find.textContaining('50,00 € · Socio'), findsOneWidget);
  });

  testWidgets('the record shows the payment and it can be cancelled', (
    tester,
  ) async {
    await signIn(tester, 'admin@example.com');
    await openMarta(tester);
    await record(tester);
    await tester.tap(find.byKey(const Key('member-marta@example.com')));
    await tester.pumpAndSettle();

    final list = find.byKey(const Key('member-payments'));
    expect(
      find.descendant(of: list, matching: find.text('Pagado')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: list,
        matching: find.textContaining('50,00 € · Bizum'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('cancel-payment-pay-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-cancel-payment')));
    await tester.pumpAndSettle();

    expect(find.text('Pago anulado'), findsOneWidget);
    expect(marta().seasonStatus, SeasonMembershipStatus.pendingPayment);
  });

  testWidgets('an invalid amount is explained', (tester) async {
    await signIn(tester, 'admin@example.com');
    await openMarta(tester);

    await record(tester, amount: '0');

    expect(find.text('Escribe un importe mayor que 0'), findsOneWidget);
    expect(payments.payments['sm-marta'], isNull);
  });

  testWidgets('the admin writes how to pay in the settings', (tester) async {
    await signIn(tester, 'admin@example.com');
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();

    final field = find.byKey(const Key('payment-instructions'));
    await tester.ensureVisible(field);
    expect(find.text('Bizum al 600 000 000'), findsOneWidget);
    await tester.enterText(field, 'Transferencia a ES12 3456');
    await tester.tap(find.byKey(const Key('payment-instructions-save')));
    await tester.pumpAndSettle();

    expect(
      payments.instructions[ideficAsAdmin.id],
      'Transferencia a ES12 3456',
    );
    expect(find.text('Instrucciones de pago guardadas'), findsOneWidget);
  });

  testWidgets('a member with a pending fee sees how to pay', (tester) async {
    final cards = FakeCardRepository({
      'marta@example.com': const MembershipCard(
        clubName: 'IDEFIC',
        state: CardState.pendingPayment,
        firstName: 'Marta',
        memberNumber: 3,
        seasonName: '2026/2027',
        seasonMembershipId: 'sm-marta',
        feeCents: 5000,
      ),
    });
    payments.instructions[idefic.id] = 'Bizum al 600 000 000';
    await signIn(tester, 'marta@example.com', cards: cards);
    await tester.tap(find.byKey(const Key('open-card')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('card-how-to-pay')));
    await tester.pumpAndSettle();

    expect(find.text('Cómo pagar tu cuota de 50,00 €'), findsOneWidget);
    expect(find.text('Bizum al 600 000 000'), findsOneWidget);
  });

  test('use cases and mappers', () async {
    final repo = FakePaymentsRepository();
    expect(
      () => RecordManualPayment(repo)(
        seasonMembershipId: 'x',
        method: PaymentMethod.card,
      ),
      throwsA(isA<PaymentUnavailableFailure>()),
    );
    expect(
      () => RecordManualPayment(repo)(
        seasonMembershipId: 'x',
        method: PaymentMethod.cash,
        amount: '-3',
      ),
      throwsA(isA<InvalidPaymentAmountFailure>()),
    );
    final cancelled = Payment(
      id: 'p',
      seasonMembershipId: 'x',
      amountCents: 100,
      concept: 'c',
      status: PaymentStatus.cancelled,
      provider: PaymentProvider.manual,
      createdAt: DateTime(2026),
    );
    expect(
      () => CancelPayment(repo)(cancelled),
      throwsA(isA<InvalidPaymentTransitionFailure>()),
    );
    final mapped = paymentFromRow({
      'id': 'p1',
      'season_membership_id': 'sm1',
      'amount_cents': 5000,
      'concept': 'Cuota de socio 2026/2027',
      'status': 'paid',
      'provider': 'manual',
      'method': 'transfer',
      'provider_reference': 'TRF',
      'paid_at': '2026-11-09T10:00:00+00:00',
      'created_at': '2026-11-09T10:00:00+00:00',
    });
    expect(mapped.method, PaymentMethod.transfer);
    expect(mapped.canBeCancelled, isTrue);
    expect(
      mapPaymentError('P0001', 'x', 'already_paid'),
      isA<AlreadyPaidFailure>(),
    );
    expect(
      mapPaymentError('P0001', 'x', 'invalid_transition'),
      isA<InvalidPaymentTransitionFailure>(),
    );
    expect(
      mapPaymentError('22023', 'invalid amount', null),
      isA<InvalidPaymentAmountFailure>(),
    );
  });
}
