import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_mhproj/core/providers/app_providers.dart';
import 'package:flutter_application_mhproj/design_system/tokens/color_tokens.dart';
import 'package:flutter_application_mhproj/design_system/tokens/typography.dart';
import 'package:flutter_application_mhproj/ui/elements/responsive_page_scaffold.dart';
import 'package:flutter_application_mhproj/widgets/sync_status_widgets.dart';

import '../application/behavior_data_bridge.dart';
import '../application/behavior_providers.dart';
import '../../../services/behavior_data_service.dart';
import '../domain/behavior_log.dart';

class BehaviorTrackerPage extends ConsumerStatefulWidget {
  final Function(bool) onThemeChanged;
  final bool isDarkMode;
  final bool isCounselor;

  const BehaviorTrackerPage({
    required this.onThemeChanged,
    required this.isDarkMode,
    this.isCounselor = false,
  });

  @override
  ConsumerState<BehaviorTrackerPage> createState() =>
      _BehaviorTrackerPageState();
}

class _BehaviorTrackerPageState extends ConsumerState<BehaviorTrackerPage> {
  final EnhancedAIPredictionEngine _aiEngine = EnhancedAIPredictionEngine();
  final SmartAlertSystem _alertSystem = SmartAlertSystem();
  AIPredictionResult _prediction = AIPredictionResult.defaultValues();

  @override
  void initState() {
    super.initState();
    _setupDataListener();
  }

  void _setupDataListener() {
    final userAsync = ref.read(currentAppUserProvider);
    userAsync.whenData((user) {
      if (user != null) {
        ref.listen(aiPredictionProvider(user.id), (previous, next) {
          next.whenData((prediction) {
            if (mounted) {
              setState(() {
                _prediction = prediction;
                _alertSystem.checkRiskThresholds(_prediction.riskLevel);
              });
            }
          });
        });
      }
    });
  }

  List<MoodData> get _behavioralData {
    final userAsync = ref.read(currentAppUserProvider);
    final user = userAsync.value;
    if (user == null) return [];

    final moodDataAsync = ref.read(moodDataProvider(user.id));
    return moodDataAsync.value ?? [];
  }

  // Method to add real data to the system
  void _addNewDataPoint(double sentimentScore, String mood, int dayOffset) {
    final userAsync = ref.read(currentAppUserProvider);
    final user = userAsync.value;
    if (user == null) return;

    final log = BehaviorLog(
      id: 'manual-${DateTime.now().millisecondsSinceEpoch}',
      loggedAt: DateTime.now().subtract(Duration(days: dayOffset)),
      riskScore: sentimentScore / 10, // Convert back to 0-10 scale
      label: sentimentScore > 70
          ? 'high'
          : sentimentScore > 35
          ? 'moderate'
          : 'low',
      notes: 'Manual entry: $mood',
    );

    final behaviorService = BehaviorDataService();
    behaviorService.recordLog(userId: user.id, log: log);
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentAppUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isCounselor ? "AI Behavior Analysis" : "My Behavioral Health",
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [_buildDemoControls(), _buildNotificationIcons()],
      ),
      body: userAsync.when(
        data: (user) => user == null ? _buildNoUser() : _buildContent(user.id),
        loading: () => _buildLoading(),
        error: (error, stack) => _buildError(error),
      ),
    );
  }

  // ITS THIS ONE
  void _generateDefaultData(String userId) {
    final behaviorService = BehaviorDataService();
    final now = DateTime.now();

    // Generate sample data for the last 7 days
    for (int i = 6; i >= 0; i--) {
      final log = BehaviorLog(
        id: 'default-${DateTime.now().millisecondsSinceEpoch}-$i',
        loggedAt: now.subtract(Duration(days: i)),
        riskScore: [2.0, 3.5, 5.0, 7.5, 4.0, 3.0, 2.5][i], // Varied scores
        label: 'sample',
        notes: 'Sample data entry',
      );
      behaviorService.recordLog(userId: userId, log: log);
    }
  }

  Widget _buildContent(String userId) {
    final moodDataAsync = ref.watch(moodDataProvider(userId));
    final predictionAsync = ref.watch(aiPredictionProvider(userId));

    return moodDataAsync.when(
      data: (moodData) => predictionAsync.when(
        data: (prediction) => _buildWithData(moodData, prediction),
        loading: () => _buildLoading(),
        error: (error, stack) => _buildError(error),
      ),
      loading: () => _buildLoading(),
      error: (error, stack) => _buildError(error),
    );
  }

  Widget _buildWithData(
    List<MoodData> moodData,
    AIPredictionResult prediction,
  ) {
    // Update your prediction state
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _prediction = prediction;
          _alertSystem.checkRiskThresholds(_prediction.riskLevel);
        });
      });
    }

    // Your existing build method using real data
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDynamicHeader(context),
          SizedBox(height: 20),
          _buildDualChartsCard(context, moodData),
          SizedBox(height: 20),
          if (_prediction.sentimentAnalysis != null)
            _buildSentimentAnalysisCard(_prediction, context),
          SizedBox(height: 20),
          _buildAIModelInsightsCard(context),
          SizedBox(height: 20),
          _buildQuickStatsRow(context),
          SizedBox(height: 20),
          if (_alertSystem.hasActiveAlerts)
            _buildRiskAlertCard(_alertSystem, context),
          SizedBox(height: 20),
          widget.isCounselor
              ? _buildCounselorOverview(context)
              : _buildPatientOverview(context),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDemoControls() {
    return PopupMenuButton<String>(
      icon: Icon(Icons.data_usage, color: Colors.blue),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'low_risk',
          child: Text('Add Low Risk Data (Score: 20)'),
        ),
        PopupMenuItem(
          value: 'moderate_risk',
          child: Text('Add Moderate Risk Data (Score: 50)'),
        ),
        PopupMenuItem(
          value: 'high_risk',
          child: Text('Add High Risk Data (Score: 75)'),
        ),
      ],
      onSelected: (value) {
        double score = 0.0;
        String mood = '';

        switch (value) {
          case 'low_risk':
            score = 20.0;
            mood = 'Calm';
            break;
          case 'moderate_risk':
            score = 50.0;
            mood = 'Anxious';
            break;
          case 'high_risk':
            score = 75.0;
            mood = 'Stressed';
            break;
        }

        _addNewDataPoint(score, mood, _behavioralData.length);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added $mood data point (Score: $score)')),
        );
      },
    );
  }

  // Helper for dashed line legends
  Widget _buildDashedLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 2,
          child: CustomPaint(painter: _DashedLinePainter(color: color)),
        ),
        SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 10, color: Colors.grey[700])),
      ],
    );
  }

  Widget _buildNotificationIcons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            IconButton(
              icon: Icon(
                Icons.notifications,
                color: _alertSystem.hasActiveAlerts ? Colors.red : Colors.grey,
              ),
              tooltip: "Risk Alerts",
              onPressed: () {
                _showAlertDetails(context, _alertSystem);
              },
            ),
            if (_alertSystem.hasActiveAlerts)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  constraints: BoxConstraints(minWidth: 14, minHeight: 14),
                  child: Text(
                    '!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        IconButton(
          icon: Icon(Icons.phone_in_talk, color: Colors.green),
          tooltip: "Emergency Contact",
          onPressed: () {
            _triggerEmergencyProtocol(context);
          },
        ),
      ],
    );
  }

  Widget _buildDynamicHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.isCounselor
              ? "AI Behavioral Analysis Dashboard"
              : "Your Behavioral Health Insights",
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        SizedBox(height: 8),
        Text(
          "Real-time AI analysis with sentiment scoring and behavioral pattern detection",
          style: TextStyle(
            fontSize: 14,
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        SizedBox(height: 4),
        Text(
          "AI Model Confidence: ${_prediction.modelConfidence}",
          style: TextStyle(
            fontSize: 12,
            color: Colors.green,
            fontStyle: FontStyle.italic,
          ),
        ),
        SizedBox(height: 4),
        Text(
          "Note: AI is currently simulated. Real AI backend integration is in progress.",
          style: TextStyle(
            fontSize: 10,
            color: Colors.orange,
            fontStyle: FontStyle.italic,
          ),
        ),
        SizedBox(height: 4), //Added sample AI info
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.amber),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info, size: 12, color: Colors.amber),
              SizedBox(width: 4),
              Text(
                "Using Simulated AI | Connect to Python backend for real predictions",
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.amber.shade800,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDualChartsCard(BuildContext context, List<MoodData> moodData) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              "Behavioral Score & Risk Analysis",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 12),
            SizedBox(
              height: 380,
              child: LineChart(
                LineChartData(
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 &&
                              value.toInt() < moodData.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                moodData[value.toInt()].day,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            );
                          }
                          return Text('');
                        },
                        interval: 1,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 25,
                        getTitlesWidget: (value, meta) {
                          if ([0, 25, 50, 75, 100].contains(value.toInt())) {
                            return Text(
                              value.toInt().toString(),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }
                          return Text('');
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 25,
                        getTitlesWidget: (value, meta) {
                          if ([0, 25, 50, 75, 100].contains(value.toInt())) {
                            return Text(
                              '${value.toInt()}%',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }
                          return Text('');
                        },
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: 25,
                    verticalInterval: 1,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: theme.colorScheme.onSurface.withOpacity(0.1),
                      strokeWidth: 1,
                    ),
                    getDrawingVerticalLine: (value) => FlLine(
                      color: theme.colorScheme.onSurface.withOpacity(0.1),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(
                      color: theme.colorScheme.onSurface.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  minY: 0,
                  maxY: 100,
                  lineBarsData: [
                    // Behavioral Score Line (Green)
                    LineChartBarData(
                      spots: moodData.asMap().entries.map((entry) {
                        return FlSpot(
                          entry.key.toDouble(),
                          entry.value.sentimentScore,
                        );
                      }).toList(),
                      isCurved: true,
                      barWidth: 4,
                      color: Colors.green,
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.withOpacity(0.3),
                            Colors.green.withOpacity(0.1),
                          ],
                        ),
                      ),
                      dotData: FlDotData(show: true),
                    ),
                    // Risk Threshold Lines
                    LineChartBarData(
                      spots: [
                        FlSpot(0, 35), // Moderate threshold
                        FlSpot(moodData.length - 1, 35),
                      ],
                      isCurved: false,
                      barWidth: 2,
                      color: Colors.orange.withOpacity(0.6),
                      dashArray: [5, 5],
                      dotData: FlDotData(show: false),
                    ),
                    LineChartBarData(
                      spots: [
                        FlSpot(0, 70), // High threshold
                        FlSpot(moodData.length - 1, 70),
                      ],
                      isCurved: false,
                      barWidth: 2,
                      color: Colors.red.withOpacity(0.6),
                      dashArray: [5, 5],
                      dotData: FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 8),
            // Enhanced Legend
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildLegendItem(Colors.green, "Behavioral Score", theme),
                    _buildDashedLegendItem(Colors.orange, "Moderate Risk"),
                    _buildDashedLegendItem(Colors.red, "High Risk"),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  "Green: Actual Score | Dashed: Risk Thresholds",
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSentimentAnalysisCard(
    AIPredictionResult prediction,
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    final sentiment = prediction.sentimentAnalysis!;

    Color cardColor;
    Color textColor;
    IconData icon;

    switch (sentiment.riskLevel) {
      case "High":
        cardColor = Colors.red.shade50;
        textColor = Colors.red;
        icon = Icons.warning;
        break;
      case "Moderate":
        cardColor = Colors.orange.shade50;
        textColor = Colors.orange;
        icon = Icons.info;
        break;
      case "Low":
        cardColor = Colors.green.shade50;
        textColor = Colors.green;
        icon = Icons.check_circle;
        break;
      default:
        cardColor = theme.cardColor;
        textColor = theme.colorScheme.onSurface;
        icon = Icons.help;
    }

    // Adjust for dark mode
    if (theme.brightness == Brightness.dark) {
      switch (sentiment.riskLevel) {
        case "High":
          cardColor = Colors.red.withOpacity(0.1);
          break;
        case "Moderate":
          cardColor = Colors.orange.withOpacity(0.1);
          break;
        case "Low":
          cardColor = Colors.green.withOpacity(0.1);
          break;
      }
    }

    return Card(
      elevation: 4,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: textColor, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: textColor),
                SizedBox(width: 8),
                Text(
                  "Sentiment Analysis Results",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Risk Level: ${sentiment.riskLevel}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Text(
                        "Score: ${sentiment.riskScore.toStringAsFixed(0)}/100",
                        style: TextStyle(color: textColor),
                      ),
                      Text(
                        "Sentiment: ${sentiment.sentiment}",
                        style: TextStyle(color: textColor),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "AI Model Prediction: ${prediction.aiModelPrediction}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
                // Risk meter visual
                Container(
                  width: 80,
                  height: 80,
                  child: Stack(
                    children: [
                      CircularProgressIndicator(
                        value: sentiment.riskScore / 100,
                        backgroundColor: theme.colorScheme.onSurface
                            .withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(textColor),
                        strokeWidth: 8,
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "${sentiment.riskScore.toStringAsFixed(0)}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: textColor,
                              ),
                            ),
                            Text(
                              sentiment.riskLevel,
                              style: TextStyle(fontSize: 10, color: textColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              sentiment.summary,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIModelInsightsCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 4,
      color: isDark ? Colors.blue.withOpacity(0.1) : Colors.blue.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  "Simulated AI Model Insights",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              _aiEngine.getModelInsights(),
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Model Features: Behavioral Score, 7-day Average, Rate of Change, Volatility, Trend Direction",
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Note: Currently using simulated AI. Connect to Python backend for real AI predictions,",
              style: TextStyle(
                fontSize: 10,
                color: Colors.orange,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatsRow(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: isDark ? Colors.blue.withOpacity(0.1) : Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    "Avg Behavioral Score",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "${_prediction.averageScore.toStringAsFixed(1)}/100",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Based on ${_behavioralData.length} days",
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: _getRiskColor(_prediction.riskLevel),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    "AI Risk Level",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "${(_prediction.riskLevel * 100).toStringAsFixed(0)}%",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _prediction.riskCategory,
                    style: TextStyle(fontSize: 10, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: isDark
                ? Colors.green.withOpacity(0.1)
                : Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    "Model Confidence",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _prediction.modelConfidence,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "AI Prediction",
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  Text(
                    _prediction.aiModelPrediction,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getRiskColor(double riskLevel) {
    if (riskLevel > 0.7) return Colors.red;
    if (riskLevel > 0.4) return Colors.orange;
    return Colors.green;
  }

  Widget _buildLegendItem(Color color, String text, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 10,
            color: theme.colorScheme.onSurface.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildRiskAlertCard(
    SmartAlertSystem alertSystem,
    BuildContext context,
  ) {
    final theme = Theme.of(context);

    return Card(
      elevation: 4,
      color: theme.brightness == Brightness.dark
          ? Colors.orange.withOpacity(0.1)
          : Colors.orange.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "AI Risk Alert",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  Text(
                    alertSystem.getLatestAlert(),
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCounselorOverview(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "AI Analysis Report",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 12),
        Card(
          color: theme.cardColor,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAnalysisItem("Patient", "John Doe", theme),
                _buildAnalysisItem(
                  "Behavioral Stability",
                  "${(_prediction.stability * 100).toStringAsFixed(0)}%",
                  theme,
                ),
                _buildAnalysisItem(
                  "Trend Direction",
                  _prediction.trend > 0 ? "Improving" : "Declining",
                  theme,
                ),
                _buildAnalysisItem(
                  "Dominant Mood",
                  _prediction.dominantMood,
                  theme,
                ),
                _buildAnalysisItem(
                  "Low Score Days",
                  "${_prediction.lowMoodDays}/7 days",
                  theme,
                ),
                if (_prediction.sentimentAnalysis != null) ...[
                  SizedBox(height: 8),
                  _buildAnalysisItem(
                    "Sentiment Risk",
                    "${_prediction.sentimentAnalysis!.riskLevel} (${_prediction.sentimentAnalysis!.riskScore.toStringAsFixed(0)}/100)",
                    theme,
                  ),
                ],
                _buildAnalysisItem(
                  "AI Model Prediction",
                  _prediction.aiModelPrediction,
                  theme,
                ),
                SizedBox(height: 16),
                Text(
                  "AI Insights:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text("• ${_prediction.mainInsight}"),
                Text("• ${_prediction.trendAnalysis}"),
                Text("• ${_prediction.recommendation}"),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetailedInsightsPage(
                          prediction: _prediction,
                          isCounselor: true,
                        ),
                      ),
                    );
                  },
                  child: Text("View Detailed Analysis"),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPatientOverview(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Your AI Insights",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetailedInsightsPage(
                      prediction: _prediction,
                      isCounselor: false,
                    ),
                  ),
                );
              },
              child: Text("View Details"),
            ),
          ],
        ),
        SizedBox(height: 12),
        Card(
          color: theme.cardColor,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.star, color: Colors.amber),
                  title: Text("Best Day: ${_prediction.bestDay}"),
                  subtitle: Text(
                    "Score: ${_prediction.bestDayScore}/100 - Felt ${_prediction.bestDayMood}",
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.trending_up, color: Colors.green),
                  title: Text("Pattern Analysis"),
                  subtitle: Text(_prediction.trendAnalysis),
                ),
                ListTile(
                  leading: Icon(Icons.psychology, color: Colors.blue),
                  title: Text("AI Recommendation"),
                  subtitle: Text(_prediction.recommendation),
                ),
                ListTile(
                  leading: Icon(Icons.model_training, color: Colors.purple),
                  title: Text("AI Model Insight"),
                  subtitle: Text(
                    "Prediction: ${_prediction.aiModelPrediction} (${_prediction.modelConfidence} confidence)",
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysisItem(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            "$label: ",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  void _showAlertDetails(BuildContext context, SmartAlertSystem alertSystem) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text(
          "AI Risk Alerts",
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
        content: Text(
          alertSystem.getAlertDetails(),
          style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close"),
          ),
        ],
      ),
    );
  }

  void _triggerEmergencyProtocol(BuildContext context) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text(
          "Emergency Contact",
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
        content: Text(
          "Would you like to contact your emergency support person?",
          style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Calling emergency contact...")),
              );
            },
            child: Text("Call Now"),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(child: CircularProgressIndicator());
  }

  Widget _buildError(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, size: 64, color: Colors.red),
          SizedBox(height: 16),
          Text('Error loading behavior data'),
          Text(error.toString()),
        ],
      ),
    );
  }

  Widget _buildNoUser() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Please log in to view behavior data'),
        ],
      ),
    );
  }
}

class DetailedInsightsPage extends StatelessWidget {
  final AIPredictionResult? prediction;
  final bool isCounselor;

  const DetailedInsightsPage({this.prediction, required this.isCounselor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isCounselor ? "Detailed AI Analysis" : "Your Detailed Insights",
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: theme.cardColor,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "AI Behavioral Analysis Report",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 16),
                    if (prediction != null) ...[
                      Text(
                        "Comprehensive Analysis:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Risk Level: ${(prediction!.riskLevel * 100).toStringAsFixed(0)}%",
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.8),
                        ),
                      ),
                      Text(
                        "Average Score: ${prediction!.averageScore.toStringAsFixed(1)}/100",
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.8),
                        ),
                      ),
                      Text(
                        "Behavioral Stability: ${(prediction!.stability * 100).toStringAsFixed(0)}%",
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.8),
                        ),
                      ),
                      Text(
                        "Trend: ${prediction!.trend > 0 ? 'Improving' : 'Declining'}",
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.8),
                        ),
                      ),
                      if (prediction!.sentimentAnalysis != null) ...[
                        Text(
                          "Sentiment Risk: ${prediction!.sentimentAnalysis!.riskLevel}",
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.8),
                          ),
                        ),
                        Text(
                          "Sentiment Score: ${prediction!.sentimentAnalysis!.riskScore.toStringAsFixed(0)}/100",
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.8),
                          ),
                        ),
                      ],
                      Text(
                        "AI Model Prediction: ${prediction!.aiModelPrediction}",
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.8),
                        ),
                      ),
                      Text(
                        "Model Confidence: ${prediction!.modelConfidence}",
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.8),
                        ),
                      ),
                      SizedBox(height: 16),
                    ],
                    Text(
                      "Main Insight:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      prediction?.mainInsight ?? "No data available",
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      "Trend Analysis:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      prediction?.trendAnalysis ?? "No data available",
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      "AI Recommendation:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      prediction?.recommendation ?? "No data available",
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                    if (prediction?.sentimentAnalysis != null) ...[
                      SizedBox(height: 12),
                      Text(
                        "Sentiment Summary:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        prediction!.sentimentAnalysis!.summary,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Painter for dashed lines
class _DashedLinePainter extends CustomPainter {
  final Color color;

  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const double dashWidth = 3;
    const double dashSpace = 3;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
