import '../features/behavior/domain/behavior_log.dart';
import 'local_data_store.dart';

class BehaviorDataService {
  BehaviorDataService({LocalDataStore? store})
    : _store = store ?? LocalDataStore.instance;

  final LocalDataStore _store;

  Stream<List<BehaviorLog>> watchLogs(String userId) {
    return _store.watchBehaviorLogs(userId);
  }

  Future<List<BehaviorLog>> fetchLogs(String userId) {
    return _store.fetchBehaviorLogs(userId);
  }

  Future<void> recordLog({
    required String userId,
    required BehaviorLog log,
  }) async {
    _store.addBehaviorLog(userId, log);
  }

  // Simulated MongoDB-style collection
  static final List<Map<String, dynamic>> _behaviorCollection = [];

  static Future<void> saveBehaviorData({
    required String userId,
    required int moodScore,
    required double sentimentScore,
    required int stressLevel,
  }) async {
    final data = {
      "user_id": userId,
      "mood_score": moodScore,
      "sentiment_score": sentimentScore,
      "stress_level": stressLevel,
      "timestamp": DateTime.now().toIso8601String(),
    };

    _behaviorCollection.add(data);

    // Demo visibility
    print("Saved behavior data to DB: $data");
  }

  static Future<List<Map<String, dynamic>>> fetchBehaviorHistory(
    String userId,
  ) async {
    return _behaviorCollection
        .where((item) => item["user_id"] == userId)
        .toList();
  }
}
