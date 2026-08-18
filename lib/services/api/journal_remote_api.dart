import '../../features/journal/domain/journal_models.dart';
import 'mindwell_api_client.dart';
import 'package:intl/intl.dart';

class JournalRemoteApi {
  JournalRemoteApi({required MindWellApiClient client}) : _client = client;

  final MindWellApiClient _client;

  Future<List<JournalEntry>> fetchEntries(
    String userId, {
    int limit = 14,
  }) async {
    final list = await _client.getJsonList(
      '/api/v1/journal/users/$userId/entries',
      query: <String, dynamic>{'limit': limit},
      headers: _authHeaders(userId),
    );
    return list
        .whereType<Map<String, dynamic>>()
        .map(_mapEntry)
        .toList(growable: false);
  }

  Future<JournalEntry> upsertEntry({
    required String userId,
    required int mood,
    required List<String> tags,
    required String note,
    DateTime? entryDate,
    List<String>? manualTriggers,
  }) async {
    final d = entryDate ?? DateTime.now();
    final dateOnly = DateFormat('yyyy-MM-dd').format(d);
    final payload = <String, dynamic>{
      'mood': mood,
      'tags': tags,
      'note': note,
      'entry_date': dateOnly,
      if (manualTriggers != null) 'manual_triggers': manualTriggers,
    };
    final json = await _client.postJson(
      '/api/v1/journal/users/$userId/entries',
      body: payload,
      headers: _authHeaders(userId),
    );
    return _mapEntry(json);
  }

  JournalEntry _mapEntry(Map<String, dynamic> data) {
    DateTime parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String && value.isNotEmpty) {
        return DateTime.parse(value).toLocal();
      }
      return DateTime.now();
    }

    SentimentInsight parseSentiment(Map<String, dynamic>? json) {
      if (json == null) {
        return const SentimentInsight(label: 'neutral', confidence: 0.5);
      }
      return SentimentInsight(
        label: json['label'] as String? ?? 'neutral',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
        scores: (json['scores'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        ),
        version: json['version'] as String? ?? 'heuristic-v1',
      );
    }

    RiskInsight parseRisk(Map<String, dynamic>? json) {
      if (json == null) {
        return const RiskInsight(level: 'low', score: 0, reason: 'N/A');
      }
      double score = (json['score'] as num?)?.toDouble() ?? 0;
      if (score <= 1.0) {
        // Backend currently returns 0–1; normalize to 0–100 for UI consistency
        score *= 100;
      }
      return RiskInsight(
        level: json['level'] as String? ?? 'low',
        score: score,
        reason: json['reason'] as String? ?? '',
        triggers: <String>[
          for (final dynamic trigger
              in (json['triggers'] as List?) ?? const <dynamic>[])
            if (trigger is String) trigger,
        ],
        version: json['version'] as String? ?? 'risk-engine-v1',
      );
    }

    final sentiment = parseSentiment(
      data['sentiment'] as Map<String, dynamic>?,
    );
    final risk = parseRisk(data['risk'] as Map<String, dynamic>?);

    return JournalEntry(
      createdAt: parseDate(data['entry_date'] ?? data['created_at']),
      mood: (data['mood'] as num?)?.toInt() ?? 3,
      tags: <String>[
        for (final dynamic tag in (data['tags'] as List?) ?? const <dynamic>[])
          if (tag is String) tag,
      ],
      note: data['note'] as String? ?? '',
      sentiment: sentiment,
      risk: risk,
      triggers: risk.triggers,
    );
  }

  Map<String, String> _authHeaders(String userId) {
    return <String, String>{'X-User-Id': userId};
  }
}
