// lib/services/journal_store.dart

/// 统一模型 & 存储接口（当前为内存实现；以后接 Hive 仅改这里即可）
class JournalEntry {
  final DateTime ts;
  final String? feeling; // 'Happy' | 'Neutral' | 'Sad' | 'Angry' | 'Anxious'
  final List<String> tags; // 任意标签
  final String text; // 日记正文

  JournalEntry({
    required this.ts,
    this.feeling,
    List<String>? tags,
    this.text = '',
  }) : tags = List.unmodifiable(tags ?? const []);

  Map<String, dynamic> toJson() => {
    'ts': ts.toIso8601String(),
    'feeling': feeling,
    'tags': tags,
    'text': text,
  };

  factory JournalEntry.fromJson(Map<String, dynamic> j) => JournalEntry(
    ts: DateTime.parse(j['ts'] as String),
    feeling: j['feeling'] as String?,
    tags: (j['tags'] as List?)?.cast<String>() ?? const [],
    text: (j['text'] as String?) ?? '',
  );
}

abstract class JournalEntryStore {
  Future<void> add(String key, JournalEntry e);
  Future<List<JournalEntry>> loadAll(String key);
}

/// 纯内存“数据库”。便于先跑通；App 退出数据会丢失。
class HiveJournalEntryStore implements JournalEntryStore {
  static Future<void> init() async {
    // 预留：以后接入 hive_flutter 时在这里初始化 Hive。
  }

  static final Map<String, List<JournalEntry>> _db = {};

  @override
  Future<void> add(String key, JournalEntry e) async {
    final list = _db.putIfAbsent(key, () => <JournalEntry>[]);
    list.add(e);
  }

  @override
  Future<List<JournalEntry>> loadAll(String key) async {
    return List.unmodifiable(_db[key] ?? const []);
  }
}
