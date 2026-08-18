import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/local_data_repository.dart';
import '../domain/behavior_log.dart';
import '../../../core/providers/app_providers.dart';

// MOODDATA CLASS - Keep your existing structure
class MoodData {
  final String patientId;
  final String patientName;
  final String day;
  final String mood;
  final int riskScore;
  final double sentimentScore;
  final double? stressLevel;
  final double? activityScore;

  MoodData({
    required this.patientId,
    required this.patientName,
    required this.day,
    required this.mood,
    required this.riskScore,
    required this.sentimentScore,
    this.stressLevel,
    this.activityScore,
  });

  @override
  String toString() {
    return 'MoodData(patientId: $patientId, sentimentScore: $sentimentScore, day: $day, mood: $mood, score: $riskScore)';
  }

  factory MoodData.fromBehaviorLog(
    BehaviorLog log,
    String patientName,
    String patientId,
  ) {
    return MoodData(
      patientId: patientId,
      patientName: patientName,
      day: _formatDay(log.loggedAt),
      mood: _scoreToMood(log.riskScore),
      riskScore: _riskScoreToUiScore(log.riskScore),
      sentimentScore: log.riskScore * 10, // Convert 0-10 scale to 0-100 for UI
    );
  }

  static String _formatDay(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  static String _scoreToMood(double riskScore) {
    if (riskScore <= 3) return 'Happy';
    if (riskScore <= 5) return 'Calm';
    if (riskScore <= 7) return 'Anxious';
    return 'Stressed';
  }

  static int _riskScoreToUiScore(double riskScore) {
    return (5 - (riskScore / 2)).clamp(1, 5).toInt();
  }
}

// BEHAVIORAL DATA POINT FOR AI TRAINING - Your original class
class BehavioralDataPoint {
  final double behaviorScore;
  final double movingAverage7d;
  final double rateOfChange;
  final double volatility;
  final double trendDirection;
  final double? stressLevel;
  final double? activityScore;
  final String riskCategory;

  BehavioralDataPoint({
    required this.behaviorScore,
    required this.movingAverage7d,
    required this.rateOfChange,
    required this.volatility,
    required this.trendDirection,
    this.stressLevel,
    this.activityScore,
    required this.riskCategory,
  });

  List<double> toFeatureVector() {
    List<double> features = [
      behaviorScore,
      movingAverage7d,
      rateOfChange,
      volatility,
      trendDirection,
    ];

    if (stressLevel != null) features.add(stressLevel!);
    if (activityScore != null) features.add(activityScore!);

    return features;
  }
}

// BEHAVIORAL AI MODEL - Your original class
class BehavioralAIModel {
  final List<BehavioralDataPoint> trainingData = [];
  final Map<String, int> riskCategoryEncoding = {
    'Low': 0,
    'Moderate': 1,
    'High': 2,
  };

  List<double> featureWeights = [];
  double bias = 0.0;
  bool isTrained = false;

  void trainModel(List<BehavioralDataPoint> trainingData) {
    if (trainingData.length < 10) {
      print('Insufficient training data. Need at least 10 data points.');
      return;
    }

    this.trainingData.addAll(trainingData);
    _trainSimplifiedModel();
    isTrained = true;
    print('AI Model trained with ${trainingData.length} data points');
    print('Model weights: $featureWeights, Bias: $bias');
  }

  void _trainSimplifiedModel() {
    featureWeights = [0.4, 0.2, 0.15, 0.15, 0.1];
    bias = -0.1;
  }

  String predictRisk(BehavioralDataPoint dataPoint) {
    if (!isTrained) {
      return 'Moderate';
    }

    final features = dataPoint.toFeatureVector();
    double prediction = bias;

    for (int i = 0; i < min(features.length, featureWeights.length); i++) {
      prediction += features[i] * featureWeights[i];
    }

    double probability = 1.0 / (1.0 + exp(-prediction));

    if (probability > 0.7) return 'High';
    if (probability > 0.4) return 'Moderate';
    return 'Low';
  }

  String generateModelInsights() {
    if (trainingData.isEmpty) return "Insufficient data for insights";

    final highRiskCount = trainingData
        .where((d) => d.riskCategory == 'High')
        .length;
    final avgVolatility =
        trainingData.map((d) => d.volatility).reduce((a, b) => a + b) /
        trainingData.length;

    return "Model Analysis: ${highRiskCount} high-risk patterns detected. "
        "Average volatility: ${avgVolatility.toStringAsFixed(2)}. "
        "Model accuracy improves with more diverse behavioral data.";
  }
}

// SENTIMENT ANALYSIS RESULTS - Your original class
class SentimentAnalysisResult {
  final double riskScore;
  final String riskLevel;
  final String sentiment;
  final String summary;

  SentimentAnalysisResult({
    required this.riskScore,
    required this.riskLevel,
    required this.sentiment,
    required this.summary,
  });
}

// AI PREDICTION RESULT WITH ENHANCED FEATURES - Your original class
class AIPredictionResult {
  final double riskLevel;
  final double averageScore;
  final double stability;
  final double trend;
  final String mainInsight;
  final String trendAnalysis;
  final String recommendation;
  final String bestDay;
  final String bestDayMood;
  final double bestDayScore;
  final int lowMoodDays;
  final String dominantMood;
  final SentimentAnalysisResult? sentimentAnalysis;
  final BehavioralDataPoint? behavioralData;
  final String aiModelPrediction;
  final String modelConfidence;

  AIPredictionResult({
    required this.riskLevel,
    required this.averageScore,
    required this.stability,
    required this.trend,
    required this.mainInsight,
    required this.trendAnalysis,
    required this.recommendation,
    required this.bestDay,
    required this.bestDayMood,
    required this.bestDayScore,
    required this.lowMoodDays,
    required this.dominantMood,
    this.sentimentAnalysis,
    this.behavioralData,
    required this.aiModelPrediction,
    required this.modelConfidence,
  });

  factory AIPredictionResult.defaultValues() {
    return AIPredictionResult(
      riskLevel: 0.0,
      averageScore: 0.0,
      stability: 0.0,
      trend: 0.0,
      mainInsight: "Insufficient data for analysis",
      trendAnalysis: "Need more mood entries",
      recommendation: "Continue logging daily moods",
      bestDay: "N/A",
      bestDayMood: "N/A",
      bestDayScore: 0,
      lowMoodDays: 0,
      dominantMood: "N/A",
      aiModelPrediction: "Not trained",
      modelConfidence: "Low",
    );
  }

  double get riskScore100 => riskLevel * 100;

  String get riskCategory {
    final score = riskScore100;
    if (score >= 70) return "High";
    if (score >= 35) return "Moderate";
    return "Low";
  }
}

// ENHANCED AI PREDICTION ENGINE WITH MODEL TRAINING - Your original engine
class EnhancedAIPredictionEngine {
  final BehavioralAIModel _aiModel = BehavioralAIModel();
  final List<BehavioralDataPoint> _historicalData = [];

  AIPredictionResult analyzePatientData(List<MoodData> patientData) {
    if (patientData.isEmpty) {
      return AIPredictionResult.defaultValues();
    }

    final last7Days = _DataHelper.getLast7Days(patientData);

    // Calculate key metrics
    final double averageScore = _calculateAverageScore(last7Days);
    final double stability = _calculateMoodStability(last7Days);
    final double trend = _calculateTrend(last7Days);
    final int lowMoodDays = _countLowMoodDays(last7Days);
    final String dominantMood = _findDominantMood(last7Days);

    // Enhanced risk calculation
    double riskLevel = _calculateRiskLevel(
      averageScore,
      stability,
      trend,
      lowMoodDays,
    );

    // Generate sentiment analysis
    final sentimentAnalysis = _generateSentimentAnalysis(
      riskLevel * 100,
      averageScore,
      dominantMood,
      lowMoodDays,
    );

    // Create behavioral data point for AI model
    final behavioralData = _createBehavioralDataPoint(
      patientData,
      sentimentAnalysis.riskScore,
    );

    // Train AI model with historical data
    _updateAndTrainModel(behavioralData, sentimentAnalysis.riskLevel);

    // Get AI model prediction
    final aiPrediction = _aiModel.predictRisk(behavioralData);
    final modelConfidence = _calculateModelConfidence();

    // Generate insights
    final String mainInsight = _generateMainInsight(
      averageScore,
      trend,
      dominantMood,
    );
    final String trendAnalysis = _generateTrendAnalysis(trend, stability);
    final String recommendation = _generateRecommendation(
      riskLevel,
      dominantMood,
      lowMoodDays,
    );

    // Find best day
    final bestDay = _findBestDay(last7Days);

    return AIPredictionResult(
      riskLevel: riskLevel,
      averageScore: averageScore,
      stability: stability,
      trend: trend,
      mainInsight: mainInsight,
      trendAnalysis: trendAnalysis,
      recommendation: recommendation,
      bestDay: bestDay?.day ?? 'N/A',
      bestDayMood: bestDay?.mood ?? 'N/A',
      bestDayScore: bestDay?.sentimentScore ?? 0,
      lowMoodDays: lowMoodDays,
      dominantMood: dominantMood,
      sentimentAnalysis: sentimentAnalysis,
      behavioralData: behavioralData,
      aiModelPrediction: aiPrediction,
      modelConfidence: modelConfidence,
    );
  }

  BehavioralDataPoint _createBehavioralDataPoint(
    List<MoodData> patientData,
    double sentimentScore,
  ) {
    final last7Days = _DataHelper.getLast7Days(patientData);

    // Feature Engineering
    final behaviorScore = sentimentScore;
    final movingAverage7d = _calculateMovingAverage(last7Days);
    final rateOfChange = _calculateRateOfChange(last7Days);
    final volatility = _calculateVolatility(last7Days);
    final trendDirection = _calculateTrendDirection(last7Days);
    final riskCategory = _getRiskCategory(sentimentScore);

    return BehavioralDataPoint(
      behaviorScore: behaviorScore,
      movingAverage7d: movingAverage7d,
      rateOfChange: rateOfChange,
      volatility: volatility,
      trendDirection: trendDirection,
      riskCategory: riskCategory,
    );
  }

  void _updateAndTrainModel(
    BehavioralDataPoint newData,
    String currentRiskLevel,
  ) {
    _historicalData.add(newData);

    // Train model when we have sufficient data
    if (_historicalData.length >= 7) {
      _aiModel.trainModel(_historicalData);
    }
  }

  String _calculateModelConfidence() {
    if (_historicalData.length < 10) return "Low";
    if (_historicalData.length < 20) return "Medium";
    return "High";
  }

  // Feature engineering methods
  double _calculateMovingAverage(List<MoodData> data) {
    if (data.isEmpty) return 0.0;
    return data.map((d) => d.sentimentScore).reduce((a, b) => a + b) /
        data.length;
  }

  double _calculateRateOfChange(List<MoodData> data) {
    if (data.length < 2) return 0.0;
    final todayScore = data.last.sentimentScore;
    final yesterdayScore = data[data.length - 2].sentimentScore;
    return todayScore - yesterdayScore;
  }

  double _calculateVolatility(List<MoodData> data) {
    if (data.length < 2) return 0.0;
    final scores = data.map((d) => d.sentimentScore).toList();
    final mean = scores.reduce((a, b) => a + b) / scores.length;
    final variance =
        scores.map((s) => pow(s - mean, 2)).reduce((a, b) => a + b) /
        scores.length;
    return sqrt(variance);
  }

  double _calculateTrendDirection(List<MoodData> data) {
    if (data.length < 3) return 0.0;
    final recentTrend = _calculateTrend(data);
    return recentTrend > 0.1 ? 1.0 : (recentTrend < -0.1 ? -1.0 : 0.0);
  }

  String _getRiskCategory(double score) {
    if (score >= 70) return "High";
    if (score >= 35) return "Moderate";
    return "Low";
  }

  // Core analysis methods
  double _calculateAverageScore(List<MoodData> data) {
    if (data.isEmpty) return 0;
    return data.map((entry) => entry.sentimentScore).reduce((a, b) => a + b) /
        data.length;
  }

  double _calculateMoodStability(List<MoodData> data) {
    if (data.length < 2) return 1.0;
    final double average = _calculateAverageScore(data);
    final double variance =
        data
            .map((entry) => pow(entry.sentimentScore - average, 2))
            .reduce((a, b) => a + b) /
        data.length;
    return 1.0 - (sqrt(variance) / 50.0);
  }

  double _calculateTrend(List<MoodData> data) {
    if (data.length < 2) return 0.0;
    final List<double> scores = data.map((e) => e.sentimentScore).toList();
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    for (int i = 0; i < scores.length; i++) {
      sumX += i.toDouble();
      sumY += scores[i];
      sumXY += i * scores[i];
      sumX2 += i * i;
    }
    final double n = scores.length.toDouble();
    return (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
  }

  int _countLowMoodDays(List<MoodData> data) {
    return data.where((entry) => entry.sentimentScore <= 40).length;
  }

  String _findDominantMood(List<MoodData> data) {
    final moodCount = <String, int>{};
    for (final entry in data) {
      moodCount[entry.mood] = (moodCount[entry.mood] ?? 0) + 1;
    }
    return moodCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  double _calculateRiskLevel(
    double averageScore,
    double stability,
    double trend,
    int lowMoodDays,
  ) {
    double risk = 0.0;
    risk += (100 - averageScore) * 0.005;
    risk += (1.0 - stability) * 0.3;
    if (trend < -5)
      risk += 0.3;
    else if (trend < 0)
      risk += 0.15;
    risk += (lowMoodDays / 7) * 0.3;
    return risk.clamp(0.0, 1.0);
  }

  SentimentAnalysisResult _generateSentimentAnalysis(
    double riskScore100,
    double averageScore,
    String dominantMood,
    int lowMoodDays,
  ) {
    String riskLevel;
    if (riskScore100 >= 70) {
      riskLevel = "High";
    } else if (riskScore100 >= 35) {
      riskLevel = "Moderate";
    } else {
      riskLevel = "Low";
    }

    String sentiment;
    if (riskScore100 >= 70) {
      sentiment = "Concerning";
    } else if (riskScore100 >= 35) {
      sentiment = "Needs Attention";
    } else {
      sentiment = "Positive";
    }

    String summary;
    if (riskLevel == "High") {
      summary =
          "High risk detected. Immediate attention recommended. "
          "Dominant mood: $dominantMood, Low mood days: $lowMoodDays";
    } else if (riskLevel == "Moderate") {
      summary =
          "Moderate risk level. Monitor patterns closely. "
          "Average score: ${averageScore.toStringAsFixed(1)}/100";
    } else {
      summary =
          "Low risk level. Positive patterns observed. "
          "Dominant mood: $dominantMood is favorable";
    }

    return SentimentAnalysisResult(
      riskScore: riskScore100,
      riskLevel: riskLevel,
      sentiment: sentiment,
      summary: summary,
    );
  }

  String _generateMainInsight(
    double averageScore,
    double trend,
    String dominantMood,
  ) {
    if (averageScore >= 80.0) {
      return "Excellent behavioral consistency with predominantly $dominantMood states";
    } else if (averageScore >= 60.0) {
      return "Generally positive behavioral patterns with $dominantMood as most common";
    } else {
      return "Opportunities for behavioral improvement detected - focus on positive routines";
    }
  }

  String _generateTrendAnalysis(double trend, double stability) {
    String trendText = trend > 5
        ? "Strong improvement"
        : trend > 1
        ? "Gradual improvement"
        : trend < -5
        ? "Concerning decline"
        : trend < -1
        ? "Slight decline"
        : "Stable pattern";

    String stabilityText = stability > 0.8
        ? "Highly stable"
        : stability > 0.6
        ? "Moderately stable"
        : "Variable patterns";

    return "$trendText with $stabilityText behavioral patterns this week";
  }

  String _generateRecommendation(
    double riskLevel,
    String dominantMood,
    int lowMoodDays,
  ) {
    if (riskLevel < 0.3) {
      return "Continue current activities - they're working well! Consider sharing positive patterns.";
    } else if (riskLevel < 0.6) {
      return "Monitor behavioral patterns closely. Try stress-reduction techniques.";
    } else {
      return "Consider scheduling a check-in. Focus on self-care and support network.";
    }
  }

  MoodData? _findBestDay(List<MoodData> data) {
    if (data.isEmpty) return null;
    return data.reduce((a, b) => a.sentimentScore > b.sentimentScore ? a : b);
  }

  // Get AI model insights
  String getModelInsights() {
    return _aiModel.generateModelInsights();
  }
}

// HELPER METHODS - Your original helper class
class _DataHelper {
  static List<MoodData> getLast7Days(List<MoodData> data) {
    if (data.length <= 7) return data;
    return data.sublist(data.length - 7);
  }

  static List<MoodData> getPatientData(
    List<MoodData> allData,
    String patientId,
  ) {
    return allData.where((data) => data.patientId == patientId).toList();
  }
}

// SMART ALERT SYSTEM
class SmartAlertSystem {
  bool hasActiveAlerts = false;
  List<String> activeAlerts = [];

  void checkRiskThresholds(double riskLevel) {
    activeAlerts.clear();
    if (riskLevel > 0.7) {
      activeAlerts.add(
        "High risk pattern detected - consider immediate check-in",
      );
      hasActiveAlerts = true;
    } else if (riskLevel > 0.5) {
      activeAlerts.add("Moderate risk - monitor closely");
      hasActiveAlerts = true;
    } else {
      hasActiveAlerts = false;
    }
  }

  String getLatestAlert() {
    return activeAlerts.isNotEmpty ? activeAlerts.first : "No active alerts";
  }

  String getAlertDetails() {
    return activeAlerts.isNotEmpty
        ? activeAlerts.join('\n\n')
        : "No risk alerts at this time. All patterns appear normal.";
  }
}

// Provider for mood data
final moodDataProvider = StreamProvider.autoDispose
    .family<List<MoodData>, String>((ref, userId) async* {
      final repository = ref.watch(localDataRepositoryProvider);
      final behaviorLogsAsync = ref.watch(behaviorLogsProvider(userId));

      // Get user info for patient name
      final userInfo = await repository.fetchUserProfile(userId);
      final patientName = userInfo?.displayName ?? 'Patient';

      yield behaviorLogsAsync.when(
        data: (logs) => logs
            .map((log) => MoodData.fromBehaviorLog(log, patientName, userId))
            .toList(),
        loading: () => [],
        error: (error, stack) => [],
      );
    });

final aiPredictionProvider = StreamProvider.autoDispose
    .family<AIPredictionResult, String>((ref, userId) async* {
      final moodDataAsync = ref.watch(moodDataProvider(userId));

      yield moodDataAsync.when(
        data: (moodData) {
          if (moodData.isEmpty) return AIPredictionResult.defaultValues();

          final aiEngine = EnhancedAIPredictionEngine();
          return aiEngine.analyzePatientData(moodData);
        },
        loading: () => AIPredictionResult.defaultValues(),
        error: (error, stack) => AIPredictionResult.defaultValues(),
      );
    });
