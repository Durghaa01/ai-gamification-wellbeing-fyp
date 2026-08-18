import 'package:flutter/foundation.dart';

import '../models/user_info.dart';
import 'local_data_store.dart';

/// Service to manage user profile information without Firebase.
class UserInfoService {
  UserInfoService({LocalDataStore? store})
      : _store = store ?? LocalDataStore.instance;

  final LocalDataStore _store;

  Future<UserInfo?> getUserInfo(String userId) async {
    return _store.fetchUserInfo(userId);
  }

  Future<UserInfo> createUserInfo({
    required String userId,
    required String email,
    required String displayName,
  }) async {
    final info = UserInfo(
      userId: userId,
      email: email,
      displayName: displayName,
      createdAt: DateTime.now(),
    );
    _store.upsertUserInfo(info);
    if (kDebugMode) {
      debugPrint('Created local UserInfo for $userId');
    }
    return info;
  }

  Future<UserInfo> updateUserInfo(UserInfo userInfo) async {
    final updated = userInfo.copyWith(lastProfileUpdate: DateTime.now());
    _store.upsertUserInfo(updated);
    return updated;
  }

  Future<void> updateProfileFields(
    String userId,
    Map<String, dynamic> fields,
  ) async {
    final existing = await getUserInfo(userId);
    if (existing == null) {
      return;
    }
    final updated = existing.copyWith(
      phoneNumber: fields['phoneNumber'] as String? ?? existing.phoneNumber,
      bio: fields['bio'] as String? ?? existing.bio,
      profileImageUrl:
          fields['profileImageUrl'] as String? ?? existing.profileImageUrl,
      location: fields['location'] as String? ?? existing.location,
      dateOfBirth: fields['dateOfBirth'] as DateTime? ?? existing.dateOfBirth,
      gender: fields['gender'] as String? ?? existing.gender,
      preferences:
          (fields['preferences'] as Map<String, dynamic>?) ?? existing.preferences,
      lastProfileUpdate: DateTime.now(),
    );
    _store.upsertUserInfo(updated);
  }

  Future<void> updatePreferences(
    String userId,
    Map<String, dynamic> preferences,
  ) async {
    await updateProfileFields(userId, {'preferences': preferences});
  }

  Future<void> deleteUserInfo(String userId) async {
    _store.deleteUserInfo(userId);
  }

  Stream<UserInfo?> watchUserInfo(String userId) {
    return _store.watchUserInfo(userId);
  }

  Future<void> batchUpdateUserInfos(List<UserInfo> userInfos) async {
    for (final info in userInfos) {
      await updateUserInfo(info);
    }
  }

  Future<int> getProfileCompletenessScore(String userId) async {
    final info = await getUserInfo(userId);
    return info?.profileCompletenessPercentage ?? 0;
  }

  Future<bool> isProfileComplete(String userId) async {
    final score = await getProfileCompletenessScore(userId);
    return score >= 70;
  }
}
