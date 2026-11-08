import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/domain/payment/my_subscription.dart';
import 'package:socios_idefic/domain/season/season_membership.dart';
import 'package:socios_idefic/infrastructure/payment/supabase_payments_repository.dart';
import 'package:socios_idefic/presentation/app/socios_app.dart';
import 'package:socios_idefic/presentation/payment/my_subscription_page.dart';

import '../support/fakes.dart';

// BDD: tasks/VS-022.md — Método de pago guardado.
void main() {
  late FakePaymentsRepository payments;
  late List<Uri> opened;

  setUp(() {
    opened = [];
    payments = FakePaymentsRepository()
      ..checkouts['sm-marta'] = Uri.parse('https://checkout.stripe.test/cs_1');
  });

  MySubscription subscription({
    SeasonMembershipStatus status = SeasonMembershipStatus.pendingPayment,
  }) => MySubscription(
    seasonName: '2026/2027',
    seasonMembershipId: 'sm-marta',
    feeCents: 5000,
    status: status,
    onlinePayments: true,
  );

  Future<void> openSubscription(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2000);
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
        openUrl: (url) async => opened.add(url),
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

  testWidgets('paying with «renovar automáticamente» asks to keep the method', (
    tester,
  ) async {
    payments.subscriptions[idefic.id] = subscription();
    await openSubscription(tester);

    final checkbox = find.byKey(const Key('save-for-renewal'));
    expect(tester.widget<CheckboxListTile>(checkbox).value, isFalse);
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('subscription-pay-online')));
    await tester.pumpAndSettle();

    expect(payments.checkoutSaveFlags, [true]);
    expect(opened.single.host, 'checkout.stripe.test');
  });

  testWidgets('her subscription shows the card ending in 4242 and automatic '
      'renewal on', (tester) async {
    payments
      ..subscriptions[idefic.id] = subscription(
        status: SeasonMembershipStatus.active,
      )
      ..renewal[idefic.id] = const RenewalSetup(
        autoRenew: true,
        method: SavedPaymentMethod(
          kind: SavedMethodKind.card,
          brand: 'visa',
          last4: '4242',
        ),
      );
    await openSubscription(tester);

    expect(find.text('Visa ···· 4242'), findsOneWidget);
    expect(find.byKey(const Key('auto-renew-on')), findsOneWidget);
    expect(find.text('Cambiar método'), findsOneWidget);
  });

  testWidgets('removing the method turns automatic renewal off', (
    tester,
  ) async {
    payments
      ..subscriptions[idefic.id] = subscription(
        status: SeasonMembershipStatus.active,
      )
      ..renewal[idefic.id] = const RenewalSetup(
        autoRenew: true,
        method: SavedPaymentMethod(
          kind: SavedMethodKind.card,
          brand: 'visa',
          last4: '4242',
        ),
      );
    await openSubscription(tester);

    await tester.tap(find.byKey(const Key('remove-method')));
    await tester.pumpAndSettle();
    expect(find.textContaining('se desactivará'), findsOneWidget);
    await tester.tap(find.byKey(const Key('remove-method-confirm')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auto-renew-on')), findsNothing);
    expect(find.byKey(const Key('saved-method')), findsNothing);
    expect(
      find.text('Método eliminado. La renovación automática está desactivada'),
      findsOneWidget,
    );
    expect(payments.renewal[idefic.id]?.method, isNull);
  });

  testWidgets(
    'a bank account is shown masked and can be saved without paying',
    (tester) async {
      payments
        ..subscriptions[idefic.id] = subscription(
          status: SeasonMembershipStatus.active,
        )
        ..renewal[idefic.id] = const RenewalSetup(
          autoRenew: true,
          method: SavedPaymentMethod(
            kind: SavedMethodKind.sepaDebit,
            last4: '3000',
            country: 'ES',
          ),
        );
      await openSubscription(tester);

      expect(find.text('Domiciliación ES ···· 3000'), findsOneWidget);
      await tester.tap(find.byKey(const Key('set-up-method')));
      await tester.pumpAndSettle();
      expect(opened.single.path, '/setup/club-idefic');
    },
  );

  test('labels and mapping never need full data', () {
    expect(
      savedMethodLabel(
        const SavedPaymentMethod(kind: SavedMethodKind.card, last4: '0005'),
      ),
      'Tarjeta ···· 0005',
    );
    final setup = renewalSetupFromRow({
      'kind': 'sepa_debit',
      'brand': null,
      'last4': '3000',
      'country': 'ES',
      'auto_renew': true,
    });
    expect(setup.isAutomatic, isTrue);
    expect(setup.method?.kind, SavedMethodKind.sepaDebit);
    expect(
      renewalSetupFromRow({'kind': null, 'auto_renew': false}).method,
      isNull,
    );
  });
}
