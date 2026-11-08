import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/presentation/app/socios_app.dart';
import 'package:socios_idefic/presentation/club/image_picking.dart';
import 'package:socios_idefic/presentation/theme/club_theme.dart';

import '../support/fakes.dart';

// BDD: tasks/VS-004.md — Identidad visual del club.
void main() {
  late FakeAuthRepository auth;
  late FakeClubRepository clubs;

  setUp(() {
    auth = FakeAuthRepository(
      passwords: {
        'admin@example.com': 'pw',
        'ana@example.com': 'pw',
        'luis@example.com': 'pw',
      },
    );
    clubs = FakeClubRepository({
      'admin@example.com': [ideficAsAdmin],
      'ana@example.com': [idefic],
      'luis@example.com': [demo, idefic],
    });
  });

  Future<void> signInAs(WidgetTester tester, String email) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      SociosApp(
        useCases: buildUseCases(auth: auth, clubs: clubs),
        pickImage: () async => PickedImage(
          bytes: Uint8List.fromList([1, 2, 3]),
          contentType: 'image/png',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('login-email')), email);
    await tester.enterText(find.byKey(const Key('login-password')), 'pw');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
  }

  Color appBarColor(WidgetTester tester) {
    final context = tester.element(find.byType(AppBar).first);
    return Theme.of(context).appBarTheme.backgroundColor!;
  }

  testWidgets('the admin changes colors and logo and the club takes them', (
    tester,
  ) async {
    await signInAs(tester, 'admin@example.com');
    expect(appBarColor(tester), const Color(0xFF0B3D91));

    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    expect(find.text('Configuración del club'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('settings-primary')),
      '#b3261e',
    );
    await tester.pumpAndSettle();
    final previewHeader = tester.widget<Container>(
      find.byKey(const Key('settings-preview-header')),
    );
    expect(previewHeader.color, const Color(0xFFB3261E));

    await tester.tap(find.byKey(const Key('settings-upload-logo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-save')));
    await tester.pumpAndSettle();
    expect(find.text('Cambios guardados'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(appBarColor(tester), const Color(0xFFB3261E));
    final logo = tester.widget<Image>(find.byType(Image).first);
    expect(
      (logo.image as NetworkImage).url,
      'https://cdn.test/club-idefic/logo-1.png',
    );
    // Test HTTP always answers 400: the logo falls back to initials.
    expect(
      tester.takeException(),
      anyOf(isNull, isA<NetworkImageLoadException>()),
    );
  });

  testWidgets('switching club switches the identity', (tester) async {
    await signInAs(tester, 'luis@example.com');

    await tester.tap(find.byKey(const Key('club-DEMO')));
    await tester.pumpAndSettle();
    expect(appBarColor(tester), const Color(0xFFB3261E));

    await tester.tap(find.byKey(const Key('switch-club')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('club-IDEFIC')));
    await tester.pumpAndSettle();
    expect(appBarColor(tester), const Color(0xFF0B3D91));
  });

  testWidgets('a very light color keeps the header readable', (tester) async {
    await signInAs(tester, 'admin@example.com');
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('settings-primary')),
      '#FFF59D',
    );
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(
      find.byKey(const Key('settings-preview-title')),
    );
    expect(
      contrastRatio(title.style!.color!, const Color(0xFFFFF59D)),
      greaterThanOrEqualTo(BrandTokens.minContrast),
    );
  });

  testWidgets('an invalid color is explained and not saved', (tester) async {
    await signInAs(tester, 'admin@example.com');
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('settings-primary')), 'azul');
    await tester.tap(find.byKey(const Key('settings-save')));
    await tester.pumpAndSettle();

    expect(
      find.text('El color principal debe tener el formato #RRGGBB'),
      findsOneWidget,
    );
  });

  testWidgets('members do not see the settings', (tester) async {
    await signInAs(tester, 'ana@example.com');

    expect(find.byKey(const Key('open-settings')), findsNothing);
  });
}
