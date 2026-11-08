import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:socios_idefic/domain/blog/post.dart';
import 'package:socios_idefic/presentation/app/socios_app.dart';

import '../support/fakes.dart';

// BDD: tasks/VS-026.md — Inicio.
void main() {
  late FakeBlogRepository blog;

  setUp(() => blog = FakeBlogRepository(now: DateTime(2026, 11, 9, 12)));

  Future<void> publish(String title, DateTime at, {String body = 'Texto'}) =>
      blog.savePost(
        clubId: idefic.id,
        title: title,
        body: body,
        publish: true,
        publishedAt: at,
      );

  Future<void> openHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      SociosApp(
        useCases: buildUseCases(
          auth: FakeAuthRepository(passwords: {'ana@example.com': 'pw'}),
          clubs: FakeClubRepository({
            'ana@example.com': [idefic],
          }),
          blog: blog,
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
  }

  testWidgets('Ana sees the 3 published posts, the newest first', (
    tester,
  ) async {
    await publish('Arranca la temporada', DateTime(2026, 10, 20));
    await publish('Asamblea de socios', DateTime(2026, 11, 8));
    await publish('Horarios', DateTime(2026, 11, 2));
    await blog.savePost(
      clubId: idefic.id,
      title: 'Cena de Navidad',
      body: 'Borrador',
      publish: false,
    );
    await publish('Nueva equipación', DateTime(2026, 11, 10)); // scheduled
    await openHome(tester);

    expect(find.byKey(const Key('open-card')), findsOneWidget);
    final titles = ['Asamblea de socios', 'Horarios', 'Arranca la temporada'];
    for (final title in titles) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('Cena de Navidad'), findsNothing);
    expect(find.text('Nueva equipación'), findsNothing);
    final ys = [for (final t in titles) tester.getTopLeft(find.text(t)).dy];
    expect(ys[0] < ys[1] && ys[1] < ys[2], isTrue);
  });

  testWidgets('a post opens with its paragraphs', (tester) async {
    await publish(
      'Asamblea de socios',
      DateTime(2026, 11, 8),
      body: 'Te convocamos el viernes.\n\nOrden del día: cuentas.',
    );
    await openHome(tester);

    expect(find.text('Te convocamos el viernes.'), findsOneWidget);
    await tester.tap(find.text('Asamblea de socios'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('post-detail-title')), findsOneWidget);
    expect(find.text('8 de noviembre de 2026'), findsOneWidget);
    expect(find.text('Orden del día: cuentas.'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('open-card')), findsOneWidget);
  });

  testWidgets('without news the home says what will appear', (tester) async {
    await openHome(tester);
    expect(find.byKey(const Key('feed-empty')), findsOneWidget);
    expect(find.text('Aquí verás las novedades de IDEFIC.'), findsOneWidget);
  });

  testWidgets('long feeds load more on demand', (tester) async {
    for (var i = 1; i <= 12; i++) {
      await publish('Noticia $i', DateTime(2026, 10, i));
    }
    await openHome(tester);
    expect(find.text('Noticia 12'), findsOneWidget);
    expect(find.text('Noticia 1'), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('feed-more')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('feed-more')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Noticia 1'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Noticia 1'), findsOneWidget);
  });

  testWidgets('a post that is not visible is not shown', (tester) async {
    await openHome(tester);
    GoRouterHelper.go(tester, '/club/post?id=missing');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('post-unavailable')), findsOneWidget);
  });

  test('excerpt and paragraphs', () {
    const post = Post(
      id: 'p',
      title: 't',
      body: 'Uno.\n\n  \n\nDos.',
      status: PostStatus.published,
    );
    expect(post.excerpt, 'Uno.');
    expect(post.paragraphs, ['Uno.', 'Dos.']);
  });
}

abstract final class GoRouterHelper {
  static void go(WidgetTester tester, String location) =>
      GoRouter.of(tester.element(find.byType(Scaffold).first)).go(location);
}
