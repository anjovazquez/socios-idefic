import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/domain/blog/post.dart';
import 'package:socios_idefic/infrastructure/blog/supabase_blog_repository.dart';
import 'package:socios_idefic/presentation/app/socios_app.dart';
import 'package:socios_idefic/presentation/club/image_picking.dart';

import '../support/fakes.dart';
import '../support/navigation.dart';

// BDD: tasks/VS-025.md — Publicar en el blog.
void main() {
  late FakeBlogRepository blog;

  setUp(() => blog = FakeBlogRepository(now: DateTime(2026, 11, 9, 12)));

  Future<void> openNews(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      SociosApp(
        useCases: buildUseCases(
          auth: FakeAuthRepository(passwords: {'admin@example.com': 'pw'}),
          clubs: FakeClubRepository({
            'admin@example.com': [ideficAsAdmin],
          }),
          blog: blog,
        ),
        pickImage: () async => PickedImage(
          bytes: Uint8List.fromList(_png),
          contentType: 'image/png',
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
    await openAdminSection(tester, 'open-news-admin');
    await tester.pumpAndSettle();
  }

  Future<void> write(WidgetTester tester, String title, String body) async {
    await tester.tap(find.byKey(const Key('new-post')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('post-title')), title);
    await tester.enterText(find.byKey(const Key('post-body')), body);
  }

  testWidgets('publish «Asamblea de socios» with text and image', (
    tester,
  ) async {
    await openNews(tester);
    await write(tester, 'Asamblea de socios', 'El viernes a las 20:00.');
    await tester.tap(find.byKey(const Key('post-image-pick')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('post-image-preview')), findsOneWidget);
    await tester.tap(find.byKey(const Key('post-publish')));
    await tester.pumpAndSettle();

    expect(find.text('Noticia publicada'), findsOneWidget);
    expect(find.text('Publicada'), findsOneWidget);
    expect(find.text('09/11/2026 12:00'), findsOneWidget);
    final post = blog.posts[ideficAsAdmin.id]!.single;
    expect(post.imagePath, 'club-idefic/post-1.png');
    expect(post.status, PostStatus.published);
  });

  testWidgets('a draft is saved but not published', (tester) async {
    await openNews(tester);
    await write(tester, 'Cena de Navidad', 'Pendiente de fecha.');
    await tester.tap(find.byKey(const Key('post-save-draft')));
    await tester.pumpAndSettle();

    expect(find.text('Borrador guardado'), findsOneWidget);
    expect(find.text('Borrador'), findsOneWidget);
    expect(blog.posts[ideficAsAdmin.id]!.single.status, PostStatus.draft);
  });

  testWidgets('a post scheduled for tomorrow shows as scheduled', (
    tester,
  ) async {
    // The editor proposes tomorrow at 09:00 with the real clock.
    blog.now = DateTime.now();
    await openNews(tester);
    await write(tester, 'Nueva equipación', 'La presentamos mañana.');
    await tester.tap(find.text('Programar'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('post-schedule')), findsOneWidget);
    await tester.tap(find.byKey(const Key('post-publish')));
    await tester.pumpAndSettle();

    expect(find.text('Programada'), findsOneWidget);
    final post = blog.posts[ideficAsAdmin.id]!.single;
    expect(post.publishedAt!.isAfter(blog.now), isTrue);
  });

  testWidgets('the admin archives a post and validation errors show inline', (
    tester,
  ) async {
    await blog.savePost(
      clubId: ideficAsAdmin.id,
      title: 'Asamblea de socios',
      body: 'Texto',
      publish: true,
      publishedAt: DateTime(2026, 11, 1),
    );
    await openNews(tester);
    await tester.tap(find.byKey(const Key('post-menu-Asamblea de socios')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archivar (retirar)'));
    await tester.pumpAndSettle();
    expect(find.text('Archivada'), findsOneWidget);

    await write(tester, 'No', 'Texto');
    await tester.tap(find.byKey(const Key('post-publish')));
    await tester.pumpAndSettle();
    expect(
      find.text('El título debe tener entre 3 y 140 caracteres'),
      findsOneWidget,
    );
  });

  test('maps posts and errors', () {
    final post = postFromRow({
      'id': 'p1',
      'title': 'Asamblea',
      'body': 'Texto',
      'image_path': null,
      'status': 'published',
      'published_at': '2026-11-10T08:00:00+00:00',
      'visible': false,
    });
    expect(post.isScheduled, isTrue);
    expect(
      mapBlogError('22023', 'invalid title'),
      isA<InvalidPostFailure>().having(
        (f) => f.field,
        'field',
        PostField.title,
      ),
    );
    expect(mapBlogError('42501', 'x'), isA<BlogPermissionFailure>());
  });
}

// 1×1 transparent PNG.
const _png = [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];
