import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/domain/dashboard/club_dashboard.dart';
import 'package:socios_idefic/domain/payment/payment.dart';
import 'package:socios_idefic/infrastructure/dashboard/supabase_dashboard_repository.dart';
import 'package:socios_idefic/presentation/app/socios_app.dart';

import '../support/fakes.dart';

// BDD: tasks/VS-031.md — Dashboard.
void main() {
  late FakeDashboardRepository dashboard;
  late FakePaymentsRepository payments;

  setUp(() {
    dashboard = FakeDashboardRepository()
      ..dashboards[ideficAsAdmin.id] = ClubDashboard(
        seasonName: '2026/2027',
        activeMembers: 90,
        pendingMembers: 10,
        notRenewedMembers: 3,
        invitedMembers: 2,
        autoRenewMembers: 30,
        paidCents: 450000,
        pendingCents: 100000,
        validPerks: 2,
        seasonSponsors: 3,
        latestPosts: [
          DashboardPost(
            id: 'p1',
            title: 'Asamblea de socios',
            publishedAt: DateTime(2026, 11, 7),
          ),
        ],
      );
    payments = FakePaymentsRepository();
  });

  Future<void> signIn(WidgetTester tester, {bool admin = true}) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      SociosApp(
        useCases: buildUseCases(
          auth: FakeAuthRepository(
            passwords: {'admin@example.com': 'pw', 'ana@example.com': 'pw'},
          ),
          clubs: FakeClubRepository({
            'admin@example.com': [ideficAsAdmin],
            'ana@example.com': [idefic],
          }),
          dashboard: dashboard,
          payments: payments,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('login-email')),
      admin ? 'admin@example.com' : 'ana@example.com',
    );
    await tester.enterText(find.byKey(const Key('login-password')), 'pw');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
  }

  String valueOf(WidgetTester tester, String key) {
    final texts = tester.widgetList<Text>(
      find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)),
    );
    return texts.first.data!;
  }

  testWidgets('the admin sees 90 active, 10 pending and 1.000 € pending', (
    tester,
  ) async {
    await signIn(tester);

    expect(find.text('Temporada 2026/2027'), findsWidgets);
    expect(valueOf(tester, 'stat-active'), '90');
    expect(valueOf(tester, 'stat-pending'), '10');
    expect(valueOf(tester, 'stat-pending-amount'), '1.000,00 €');
    expect(valueOf(tester, 'stat-paid'), '4.500,00 €');
    expect(valueOf(tester, 'stat-invited'), '2');
    expect(
      find.text(
        '30 con renovación automática · 2 ventajas vigentes · 3 '
        'patrocinadores esta temporada',
      ),
      findsOneWidget,
    );
    expect(find.text('07/11/2026 · Asamblea de socios'), findsOneWidget);
  });

  testWidgets('members do not see the dashboard', (tester) async {
    await signIn(tester, admin: false);
    expect(find.byKey(const Key('admin-dashboard')), findsNothing);
  });

  testWidgets('shortcuts: new member opens the form, payments open pending', (
    tester,
  ) async {
    await signIn(tester);
    await tester.tap(find.byKey(const Key('shortcut-new-member')));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo socio'), findsWidgets);
    expect(find.byType(Dialog), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('shortcut-record-payment')));
    await tester.pumpAndSettle();
    expect(payments.clubQueries.last.status, PaymentStatus.pending);
  });

  testWidgets('without an active season it points to Temporadas', (
    tester,
  ) async {
    dashboard.dashboards[ideficAsAdmin.id] = const ClubDashboard();
    await signIn(tester);
    expect(find.text('No hay temporada activa'), findsOneWidget);
  });

  test('maps the dashboard row', () {
    final data = clubDashboardFromRow({
      'season_name': '2026/2027',
      'active_members': 90,
      'pending_members': 10,
      'not_renewed_members': 1,
      'invited_members': 2,
      'auto_renew_members': 30,
      'paid_cents': 450000,
      'pending_cents': 100000,
      'valid_perks': 2,
      'season_sponsors': 3,
      'latest_posts': [
        {
          'id': 'p',
          'title': 'Asamblea',
          'published_at': '2026-11-07T10:00:00+00:00',
        },
      ],
    });
    expect(data.pendingCents, 100000);
    expect(data.latestPosts.single.title, 'Asamblea');
  });
}
