import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/domain/profile/my_profile.dart';
import 'package:socios_idefic/presentation/app/socios_app.dart';
import 'package:socios_idefic/presentation/club/image_picking.dart';

import '../support/fakes.dart';

// BDD: tasks/VS-009.md — Mis datos.
void main() {
  late FakeAuthRepository auth;
  late FakeProfileRepository profiles;

  setUp(() {
    auth = FakeAuthRepository(passwords: {'ana@example.com': 'pw'});
    profiles = FakeProfileRepository({
      'ana@example.com': const MyProfile(
        email: 'ana@example.com',
        firstName: 'Ana',
        lastName: 'Pérez',
        phone: '600000000',
      ),
    });
  });

  Future<void> openMyData(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      SociosApp(
        useCases: buildUseCases(
          auth: auth,
          clubs: FakeClubRepository({
            'ana@example.com': [idefic],
          }),
          profile: profiles,
        ),
        pickImage: () async => PickedImage(
          bytes: Uint8List.fromList([1, 2, 3]),
          contentType: 'image/jpeg',
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
    await tester.tap(find.byKey(const Key('open-my-data')));
    await tester.pumpAndSettle();
  }

  testWidgets('the member edits her phone and photo', (tester) async {
    await openMyData(tester);
    expect(find.text('Mis datos'), findsOneWidget);
    expect(find.text('Socio nº 2'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('my-data-phone')),
      '611 22 33 44',
    );
    await tester.tap(find.byKey(const Key('my-data-change-photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('my-data-save')));
    await tester.pumpAndSettle();

    expect(find.text('Datos guardados'), findsOneWidget);
    final saved = profiles.profiles['ana@example.com']!;
    expect(saved.phone, '611223344');
    expect(saved.photoPath, 'user-ana@example.com/photo-1.jpg');
    final avatar = tester.widget<CircleAvatar>(
      find.byKey(const Key('my-data-photo')),
    );
    expect(
      (avatar.backgroundImage! as NetworkImage).url,
      'https://signed.test/user-ana@example.com/photo-1.jpg',
    );
    expect(
      tester.takeException(),
      anyOf(isNull, isA<NetworkImageLoadException>()),
    );
  });

  testWidgets('the email is read only', (tester) async {
    await openMyData(tester);

    expect(find.byKey(const Key('my-data-email')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(TextField),
        matching: find.text('ana@example.com'),
      ),
      findsNothing,
    );
    expect(
      find.text('Es tu acceso a la app y no se puede cambiar'),
      findsOneWidget,
    );
  });

  testWidgets('invalid data is explained and not saved', (tester) async {
    await openMyData(tester);

    await tester.enterText(find.byKey(const Key('my-data-last-name')), ' ');
    await tester.tap(find.byKey(const Key('my-data-save')));
    await tester.pumpAndSettle();

    expect(find.text('Escribe tus apellidos'), findsOneWidget);
    expect(profiles.profiles['ana@example.com']!.lastName, 'Pérez');
  });
}
