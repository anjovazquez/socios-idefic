import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:socios_idefic/domain/payment/my_subscription.dart';
import 'package:socios_idefic/domain/payment/online_payments.dart';
import 'package:socios_idefic/domain/payment/payment.dart';
import 'package:socios_idefic/domain/season/season_membership.dart';
import 'package:socios_idefic/infrastructure/payment/supabase_payments_repository.dart';
import 'package:socios_idefic/presentation/app/socios_app.dart';

import '../support/fakes.dart';
import '../support/navigation.dart';

// BDD: tasks/VS-021.md — Pago online (lado app; el estado lo pone el webhook).
void main() {
  late FakePaymentsRepository payments;
  late List<Uri> opened;

  setUp(() {
    opened = [];
    payments = FakePaymentsRepository()
      ..instructions[idefic.id] = 'Bizum al 600 000 000'
      ..checkouts['sm-marta'] = Uri.parse('https://checkout.stripe.test/cs_1');
  });

  MySubscription pending({bool online = true}) => MySubscription(
    seasonName: '2026/2027',
    seasonMembershipId: 'sm-marta',
    feeCents: 5000,
    status: SeasonMembershipStatus.pendingPayment,
    onlinePayments: online,
  );

  Future<void> signIn(WidgetTester tester, String email) async {
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
        ),
        openUrl: (url) async => opened.add(url),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('login-email')), email);
    await tester.enterText(find.byKey(const Key('login-password')), 'pw');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) =>
      tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );

  Future<void> go(WidgetTester tester, String location) async {
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(location);
    await tester.pumpAndSettle();
  }

  testWidgets('Marta pays her pending 50 € online in the provider checkout', (
    tester,
  ) async {
    payments.subscriptions[idefic.id] = pending();
    await signIn(tester, 'marta@example.com');
    await tester.tap(find.byKey(const Key('open-subscription')));
    await tester.pumpAndSettle();

    expect(find.text('Otras formas de pago'), findsOneWidget);
    await tester.tap(find.byKey(const Key('subscription-pay-online')));
    await tester.pumpAndSettle();

    expect(opened, [Uri.parse('https://checkout.stripe.test/cs_1')]);
  });

  testWidgets('without online payments only the manual way is offered', (
    tester,
  ) async {
    payments.subscriptions[idefic.id] = pending(online: false);
    await signIn(tester, 'marta@example.com');
    await tester.tap(find.byKey(const Key('open-subscription')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('subscription-pay-online')), findsNothing);
    expect(find.text('Cómo pagar'), findsOneWidget);
  });

  testWidgets('if the provider is not available it says what to do', (
    tester,
  ) async {
    payments
      ..subscriptions[idefic.id] = pending()
      ..checkouts.clear();
    await signIn(tester, 'marta@example.com');
    await tester.tap(find.byKey(const Key('open-subscription')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('subscription-pay-online')));
    await tester.pumpAndSettle();

    expect(opened, isEmpty);
    expect(
      find.text(
        'El pago online no está disponible ahora. Usa otra forma de pago',
      ),
      findsOneWidget,
    );
  });

  testWidgets('back from the checkout the member is told what happens', (
    tester,
  ) async {
    payments.subscriptions[idefic.id] = pending();
    await signIn(tester, 'marta@example.com');

    await go(tester, '/club/subscription?pago=ok');
    expect(find.byKey(const Key('payment-return-ok')), findsOneWidget);

    await go(tester, '/club/subscription?pago=cancelado');
    expect(find.byKey(const Key('payment-return-cancelled')), findsOneWidget);
    // A cancelled or declined attempt can be retried.
    expect(find.byKey(const Key('subscription-pay-online')), findsOneWidget);
  });

  testWidgets('the admin connects the club with Stripe from Configuración', (
    tester,
  ) async {
    await signIn(tester, 'admin@example.com');
    await openAdminSection(tester, 'open-settings');
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('online-payments-connect')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('online-payments-notConnected')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('online-payments-connect')));
    await tester.pumpAndSettle();
    expect(opened, [Uri.parse('https://connect.stripe.test/club-idefic')]);

    // Stripe verifies the club, the admin comes back and checks.
    payments.online[ideficAsAdmin.id] = OnlinePaymentsStatus.active;
    await go(tester, '/club/settings?stripe=volver');
    await reveal(tester, find.byKey(const Key('online-payments-active')));
    expect(find.byKey(const Key('online-payments-connect')), findsNothing);
  });

  test('maps the online payment errors of the functions', () {
    expect(
      mapOnlinePaymentError(503, 'payments_not_configured'),
      isA<OnlinePaymentsUnavailableFailure>(),
    );
    expect(
      mapOnlinePaymentError(409, 'online_payments_disabled'),
      isA<OnlinePaymentsUnavailableFailure>(),
    );
    expect(
      mapOnlinePaymentError(409, 'already_paid'),
      isA<AlreadyPaidFailure>(),
    );
    expect(
      mapOnlinePaymentError(403, 'forbidden'),
      isA<PaymentPermissionFailure>(),
    );
  });
}
