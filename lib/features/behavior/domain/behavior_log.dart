class BehaviorLog {
  BehaviorLog({
    required this.id,
    required this.loggedAt,
    required this.riskScore,
    required this.label,
    this.notes,
    String? dayKey,
  }) : dayKey = dayKey ?? _formatDayKey(loggedAt);

  final String id;
  final DateTime loggedAt;
  final double riskScore;
  final String label;
  final String? notes;
  final String dayKey;

  Map<String, dynamic> toMap() {
    return {
      'loggedAt': loggedAt,
      'dayKey': dayKey,
      'riskScore': riskScore,
      'label': label,
      if (notes != null) 'notes': notes,
    };
  }

  static BehaviorLog fromMap(Map<String, dynamic> data, {required String id}) {
    final loggedAtRaw = data['loggedAt'];
    final DateTime loggedAt;
    if (loggedAtRaw is DateTime) {
      loggedAt = loggedAtRaw;
    } else if (loggedAtRaw is String) {
      loggedAt = DateTime.tryParse(loggedAtRaw) ?? DateTime.now();
    } else if (loggedAtRaw is int) {
      loggedAt = DateTime.fromMillisecondsSinceEpoch(loggedAtRaw);
    } else {
      loggedAt = DateTime.now();
    }

    final riskScoreRaw = data['riskScore'];
    final riskScore = riskScoreRaw is num ? riskScoreRaw.toDouble() : 0.0;

    return BehaviorLog(
      id: id,
      loggedAt: loggedAt,
      riskScore: riskScore,
      label: (data['label'] as String?) ?? 'unknown',
      notes: data['notes'] as String?,
      dayKey: (data['dayKey'] as String?) ?? _formatDayKey(loggedAt),
    );
  }

  static String _formatDayKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
