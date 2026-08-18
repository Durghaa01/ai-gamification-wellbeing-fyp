class CompanionSessionSummary {
  CompanionSessionSummary({
    required this.id,
    required this.companionId,
    required this.companionName,
    this.title,
    this.summary,
    required this.createdAt,
    required this.lastMessageAt,
    required this.messageCount,
    this.tokenCount = 0,
    this.latencyMs = 0,
    this.archivedAt,
    this.isArchived = false,
  });

  final String id;
  final String companionId;
  final String companionName;
  final String? title;
  final String? summary;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
  final int messageCount;
  final int tokenCount;
  final int latencyMs;
  final DateTime? archivedAt;
  final bool isArchived;

  Map<String, dynamic> toMap() {
    return {
      'companionId': companionId,
      'companionName': companionName,
      'title': title,
      'summary': summary,
      'createdAt': createdAt,
      'lastMessageAt': lastMessageAt,
      'messageCount': messageCount,
      'tokenCount': tokenCount,
      'latencyMs': latencyMs,
      'archivedAt': archivedAt,
      'isArchived': isArchived,
    };
  }

  static CompanionSessionSummary fromMap(
    Map<String, dynamic> data, {
    required String id,
  }) {
    DateTime? _parse(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return null;
    }

    final createdAt = _parse(data['createdAt']) ?? DateTime.now();

    return CompanionSessionSummary(
      id: id,
      companionId: (data['companionId'] as String?) ?? 'unknown',
      companionName: (data['companionName'] as String?) ?? 'Companion',
      title: data['title'] as String?,
      summary: data['summary'] as String?,
      createdAt: createdAt,
      lastMessageAt: _parse(data['lastMessageAt']),
      messageCount: (data['messageCount'] as num?)?.toInt() ?? 0,
      tokenCount: (data['tokenCount'] as num?)?.toInt() ?? 0,
      latencyMs: (data['latencyMs'] as num?)?.toInt() ?? 0,
      archivedAt: _parse(data['archivedAt']),
      isArchived: data['isArchived'] as bool? ?? false,
    );
  }
}
