import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/application/auth/sign_in_with_password.dart';
import 'package:socios_idefic/application/auth/sign_out.dart';
import 'package:socios_idefic/domain/auth/auth_failures.dart';

import '../support/fakes.dart';

void main() {
  group('SignInWithPassword', () {
    test('normalizes the email before signing in', () async {
      final auth = FakeAuthRepository(passwords: {'ana@example.com': 'pw'});

      final user = await SignInWithPassword(auth)(
        email: '  Ana@Example.com ',
        password: 'pw',
      );

      expect(auth.lastEmail, 'ana@example.com');
      expect(user.email, 'ana@example.com');
    });

    test('rejects empty credentials without calling the server', () {
      final auth = FakeAuthRepository();

      expect(
        () => SignInWithPassword(auth)(email: ' ', password: ''),
        throwsA(isA<MissingCredentialsFailure>()),
      );
      expect(auth.lastEmail, isNull);
    });

    test('propagates invalid credentials', () {
      final auth = FakeAuthRepository(passwords: {'ana@example.com': 'pw'});

      expect(
        () => SignInWithPassword(auth)(email: 'ana@example.com', password: 'x'),
        throwsA(isA<InvalidCredentialsFailure>()),
      );
    });
  });

  test('SignOut forgets the active club and ends the session', () async {
    final auth = FakeAuthRepository(passwords: {'ana@example.com': 'pw'});
    await auth.signInWithPassword(email: 'ana@example.com', password: 'pw');
    final store = InMemoryActiveClubStore()..value = idefic.id;

    await SignOut(auth, store)();

    expect(store.value, isNull);
    expect(auth.currentUser, isNull);
  });
}
