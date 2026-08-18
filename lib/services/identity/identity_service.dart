import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class IdentityContext {
  IdentityContext({
    required this.visitorId,
    required this.subjectId,
    required this.isAuthenticated,
    this.userId,
  });

  final String visitorId;
  final String subjectId;
  final bool isAuthenticated;
  final String? userId;
}

class IdentityService {
  IdentityService({SharedPreferences? preferences})
    : _prefsFuture = preferences != null
          ? Future<SharedPreferences>.value(preferences)
          : SharedPreferences.getInstance();

  static const String _visitorKey = 'mindwell_visitor_id';

  final Future<SharedPreferences> _prefsFuture;

  Future<String> ensureVisitorId() async {
    final prefs = await _prefsFuture;
    final existing = prefs.getString(_visitorKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final generated = _generateVisitorId();
    await prefs.setString(_visitorKey, generated);
    return generated;
  }

  IdentityContext composeIdentity({String? userId, String? visitorId}) {
    final cleanVisitorId = (visitorId ?? '').trim();
    final cleanUserId = userId?.trim();
    final isAuthenticated = cleanUserId != null && cleanUserId.isNotEmpty;
    final subject = isAuthenticated
        ? 'user:${cleanUserId!.toLowerCase()}'
        : 'visitor:${cleanVisitorId.toLowerCase()}';
    return IdentityContext(
      visitorId: cleanVisitorId.isEmpty ? 'unknown' : cleanVisitorId,
      subjectId: subject,
      isAuthenticated: isAuthenticated,
      userId: isAuthenticated ? cleanUserId : null,
    );
  }

  String _generateVisitorId() {
    final random = Random.secure();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = List<int>.generate(6, (_) => random.nextInt(36));
    final buffer = StringBuffer(timestamp.toRadixString(36));
    for (final value in randomPart) {
      buffer.write(value.toRadixString(36));
    }
    return buffer.toString();
  }
}
