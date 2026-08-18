import 'behavior_data_service.dart';

// Simulated AI risk prediction module (prototype)

class AIRiskPredictionService {
  static Future<String> predictRiskLevel(String userId) async {
    final history = await BehaviorDataService.fetchBehaviorHistory(userId);

    if (history.length < 3) {
      return "Low";
    }

    double avgMood =
        history.map((e) => e["mood_score"] as int).reduce((a, b) => a + b) /
        history.length;

    double avgSentiment =
        history
            .map((e) => e["sentiment_score"] as double)
            .reduce((a, b) => a + b) /
        history.length;

    // Simulated AI decision boundary
    if (avgMood <= 2 && avgSentiment < 0) {
      return "High";
    } else if (avgMood <= 3) {
      return "Medium";
    } else {
      return "Low";
    }
  }
}
