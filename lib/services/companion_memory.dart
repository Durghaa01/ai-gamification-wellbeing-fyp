import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/assessment.dart';

class CompanionMemoryStore {
  CompanionMemoryStore({SharedPreferences? preferences})
    : _prefsFuture = preferences == null
          ? SharedPreferences.getInstance()
          : Future<SharedPreferences>.value(preferences);

  static const String _prefix = 'companion_memory_';

  final Future<SharedPreferences> _prefsFuture;

  Future<List<AssessmentMessage>> load(String companionId) async {
    final prefs = await _prefsFuture;
    final raw = prefs.getString('$_prefix$companionId');
    if (raw == null || raw.isEmpty) {
      return <AssessmentMessage>[];
    }
    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(_fromJson)
          .toList(growable: false);
    } catch (_) {
      return <AssessmentMessage>[];
    }
  }

  Future<void> save(
    String companionId,
    List<AssessmentMessage> messages,
  ) async {
    final prefs = await _prefsFuture;
    final encoded = jsonEncode(messages.map(_toJson).toList(growable: false));
    await prefs.setString('$_prefix$companionId', encoded);
  }

  Future<void> clear(String companionId) async {
    final prefs = await _prefsFuture;
    await prefs.remove('$_prefix$companionId');
  }

  AssessmentMessage _fromJson(Map<String, dynamic> json) {
    final String role = json['role'] as String? ?? 'assistant';
    return AssessmentMessage(
      role: _roleFromString(role),
      text: json['text'] as String? ?? '',
      ts: DateTime.tryParse(json['ts'] as String? ?? '') ?? DateTime.now(),
      meta: _decodeMeta(json['meta']),
    );
  }

  Map<String, dynamic> _toJson(AssessmentMessage message) {
    return <String, dynamic>{
      'role': message.role.name,
      'text': message.text,
      'ts': message.ts.toIso8601String(),
      if (message.meta != null) 'meta': message.meta,
    };
  }

  AgentRole _roleFromString(String value) {
    switch (value) {
      case 'user':
        return AgentRole.user;
      case 'system':
        return AgentRole.system;
      case 'assistant':
      default:
        return AgentRole.assistant;
    }
  }

  Map<String, dynamic>? _decodeMeta(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }
}
