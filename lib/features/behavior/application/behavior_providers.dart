import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../domain/behavior_log.dart';

class BehaviorDashboardData {
  BehaviorDashboardData({
    required this.trend,
    required this.currentMood,
    required this.shortcuts,
  });

  final List<FlSpot> trend;
  final String currentMood;
  final List<BehaviorShortcut> shortcuts;

  factory BehaviorDashboardData.empty() {
    return BehaviorDashboardData(
      trend: List<FlSpot>.generate(7, (index) => FlSpot(index.toDouble(), 0)),
      currentMood: 'No data yet',
      shortcuts: const [
        BehaviorShortcut(icon: Icons.bar_chart, label: 'Weekly Report'),
        BehaviorShortcut(icon: Icons.psychology, label: 'AI Insights'),
      ],
    );
  }
}

class BehaviorShortcut {
  const BehaviorShortcut({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

final behaviorDashboardProvider = StreamProvider<BehaviorDashboardData>((
  ref,
) async* {
  final userId = await ref.watch(currentUserIdProvider.future);
  if (userId == null) {
    yield BehaviorDashboardData.empty();
    return;
  }

  final service = ref.watch(behaviorDataServiceProvider);

  yield* service
      .watchLogs(userId)
      .map(_mapLogsToDashboard)
      .handleError((_) => BehaviorDashboardData.empty());
});

BehaviorDashboardData _mapLogsToDashboard(List<BehaviorLog> logs) {
  if (logs.isEmpty) {
    return BehaviorDashboardData.empty();
  }

  final sorted = List<BehaviorLog>.from(logs)
    ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));

  final recent = sorted.length > 7 ? sorted.sublist(sorted.length - 7) : sorted;
  final trend = <FlSpot>[];
  for (var i = 0; i < recent.length; i++) {
    trend.add(FlSpot(i.toDouble(), recent[i].riskScore));
  }

  final latest = sorted.last;
  final label = switch (latest.label.toLowerCase()) {
    'very_high' => '⚠️ High Risk',
    'high' => '⚠️ High Risk',
    'moderate' => '🟡 Moderate',
    'low' => '🟢 Low',
    _ => '📊 Monitoring',
  };

  return BehaviorDashboardData(
    trend: trend,
    currentMood: label,
    shortcuts: const [
      BehaviorShortcut(icon: Icons.bar_chart, label: 'Weekly Report'),
      BehaviorShortcut(icon: Icons.psychology, label: 'AI Insights'),
    ],
  );
}
