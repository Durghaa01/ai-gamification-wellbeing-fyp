import '../../features/companions/domain/companion_session.dart';
import '../../models/assessment.dart';
import 'mindwell_api_client.dart';

class CompanionRemoteApi {
  CompanionRemoteApi({required MindWellApiClient client}) : _client = client;

  final MindWellApiClient _client;

  Future<List<CompanionSessionSummary>> fetchSessions(
    String userId, {
    int limit = 10,
    int offset = 0,
    bool includeArchived = false,
  }) async {
    final state = includeArchived ? 'all' : 'active';
    final list = await _client.getJsonList(
      '/api/v1/companions/users/$userId/sessions',
      query: <String, dynamic>{
        'limit': limit,
        'offset': offset,
        'state': state,
      },
      headers: _userHeaders(userId),
    );
    return list
        .whereType<Map<String, dynamic>>()
        .map(_mapSummary)
        .toList(growable: false);
  }

  Future<CompanionSessionSummary> recordMessage({
    required String userId,
    required String sessionId,
    required String companionId,
    required String companionName,
    required AssessmentMessage message,
    String? sessionSummary,
  }) async {
    final payload = <String, dynamic>{
      'companion_id': companionId,
      'companion_name': companionName,
      'role': message.role.name,
      'content': message.text,
      'metadata': message.meta ?? const <String, dynamic>{},
    };
    final messageId = message.meta?['messageId'];
    if (messageId != null) {
      payload['message_id'] = messageId;
    }
    final tokenCount = (message.meta?['tokenCount'] as num?)?.toInt();
    if (tokenCount != null) {
      payload['token_count'] = tokenCount;
    }
    final latencyMs = (message.meta?['latencyMs'] as num?)?.toInt();
    if (latencyMs != null) {
      payload['latency_ms'] = latencyMs;
    }
    if (sessionSummary != null && sessionSummary.isNotEmpty) {
      payload['session_summary'] = sessionSummary;
    }
    final json = await _client.postJson(
      '/api/v1/companions/users/$userId/sessions/$sessionId/messages',
      body: payload,
      headers: _userHeaders(userId),
    );
    final session = json['session'] as Map<String, dynamic>? ?? const {};
    return _mapSummary(session);
  }

  Future<List<AssessmentMessage>> fetchSessionMessages(
    String userId,
    String sessionId, {
    int limit = 50,
    DateTime? before,
    DateTime? after,
  }) async {
    final query = <String, dynamic>{'limit': limit};
    if (before != null) {
      query['before'] = before.toUtc().toIso8601String();
    }
    if (after != null) {
      query['after'] = after.toUtc().toIso8601String();
    }
    final json = await _client.getJson(
      '/api/v1/companions/sessions/$sessionId',
      query: query,
      headers: _userHeaders(userId),
    );
    final messages = (json['messages'] as List?)
        ?.whereType<Map<String, dynamic>>()
        .map(_mapMessage)
        .toList(growable: false);
    return messages ?? const <AssessmentMessage>[];
  }

  Future<CompanionSessionSummary> updateSession({
    required String userId,
    required String sessionId,
    String? title,
    bool? isArchived,
    String? summary,
    int? tokenCount,
    int? latencyMs,
  }) async {
    final payload = <String, dynamic>{
      if (title != null) 'title': title,
      if (isArchived != null) 'is_archived': isArchived,
      if (summary != null) 'summary': summary,
      if (tokenCount != null) 'token_count': tokenCount,
      if (latencyMs != null) 'latency_ms': latencyMs,
    };
    final json = await _client.patchJson(
      '/api/v1/companions/sessions/$sessionId',
      body: payload,
      headers: _userHeaders(userId),
    );
    return _mapSummary(json);
  }

  Future<void> deleteSession(String userId, String sessionId) {
    return _client.delete(
      '/api/v1/companions/sessions/$sessionId',
      headers: _userHeaders(userId),
    );
  }

  CompanionSessionSummary _mapSummary(Map<String, dynamic> data) {
    DateTime? parse(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value)?.toLocal();
      }
      return null;
    }

    return CompanionSessionSummary(
      id: data['id'] as String? ?? '',
      companionId: data['companion_id'] as String? ?? 'unknown',
      companionName: data['companion_name'] as String? ?? 'Companion',
      title: data['title'] as String?,
      summary: data['summary'] as String?,
      createdAt: parse(data['created_at']) ?? DateTime.now(),
      lastMessageAt: parse(data['last_message_at']),
      messageCount: (data['message_count'] as num?)?.toInt() ?? 0,
      tokenCount: (data['token_count'] as num?)?.toInt() ?? 0,
      latencyMs: (data['latency_ms'] as num?)?.toInt() ?? 0,
      archivedAt: parse(data['archived_at']),
      isArchived: data['is_archived'] as bool? ?? false,
    );
  }

  AssessmentMessage _mapMessage(Map<String, dynamic> data) {
    final role = switch ((data['role'] as String?)?.toLowerCase()) {
      'assistant' => AgentRole.assistant,
      'system' => AgentRole.system,
      _ => AgentRole.user,
    };
    final createdAt =
        DateTime.tryParse(data['created_at'] as String? ?? '') ??
        DateTime.now();
    final meta = Map<String, dynamic>.from(
      (data['meta_data'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    meta['messageId'] = data['id']?.toString();
    meta['tokenCount'] = (data['token_count'] as num?)?.toInt();
    meta['latencyMs'] = (data['latency_ms'] as num?)?.toInt();
    return AssessmentMessage(
      role: role,
      text: data['content'] as String? ?? '',
      ts: createdAt.toLocal(),
      meta: meta,
    );
  }

  Map<String, String> _userHeaders(String userId) {
    return <String, String>{'X-User-Id': userId};
  }
}
