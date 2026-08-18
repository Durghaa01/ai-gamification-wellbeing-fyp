import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_mhproj/models/user_info.dart';
import 'package:flutter_application_mhproj/services/user_info_service.dart';

import 'helpers/test_bootstrap.dart';

void main() {
  setUpAll(() async {
    await ensureTestStoreInitialized(reset: true);
  });

  group('UserInfo model validation', () {
    late UserInfo baseProfile;

    setUp(() {
      baseProfile = UserInfo(
        userId: 'user-1',
        email: 'user@example.com',
        displayName: 'Test User',
        createdAt: DateTime(2025, 1, 1),
      );
    });

    test('calculates profile completeness', () {
      final emptyCompleteness = baseProfile.profileCompletenessPercentage;
      expect(emptyCompleteness, 0);

      final fullProfile = baseProfile.copyWith(
        phoneNumber: '+1234567890',
        bio: 'Hello!',
        profileImageUrl: 'https://example.com/avatar.png',
        location: 'Singapore',
        dateOfBirth: DateTime(1995, 6, 15),
        gender: 'Female',
        preferences: const {'darkMode': true},
      );
      expect(fullProfile.profileCompletenessPercentage, 100);
    });

    test('validates phone numbers', () {
      expect(baseProfile.validatePhoneNumber(), isNull);
      expect(
        baseProfile.copyWith(phoneNumber: '123').validatePhoneNumber(),
        isNotNull,
      );
      expect(
        baseProfile.copyWith(phoneNumber: '+1 (555) 123-4567').validatePhoneNumber(),
        isNull,
      );
    });

    test('validates bio length', () {
      expect(baseProfile.validateBio(), isNull);
      expect(
        baseProfile.copyWith(bio: 'a' * 501).validateBio(),
        isNotNull,
      );
    });

    test('validates minimum age requirement', () {
      final tooYoung = baseProfile.copyWith(
        dateOfBirth: DateTime.now().subtract(const Duration(days: 365 * 10)),
      );
      expect(tooYoung.validateAge(), isNotNull);

      final adult = baseProfile.copyWith(
        dateOfBirth: DateTime.now().subtract(const Duration(days: 365 * 25)),
      );
      expect(adult.validateAge(), isNull);
    });
  });

  group('UserInfoService', () {
    late UserInfoService service;

    setUp(() async {
      await ensureTestStoreInitialized(reset: true);
      service = UserInfoService();
    });

    test('creates and retrieves user info', () async {
      final created = await service.createUserInfo(
        userId: 'user-1',
        email: 'user1@example.com',
        displayName: 'User One',
      );

      final fetched = await service.getUserInfo('user-1');
      expect(fetched?.userId, 'user-1');
      expect(fetched?.email, created.email);
    });

    test('updates user info fields and preferences', () async {
      await service.createUserInfo(
        userId: 'user-2',
        email: 'user2@example.com',
        displayName: 'User Two',
      );

      await service.updateProfileFields('user-2', {
        'bio': 'Updated bio',
        'location': 'Tokyo',
      });
      await service.updatePreferences('user-2', {'darkMode': true});

      final updated = await service.getUserInfo('user-2');
      expect(updated?.bio, 'Updated bio');
      expect(updated?.location, 'Tokyo');
      expect(updated?.preferences['darkMode'], true);
    });
  });
}
