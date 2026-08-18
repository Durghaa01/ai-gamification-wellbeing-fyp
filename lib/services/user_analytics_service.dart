import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../features/journal/domain/journal_models.dart';
import '../features/appointments/domain/appointment.dart';
import '../features/behavior/domain/behavior_log.dart';
import '../features/companions/domain/companion_session.dart';
import '../models/user_analytics.dart';

/// Service to extract and aggregate analytics from all feature modules
class UserAnalyticsService {
  /// Extract journal analytics from JournalRepository
  static JournalAnalytics extractJournalAnalytics(Iterable<JournalEntry> entries) {
    final journalEntries = entries.toList();

    if (journalEntries.isEmpty) {
      return JournalAnalytics.empty();
    }

    // Calculate mood distribution
    final moodMap = <String, int>{};
    double totalMood = 0;
    for (final entry in journalEntries) {
      totalMood += entry.mood;
      final moodLabel = _getMoodLabel(entry.mood);
      moodMap[moodLabel] = (moodMap[moodLabel] ?? 0) + 1;
    }

    final averageMoodScore = (totalMood / journalEntries.length) * 20; // Convert 1-5 to 0-100

    // Get last entry date
    final lastEntryDate = journalEntries.isNotEmpty ? journalEntries.last.createdAt : null;

    // Calculate entries this week
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final thisWeekEntries = journalEntries
        .where((e) => e.createdAt.isAfter(weekAgo) || e.createdAt.isAtSameMomentAs(weekAgo))
        .length;

    // Determine mood trend based on last 7 entries
    final trend = _calculateMoodTrend(
      journalEntries.length > 1
          ? journalEntries.sublist(journalEntries.length - 7)
          : journalEntries,
    );

    if (kDebugMode) {
      debugPrint(
        'JournalAnalytics: ${journalEntries.length} entries, '
        'avg mood: ${averageMoodScore.toStringAsFixed(1)}, '
        'trend: $trend',
      );
    }

    return JournalAnalytics(
      entryCount: journalEntries.length,
      lastEntryDate: lastEntryDate,
      moodTrend: trend,
      moodDistribution: moodMap,
      averageMoodScore: averageMoodScore,
      thisWeekEntries: thisWeekEntries,
    );
  }

  /// Extract behavior tracker analytics
  /// Note: This is a placeholder - real implementation would query actual behavior data
  static BehaviorAnalytics extractBehaviorAnalytics(
    Iterable<BehaviorLog> behaviorEntries,
  ) {
    final logs = behaviorEntries.toList();
    if (logs.isEmpty) {
      return BehaviorAnalytics.empty();
    }

    logs.sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    final now = DateTime.now();

    final uniqueDays = <DateTime>{};
    int thisMonthCount = 0;
    final moodOccurrences = <String, int>{};

    for (final log in logs) {
      final day = DateTime(log.loggedAt.year, log.loggedAt.month, log.loggedAt.day);
      uniqueDays.add(day);
      if (log.loggedAt.month == now.month && log.loggedAt.year == now.year) {
        thisMonthCount++;
      }
      moodOccurrences[log.label] = (moodOccurrences[log.label] ?? 0) + 1;
    }

    final lastActivity = logs.last.loggedAt;

    // Consistency: percentage of days with activity in last two weeks
    final windowStart = now.subtract(const Duration(days: 13));
    final recentDays = uniqueDays.where((day) => !day.isBefore(windowStart)).length;
    final consistencyScore = ((recentDays / 14) * 100).clamp(0, 100).round();

    // Current streak counting consecutive days ending today
    int currentStreak = 0;
    DateTime cursor = DateTime(now.year, now.month, now.day);
    final daySet = uniqueDays
        .map((day) => DateTime(day.year, day.month, day.day))
        .toSet();
    while (daySet.contains(cursor)) {
      currentStreak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    final mostLoggedActivity = moodOccurrences.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;

    if (kDebugMode) {
      debugPrint(
        'BehaviorAnalytics: ${logs.length} logs, consistency $consistencyScore%, streak $currentStreak days',
      );
    }

    return BehaviorAnalytics(
      activityCount: logs.length,
      lastActivityDate: lastActivity,
      consistencyScore: consistencyScore,
      thisMonthCount: thisMonthCount,
      currentStreak: currentStreak,
      mostLoggedActivity: mostLoggedActivity,
    );
  }

  /// Extract appointment analytics
  static AppointmentAnalytics extractAppointmentAnalytics(
    Iterable<Appointment> appointments,
  ) {
    final items = appointments.toList();
    if (items.isEmpty) {
      return AppointmentAnalytics.empty();
    }

    final now = DateTime.now();
    int completed = 0;
    int upcoming = 0;
    DateTime? nextDate;

    DateTime _combine(DateTime date, TimeOfDay time) {
      return DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    }

    for (final appointment in items) {
      final dateTime = _combine(appointment.date, appointment.time);
      if (dateTime.isBefore(now)) {
        completed++;
      } else {
        upcoming++;
        if (nextDate == null || dateTime.isBefore(nextDate!)) {
          nextDate = dateTime;
        }
      }
    }

    if (kDebugMode) {
      debugPrint(
        'AppointmentAnalytics: total ${items.length}, completed $completed, upcoming $upcoming',
      );
    }

    return AppointmentAnalytics(
      totalCount: items.length,
      completedCount: completed,
      upcomingCount: upcoming,
      nextAppointmentDate: nextDate,
      averageRating: 0.0,
    );
  }

  /// Extract companion chat analytics
  /// Note: This is a placeholder - real implementation would query API sessions
  static CompanionAnalytics extractCompanionAnalytics(
    Iterable<CompanionSessionSummary> sessions,
  ) {
    final list = sessions.toList();
    if (list.isEmpty) {
      return CompanionAnalytics.empty();
    }

    DateTime? lastActive;
    final favoriteMap = <String, int>{};
    int totalMessages = 0;

    for (final session in list) {
      final activityTime = session.lastMessageAt ?? session.createdAt;
      if (lastActive == null || activityTime.isAfter(lastActive!)) {
        lastActive = activityTime;
      }
      totalMessages += session.messageCount;
      favoriteMap[session.companionName] =
          (favoriteMap[session.companionName] ?? 0) + session.messageCount;
    }

    final favoriteTopics = favoriteMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (kDebugMode) {
      debugPrint(
        'CompanionAnalytics: ${list.length} sessions, total messages $totalMessages',
      );
    }

    return CompanionAnalytics(
      sessionCount: list.length,
      lastActiveDate: lastActive,
      totalMessages: totalMessages,
      averageSessionDuration: 0,
      favoriteTopics: favoriteTopics.take(3).map((entry) => entry.key).toList(),
    );
  }

  /// Aggregate all analytics into a single UserAnalytics object
  static UserAnalytics aggregateAnalytics({
    required String userId,
    required JournalAnalytics journal,
    required BehaviorAnalytics behavior,
    required AppointmentAnalytics appointments,
    required CompanionAnalytics companion,
  }) {
    final analytics = UserAnalytics(
      userId: userId,
      journal: journal,
      behavior: behavior,
      appointments: appointments,
      companion: companion,
      generatedAt: DateTime.now(),
    );

    if (kDebugMode) {
      debugPrint(
        'UserAnalytics aggregated: '
        'total interactions: ${analytics.totalInteractions}, '
        'engagement: ${analytics.engagementScore}% (${analytics.engagementLevel})',
      );
    }

    return analytics;
  }

  /// Helper: Convert mood score (1-5) to label
  static String _getMoodLabel(int mood) {
    switch (mood) {
      case 1:
        return 'very_sad';
      case 2:
        return 'sad';
      case 3:
        return 'neutral';
      case 4:
        return 'happy';
      case 5:
        return 'very_happy';
      default:
        return 'unknown';
    }
  }

  /// Calculate mood trend based on recent entries
  static String _calculateMoodTrend(List<JournalEntry> recentEntries) {
    if (recentEntries.length < 2) {
      return 'stable';
    }

    // Split entries in half
    final mid = recentEntries.length ~/ 2;
    final firstHalf = recentEntries.sublist(0, mid);
    final secondHalf = recentEntries.sublist(mid);

    final firstAvg = firstHalf.fold<double>(0, (sum, e) => sum + e.mood) / firstHalf.length;
    final secondAvg = secondHalf.fold<double>(0, (sum, e) => sum + e.mood) / secondHalf.length;

    const threshold = 0.5;
    if ((secondAvg - firstAvg).abs() < threshold) {
      return 'stable';
    } else if (secondAvg > firstAvg) {
      return 'improving';
    } else {
      return 'declining';
    }
  }
}
