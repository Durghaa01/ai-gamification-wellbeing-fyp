import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

import '../domain/journal_models.dart';
import 'risk_engine.dart';

class JournalAnalysisService {
  JournalAnalysisService({
    http.Client? client,
    String? baseUrl,
    Duration? timeout,
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? _resolveBaseUrl(),
       _timeout = timeout ?? const Duration(seconds: 8);

  static const String _defaultBaseUrl = 'http://127.0.0.1:8000';

  // 运行时解析环境变量（flutter run --dart-define=API_BASE=...）
  static String _resolveBaseUrl() {
    const api = String.fromEnvironment('API_BASE');
    const alt = String.fromEnvironment('JOURNAL_API_BASE');
    if (api.isNotEmpty) return api;
    if (alt.isNotEmpty) return alt;
    return _defaultBaseUrl;
  }

  final http.Client _client;
  final String _baseUrl;
  final Duration _timeout;

  /* ====================================================================== */
  /* ===============  NEW: One-shot combined analysis API  ================= */
  /* ====================================================================== */

  /// 优先调用后端 `/analyze`，期望返回：
  /// {
  ///   "sentiment": {"label":"positive|neutral|negative","confidence":0..1},
  ///   "risk": {"level":"low|moderate|high","score":0..100,"reason":"...","triggers":[...]},
  ///   "triggers": ["exam","sleep",...]
  /// }
  ///
  /// 若后端不可达或缺字段：
  /// - sentiment：回退到 [_deriveSentiment]
  /// - risk：回退到 [JournalRiskEngine.evaluate]
  /// - triggers：回退到 [_extractTriggersHeuristic]
  ///
  /// 返回值为 Dart record：(SentimentInsight, RiskInsight, List<String>)
  Future<(SentimentInsight, RiskInsight, List<String>)>
  analyzeSentimentAndTriggers(
    String note, {
    JournalEntryInput? input, // 传入可让后端/风控更准确（含 mood/tags/userId）
  }) async {
    final trimmed = note.trim();

    // 先准备兜底
    final fallbackSent = trimmed.isEmpty
        ? const SentimentInsight(
            label: 'neutral',
            confidence: 0.5,
            version: 'client:heuristic',
          )
        : _deriveSentiment(trimmed);

    final fallbackRisk = JournalRiskEngine.evaluate(
      input:
          input ??
          JournalEntryInput(
            mood: 3,
            tags: const [],
            note: trimmed,
            userId: 'anonymous',
          ),
      sentiment: fallbackSent,
    ).copyWith(version: 'client:heuristic');

    final fallbackTriggers = _extractTriggersHeuristic(trimmed);

    // 尝试后端 /analyze
    try {
      final uri = Uri.parse('$_baseUrl/analyze');
      final body = <String, dynamic>{
        'text': trimmed,
        if (input != null) ...{
          'score': input.mood, // 和 computeRisk 约定一致
          'tags': input.tags,
          'userId': input.userId,
        },
      };

      final resp = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;

        // --- sentiment ---
        SentimentInsight sentiment;
        final s = data['sentiment'];
        if (s is Map<String, dynamic>) {
          final label = (s['label'] as String? ?? 'neutral').toLowerCase();
          final conf = _clampDouble(
            _pickNum(s, 'confidence', 0.65),
            min: 0,
            max: 1,
          );
          Map<String, double>? scores;
          if (s['scores'] is Map) {
            scores = (s['scores'] as Map).map(
              (k, v) => MapEntry(
                k.toString(),
                _clampDouble(v as num, min: 0, max: 1),
              ),
            );
          }
          final version = (s['version'] as String?) ?? 'remote';
          sentiment = SentimentInsight(
            label: label,
            confidence: conf,
            scores: scores,
            version: version,
          );
        } else {
          sentiment = fallbackSent;
        }

        // --- risk ---
        RiskInsight risk;
        final r = data['risk'];
        if (r is Map<String, dynamic>) {
          final numeric = _pickNum(
            r,
            'numeric',
            _pickNum(r, 'score', _pickNum(r, 'risk', _pickNum(r, 'value', 0))),
          ).toDouble();
          final score = _clampDouble(numeric, min: 0, max: 100);

          final rawLevel =
              (r['level'] as String? ??
                      (r['label'] as String?) ??
                      (r['risk_level'] as String?) ??
                      '')
                  .toLowerCase();
          final level = _normalizeLevel(rawLevel, score);

          final reason = (r['reason'] as String?) ?? '';
          final version = (r['version'] as String?) ?? 'remote';
          final triggers =
              (r['triggers'] as List?)
                  ?.map((e) => e.toString())
                  .toList(growable: false) ??
              const <String>[];

          risk = RiskInsight(
            level: level,
            score: score,
            reason: reason,
            triggers: triggers,
            version: version,
          );
        } else {
          // 若 /analyze 没给 risk，就用已有 computeRisk（能用到后端 /risk）
          if (input != null) {
            final riskFromApi = await computeRisk(
              input: input,
              sentiment: sentiment,
            );
            risk = riskFromApi;
          } else {
            risk = fallbackRisk;
          }
        }

        // --- triggers ---
        List<String> triggers;
        final t = data['triggers'];
        if (t is List) {
          triggers = t
              .map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList();
        } else if (risk.triggers.isNotEmpty) {
          triggers = risk.triggers;
        } else {
          triggers = fallbackTriggers;
        }

        return (sentiment, risk, triggers);
      }
    } catch (_) {
      // ignore: fallback below
    }

    // 完整兜底：单独 sentiment + 本地 risk + 启发式 triggers
    final sent = await analyzeSentiment(trimmed);
    final risk = await computeRisk(
      input:
          input ??
          JournalEntryInput(
            mood: 3,
            tags: const [],
            note: trimmed,
            userId: 'anonymous',
          ),
      sentiment: sent,
    );
    final triggers = _extractTriggersHeuristic(trimmed);
    return (sent, risk, triggers);
  }

  /// 只要触发词（本地启发式或未来改成 /triggers）
  Future<List<String>> extractTriggers(String note) async {
    // 若你后端实现了 /triggers，可改成调用后端
    // final resp = await _client.post(Uri.parse('$_baseUrl/triggers'), ...);
    return _extractTriggersHeuristic(note);
  }

  /* ====================================================================== */
  /* ======================  Existing: Sentiment only  ===================== */
  /* ====================================================================== */

  Future<SentimentInsight> analyzeSentiment(String note) async {
    final trimmed = note.trim();
    if (trimmed.isEmpty) {
      return const SentimentInsight(
        label: 'neutral',
        confidence: 0.5,
        version: 'client:heuristic',
      );
    }

    try {
      final uri = Uri.parse('$_baseUrl/sentiment');
      final resp = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': trimmed}),
          )
          .timeout(_timeout);

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final label = (data['label'] as String?)?.toLowerCase() ?? 'neutral';
        final confidence = _clampDouble(
          _pickNum(data, 'confidence', 0.65),
          min: 0,
          max: 1,
        );

        Map<String, double>? scores;
        final rawScores = data['scores'];
        if (rawScores is Map) {
          scores = rawScores.map(
            (k, v) =>
                MapEntry(k.toString(), _clampDouble(v as num, min: 0, max: 1)),
          );
        }
        final version = (data['version'] as String?) ?? 'remote';

        return SentimentInsight(
          label: label,
          confidence: confidence,
          scores: scores,
          version: version,
        );
      }
    } catch (_) {
      // ignore and fallback
    }

    return _deriveSentiment(trimmed);
  }

  /* ====================================================================== */
  /* ========================  Existing: Risk only  ======================== */
  /* ====================================================================== */

  Future<RiskInsight> computeRisk({
    required JournalEntryInput input,
    required SentimentInsight sentiment,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/risk');
      final payload = {
        'score': input.mood,
        'tags': input.tags,
        'text': input.note,
        'userId': input.userId,
      };

      final resp = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(_timeout);

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;

        final numeric = _pickNum(
          data,
          'numeric',
          _pickNum(
            data,
            'score',
            _pickNum(data, 'risk', _pickNum(data, 'value', 0.0)),
          ),
        ).toDouble();
        final score = _clampDouble(numeric, min: 0, max: 100);

        final rawLevel =
            (data['level'] as String? ??
                    (data['label'] as String?) ??
                    (data['risk_level'] as String?) ??
                    '')
                .toLowerCase();
        final level = _normalizeLevel(rawLevel, score);

        final reason = (data['reason'] as String?) ?? '';
        final version = (data['version'] as String?) ?? 'remote';
        final triggers =
            (data['triggers'] as List?)
                ?.map((e) => e.toString())
                .toList(growable: false) ??
            const <String>[];

        return RiskInsight(
          level: level,
          score: score,
          reason: reason,
          triggers: triggers,
          version: version,
        );
      }
    } catch (_) {
      // ignore and fallback
    }

    final local = JournalRiskEngine.evaluate(
      input: input,
      sentiment: sentiment,
    );
    return local.copyWith(version: 'client:heuristic');
  }

  /* ====================================================================== */
  /* ===========================  Existing: Alert  ========================= */
  /* ====================================================================== */

  Future<void> sendAlert({
    required JournalEntryInput input,
    required RiskInsight risk,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/alert');
      final body = {
        'userId': input.userId,
        'clinicId': 'clinic_demo_001',
        'input': {
          'score': input.mood,
          'tags': input.tags,
          'text': input.note,
          'userId': input.userId,
        },
        'risk': {
          'numeric': risk.score,
          'level': risk.level,
          'reason': risk.reason,
          'triggers': risk.triggers,
          'version': risk.version,
        },
      };
      final resp = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      // 告警失败不打断流程
      if (resp.statusCode != 200) {
        /* no-op */
      }
    } catch (_) {
      /* ignore */
    }
  }

  void dispose() => _client.close();

  /* ====================================================================== */
  /* ==========================  Local heuristics  ========================= */
  /* ====================================================================== */

  SentimentInsight _deriveSentiment(String note) {
    const positiveWords = [
      'happy',
      'grateful',
      'joy',
      'calm',
      'relaxed',
      'excited',
      'hopeful',
      'content',
    ];
    const negativeWords = [
      'sad',
      'angry',
      'anxious',
      'stressed',
      'worried',
      'afraid',
      'lonely',
      'tired',
      'guilty',
      'ashamed',
    ];

    final lower = note.toLowerCase();
    int positiveHits = 0;
    int negativeHits = 0;

    for (final w in positiveWords) {
      if (lower.contains(w)) positiveHits++;
    }
    for (final w in negativeWords) {
      if (lower.contains(w)) negativeHits++;
    }

    if (positiveHits == negativeHits) {
      return const SentimentInsight(
        label: 'neutral',
        confidence: 0.55,
        version: 'client:heuristic',
      );
    }

    final isPositive = positiveHits > negativeHits;
    final total = (positiveHits + negativeHits).clamp(1, 6);
    final confidence = _clampDouble(
      0.6 + (total - 1) * 0.06,
      min: 0.6,
      max: 0.9,
    );
    final label = isPositive ? 'positive' : 'negative';

    final scores = <String, double>{
      'positive': isPositive ? confidence : _clampDouble(1 - confidence),
      'negative': isPositive ? _clampDouble(1 - confidence) : confidence,
      'neutral': _clampDouble(1 - confidence / 1.5),
    };

    return SentimentInsight(
      label: label,
      confidence: confidence,
      scores: scores,
      version: 'client:heuristic',
    );
  }

  /// 朴素“事件触发词”抽取（可被后端替换）：
  /// - 统一小写，做简单分词和同义词映射
  /// - 返回去重后的关键词（ex: exam, deadline, sleep, work, family, relationship, finance, health, study, meeting, travel, weather, traffic, social, conflict, presentation, interview, breakup, illness ...）
  List<String> _extractTriggersHeuristic(String text) {
    final s = (text).toLowerCase();

    // 同义词 → 统一触发词
    final Map<String, List<String>> dict = {
      'exam': ['exam', 'examination', 'test', 'midterm', 'final', 'quiz'],
      'deadline': ['deadline', 'due', 'submission', 'submit', 'deliverable'],
      'sleep': [
        'sleep',
        'insomnia',
        'late night',
        'bedtime',
        'oversleep',
        'nap',
      ],
      'work': [
        'work',
        'office',
        'shift',
        'overtime',
        'boss',
        'coworker',
        'colleague',
      ],
      'study': ['study', 'assignment', 'homework', 'project', 'presentation'],
      'meeting': [
        'meeting',
        'call',
        'zoom',
        'interview',
        'presentation',
        'pitch',
      ],
      'relationship': [
        'relationship',
        'partner',
        'boyfriend',
        'girlfriend',
        'breakup',
        'argument',
      ],
      'family': [
        'family',
        'parents',
        'mum',
        'dad',
        'siblings',
        'brother',
        'sister',
      ],
      'finance': [
        'finance',
        'money',
        'bills',
        'rent',
        'salary',
        'tuition',
        'loan',
        'debt',
      ],
      'health': [
        'health',
        'sick',
        'ill',
        'fever',
        'flu',
        'injury',
        'hospital',
        'clinic',
      ],
      'traffic': ['traffic', 'jam', 'bus', 'train', 'commute', 'transport'],
      'weather': ['weather', 'rain', 'storm', 'hot', 'cold', 'heat'],
      'social': ['party', 'friends', 'gathering', 'social', 'event', 'club'],
      'conflict': ['conflict', 'fight', 'argue', 'argument', 'dispute'],
      'travel': ['travel', 'flight', 'airport', 'trip', 'vacation'],
      'diet': ['diet', 'food', 'eat', 'hungry', 'meal', 'fasting'],
      'exercise': ['exercise', 'gym', 'run', 'walk', 'yoga', 'workout'],
      'tech': ['phone', 'laptop', 'internet', 'wifi', 'app', 'computer', 'bug'],
      'household': ['cleaning', 'chores', 'laundry', 'cooking', 'grocery'],
      'loneliness': ['lonely', 'alone', 'isolated'],
      'bullying': ['bully', 'harass', 'toxic'],
      'grief': ['loss', 'passed away', 'funeral', 'grief'],
    };

    final hits = <String>{};
    for (final entry in dict.entries) {
      for (final term in entry.value) {
        if (s.contains(term)) {
          hits.add(entry.key);
          break;
        }
      }
    }

    return hits.toList(growable: false);
  }

  /* --------------------------- tiny utils --------------------------- */

  static double _clampDouble(num value, {double min = 0, double max = 1}) {
    final v = value.toDouble();
    if (v < min) return min;
    if (v > max) return max;
    return v;
  }

  static String _normalizeLevel(String raw, double score) {
    switch (raw) {
      case 'high':
      case 'hi':
      case 'danger':
      case 'severe':
        return 'high';
      case 'moderate':
      case 'med':
      case 'mid':
      case 'warning':
        return 'moderate';
      case 'low':
      case 'ok':
      case 'normal':
      case 'safe':
        return 'low';
      default:
        if (score >= 70) return 'high';
        if (score >= 35) return 'moderate';
        return 'low';
    }
  }

  static num _pickNum(Map<String, dynamic> m, String key, [num fallback = 0]) {
    final v = m[key];
    if (v is num) return v;
    if (v is String) {
      final parsed = num.tryParse(v);
      if (parsed != null) return parsed;
    }
    return fallback;
  }
}
