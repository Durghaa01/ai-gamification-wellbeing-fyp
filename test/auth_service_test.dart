import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_mhproj/models/models.dart';
import 'package:flutter_application_mhproj/services/auth_service.dart';

import 'helpers/test_bootstrap.dart';

void main() {
  group('AuthService', () {
    late AuthService authService;

    setUpAll(() async {
      await ensureTestStoreInitialized(reset: true);
    });

    setUp(() async {
      await ensureTestStoreInitialized(reset: true);
      authService = AuthService();
    });

    test('registers and signs in new user', () async {
      final user = await authService.registerWithEmail(
        email: 'new_user@example.com',
        password: 'secret123',
        displayName: 'New User',
        role: Role.user,
      );
      expect(user.email, 'new_user@example.com');

      await authService.signOut();
      final signedIn = await authService.signInWithEmail(
        email: 'new_user@example.com',
        password: 'secret123',
      );
      expect(signedIn.id, user.id);
    });

    test('rejects duplicate email', () async {
      await authService.registerWithEmail(
        email: 'duplicate@example.com',
        password: 'secret123',
        displayName: 'Original',
        role: Role.user,
      );

      await expectLater(
        authService.registerWithEmail(
          email: 'duplicate@example.com',
          password: 'secret456',
          displayName: 'Duplicate',
          role: Role.user,
        ),
        throwsA(isA<AuthException>()),
      );
    });
  });
}
