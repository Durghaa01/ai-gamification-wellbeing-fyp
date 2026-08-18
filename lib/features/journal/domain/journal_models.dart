import 'dart:collection';

/// 🧾 Raw form payload collected before analytics (from journal page)
class JournalEntryInput {
  JournalEntryInput({
    required this.mood,
    required this.tags,
    required this.note,
    required this.userId,
  }) : assert(mood >= 1 && mood <= 5, 'mood must be between 1 and 5');

  /// 1 = very positive → 5 = very negative
  final int mood;

  /// 用户主动选择的“感受/上下文”标签（例如 Calm, Tired, Grateful）
  final List<String> tags;

  /// 自由文本日记（NLP 将从这里抽取 triggers）
  final String note;
  final String userId;
}

/// 🤖 Sentiment analysis result (from backend or fallback)
class SentimentInsight {
  const SentimentInsight({
    required this.label, // positive | neutral | negative
    required this.confidence, // 0..1
    this.scores,
    this.version = 'heuristic-v1',
  });

  final String label;
  final double confidence;
  final Map<String, double>? scores;
  final String version;
}

/// ⚠️ Risk analysis result — numeric + qualitative level
/// Uses Final FYP Definition: High≥70, Moderate≥35, Low<35
class RiskInsight {
  const RiskInsight({
    required this.level, // low | moderate | high
    required this.score, // 0..100
    required this.reason,
    this.triggers = const [], // 来自风控推理的触发词（保留以兼容）
    this.version = 'risk-engine-v1',
  });

  final String level;
  final double score;
  final String reason;
  final List<String> triggers;
  final String version;

  RiskInsight copyWith({
    String? level,
    double? score,
    String? reason,
    List<String>? triggers,
    String? version,
  }) {
    return RiskInsight(
      level: level ?? this.level,
      score: score ?? this.score,
      reason: reason ?? this.reason,
      triggers: triggers ?? this.triggers,
      version: version ?? this.version,
    );
  }
}

/// 🧠 Unified record combining form + sentiment + risk
class JournalEntry {
  JournalEntry({
    required DateTime createdAt,
    required this.mood,
    required List<String> tags,
    required this.note,
    required this.sentiment,
    required this.risk,
    List<String>? triggers, // ✨ 新增：从 note 里抽取的“事件/诱因”
  }) : createdAt = DateTime(createdAt.year, createdAt.month, createdAt.day),
       tags = List.unmodifiable(tags),
       triggers = List.unmodifiable(triggers ?? const []);

  /// 归一化到“天”的时间戳（确保仓库里每日一条）
  final DateTime createdAt;

  /// 1..5（1好 5差）
  final int mood;

  /// 用户选择的“感受”标签
  final List<String> tags;

  /// 自由文本
  final String note;

  /// 文本情绪
  final SentimentInsight sentiment;

  /// 风险结果
  final RiskInsight risk;

  /// ✨ 自动抽取的“事件/诱因”，供 Dashboard 的 Trigger 模块统计使用
  final List<String> triggers;

  /// 便捷属性：当天零点
  DateTime get normalizedDate => createdAt;

  /// ✅ 新增：用于本地存储等按“某一天”去重的 key
  String get dayKey {
    final d = createdAt;
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// Normalized "happiness index" for charts (higher = better)
  double get moodPercent {
    // 经验映射表（与你现有图表保持一致）
    const base = {1: 92.0, 2: 76.0, 3: 54.0, 4: 30.0, 5: 12.0};
    final baseValue = base[mood] ?? 50.0;

    // 文本情绪对可视化的轻微修正（保持之前的手感）
    final polarity = (sentiment.label == 'positive')
        ? 1
        : (sentiment.label == 'negative' ? -1 : 0);
    final sentimentShift = polarity * (sentiment.confidence - 0.5) * 20.0;

    final value = (baseValue + sentimentShift).clamp(0, 100);
    return value.toDouble();
  }

  bool occursOn(DateTime day) {
    final target = DateTime(day.year, day.month, day.day);
    return createdAt == target;
  }

  /// 便捷更新
  JournalEntry copyWith({
    DateTime? createdAt,
    int? mood,
    List<String>? tags,
    String? note,
    SentimentInsight? sentiment,
    RiskInsight? risk,
    List<String>? triggers,
  }) {
    return JournalEntry(
      createdAt: createdAt ?? this.createdAt,
      mood: mood ?? this.mood,
      tags: tags ?? this.tags,
      note: note ?? this.note,
      sentiment: sentiment ?? this.sentiment,
      risk: risk ?? this.risk,
      triggers: triggers ?? this.triggers,
    );
  }
}

/// 🗂️ In-memory repository for daily entries (1 per day)
class JournalRepository {
  JournalRepository._();

  static final JournalRepository instance = JournalRepository._();

  final List<JournalEntry> _entries = <JournalEntry>[];

  UnmodifiableListView<JournalEntry> get entries =>
      UnmodifiableListView(_entries);

  /// 保存/覆盖“当天”的记录
  void save(JournalEntry entry) {
    _entries.removeWhere((existing) => existing.occursOn(entry.createdAt));
    _entries.add(entry);
    _entries.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// 全量替换（用于 Demo 场景切换 & 真实数据切回）
  void replaceAll(Iterable<JournalEntry> entries) {
    _entries
      ..clear()
      ..addAll(
        entries.map(
          // 深度复制，确保 triggers 一并迁入（✨）
          (e) => JournalEntry(
            createdAt: e.createdAt,
            mood: e.mood,
            tags: e.tags,
            note: e.note,
            sentiment: e.sentiment,
            risk: e.risk,
            triggers: e.triggers,
          ),
        ),
      )
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  bool hasEntryOn(DateTime day) => _entries.any((entry) => entry.occursOn(day));

  JournalEntry? entryOn(DateTime day) {
    for (final entry in _entries.reversed) {
      if (entry.occursOn(day)) return entry;
    }
    return null;
  }

  /// Returns entries within the last [days] (inclusive)
  List<JournalEntry> lastDays(int days) {
    if (days <= 0) return const [];
    final now = DateTime.now();
    final lowerBound = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days - 1));
    return _entries
        .where((entry) => !entry.createdAt.isBefore(lowerBound))
        .toList();
  }

  /// ✨ 额外便捷：按触发事件归类统计（给 Dashboard 用）
  Map<String, List<JournalEntry>> groupByTrigger() {
    final map = <String, List<JournalEntry>>{};
    for (final e in _entries) {
      for (final t in e.triggers) {
        map.putIfAbsent(t, () => <JournalEntry>[]).add(e);
      }
    }
    return map;
    // 后续在 UI 里：平均心情 = list.map((e) => e.mood).average
  }
}
