import '../domain/journal_models.dart';

/// 🔍 Lightweight Risk Estimator
/// Used as an offline fallback when backend service is unavailable.
/// Calculates overall emotional risk score based on:
/// - Sentiment polarity & confidence
/// - Self-reported mood score (1–5)
/// - Tags (keywords)
/// - Mood-text mismatch
///
/// Output range: 0–100
/// Final risk level based on new FYP standard:
/// 🟢 Low < 35 | 🟠 Moderate 35–69 | 🔴 High ≥ 70
class JournalRiskEngine {
  static const Map<String, double> _tagWeights = {
    'anxious': 12,
    'stress': 10,
    'stressed': 10,
    'lonely': 10,
    'tired': 8,
    'sleep': 8,
    'relationship': 8,
    'work': 6,
    'study': 6,
    'health': 8,
    'burnout': 10,
  };

  static RiskInsight evaluate({
    required JournalEntryInput input,
    required SentimentInsight sentiment,
  }) {
    final isNegative = sentiment.label.toLowerCase() == 'negative';

    // 🧠 Base score from sentiment
    double baseScore = isNegative
        ? (40 + 40 * sentiment.confidence) // strong negative → high base risk
        : (15 - 10 * sentiment.confidence); // strong positive → lower base risk
    if (baseScore < 0) baseScore = 0;

    // 🧍 Mood influence (1=very happy → 5=very unhappy)
    final userAdjustment = (3 - input.mood) * 10.0;

    // 🏷️ Tag influence (weighted)
    double tagAdjustment = 0;
    final triggers = <String>[];
    for (final tag in input.tags) {
      final weight = _tagWeights[tag.toLowerCase()];
      if (weight != null) {
        tagAdjustment += weight;
        triggers.add(tag);
      } else {
        tagAdjustment += 4; // unknown tags: mild weight
      }
    }

    // ⚖️ Mismatch penalty (inconsistent mood vs text)
    double mismatchPenalty = 0;
    if (input.mood <= 2 && !isNegative && sentiment.confidence >= 0.8) {
      // user says happy but text looks neutral/positive — mild inconsistency
      mismatchPenalty += 6;
    }
    if (input.mood >= 4 && isNegative && sentiment.confidence >= 0.7) {
      // user rates unhappy but text clearly negative — strong mismatch
      mismatchPenalty += 18;
    }

    // 🧩 Combine all parts
    double total = baseScore + userAdjustment + tagAdjustment + mismatchPenalty;
    total = total.clamp(0, 100);

    // 🎯 Risk level (Final FYP version)
    String level = 'low';
    if (total >= 70) {
      level = 'high';
    } else if (total >= 35) {
      level = 'moderate';
    }

    // 📋 Explanation string (for UI / debugging)
    final reason = <String>[
      'sentiment=${sentiment.label} ${(sentiment.confidence * 100).round()}%',
      'selfScore=${input.mood}',
      if (input.tags.isNotEmpty) 'tags=${input.tags.join(",")}',
      if (mismatchPenalty > 0) 'mismatch',
    ];

    return RiskInsight(
      level: level,
      score: total,
      reason: reason.join(' | '),
      triggers: triggers,
    );
  }
}
