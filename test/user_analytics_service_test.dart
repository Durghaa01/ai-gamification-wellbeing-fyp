import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_mhproj/features/appointments/domain/appointment.dart';
import 'package:flutter_application_mhproj/features/behavior/domain/behavior_log.dart';
import 'package:flutter_application_mhproj/features/companions/domain/companion_session.dart';
import 'package:flutter_application_mhproj/features/journal/domain/journal_models.dart';
import 'package:flutter_application_mhproj/models/user_analytics.dart';
import 'package:flutter_application_mhproj/services/user_analytics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UserAnalyticsService.extractJournalAnalytics', () {
    test('returns expected metrics for populated entries', () {
      final now = DateTime.now();
      final entries = List.generate(
        7,
        (index) => JournalEntry(
          createdAt: now.subtract(Duration(days: 6 - index)),
          mood: 3 + index % 2,
          tags: const ['wellness'],
          note: 'Entry $index',
          sentiment: const SentimentInsight(label: 'positive', confidence: 0.8),
          risk: const RiskInsight(
            level: 'low',
            score: 10,
            reason: '',
            triggers: <String>[],
          ),
        ),
      );

      final analytics = UserAnalyticsService.extractJournalAnalytics(entries);

      expect(analytics.entryCount, 7);
      expect(analytics.lastEntryDate, entries.last.createdAt);
      expect(analytics.thisWeekEntries, greaterThan(0));
      expect(analytics.moodDistribution.isNotEmpty, isTrue);
      expect(
        ['improving', 'declining', 'stable'],
        contains(analytics.moodTrend),
      );
    });

    test('returns empty analytics when entries list is empty', () {
      final analytics = UserAnalyticsService.extractJournalAnalytics(const []);
      expect(analytics.entryCount, 0);
      expect(analytics.moodTrend, 'stable');
    });
  });

  group('UserAnalyticsService.extractBehaviorAnalytics', () {
    test('calculates streak and consistency from behavior logs', () {
      final now = DateTime.now();
      final logs = [
        BehaviorLog(
          id: 'log1',
          loggedAt: now.subtract(const Duration(days: 1)),
          riskScore: 3.2,
          label: 'moderate',
        ),
        BehaviorLog(
          id: 'log2',
          loggedAt: now.subtract(const Duration(days: 2)),
          riskScore: 2.4,
          label: 'low',
        ),
        BehaviorLog(
          id: 'log3',
          loggedAt: now,
          riskScore: 4.1,
          label: 'high',
        ),
      ];

      final analytics = UserAnalyticsService.extractBehaviorAnalytics(logs);

      expect(analytics.activityCount, logs.length);
      expect(analytics.lastActivityDate, logs.last.loggedAt);
      expect(analytics.currentStreak, greaterThanOrEqualTo(1));
      expect(analytics.consistencyScore, inInclusiveRange(0, 100));
      expect(analytics.mostLoggedActivity, isNotEmpty);
    });
  });

  group('UserAnalyticsService.extractAppointmentAnalytics', () {
    test('identifies upcoming and completed appointments', () {
      final now = DateTime.now();
      final List<Appointment> appointments = [
        Appointment(
          userId: 'a1',
          counselorId: '100',
          date: now.subtract(const Duration(days: 1)),
          time: const TimeOfDay(hour: 10, minute: 0),
          mode: 'Online',
        ),
        Appointment(
          userId: 'a1',
          counselorId: '100',
          date: now.add(const Duration(days: 2)),
          time: const TimeOfDay(hour: 11, minute: 30),
          mode: 'In-Person',
        ),
      ];

      final analytics = UserAnalyticsService.extractAppointmentAnalytics(appointments);

      expect(analytics.totalCount, 2);
      expect(analytics.completedCount, 1);
      expect(analytics.upcomingCount, 1);
      expect(analytics.nextAppointmentDate, isNotNull);
    });
  });

  group('UserAnalyticsService.extractCompanionAnalytics', () {
    test('aggregates companion session metadata', () {
      final sessions = [
        CompanionSessionSummary(
          id: 's1',
          companionId: 'c_listener',
          companionName: 'Listener',
          title: 'Listener',
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
          lastMessageAt: DateTime.now().subtract(const Duration(days: 1)),
          messageCount: 4,
          archivedAt: null,
          isArchived: false,
        ),
        CompanionSessionSummary(
          id: 's2',
          companionId: 'c_coach',
          companionName: 'Coach',
          title: 'Coach',
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
          lastMessageAt: DateTime.now(),
          messageCount: 6,
          archivedAt: null,
          isArchived: false,
        ),
      ];

      final analytics = UserAnalyticsService.extractCompanionAnalytics(sessions);

      expect(analytics.sessionCount, sessions.length);
      expect(analytics.totalMessages, 10);
      expect(analytics.lastActiveDate, equals(sessions.last.lastMessageAt));
      expect(analytics.favoriteTopics, contains('Coach'));
    });
  });

  group('UserAnalyticsService.aggregateAnalytics', () {
    test('combines feature analytics into aggregated view', () {
      final aggregated = UserAnalyticsService.aggregateAnalytics(
        userId: 'user-123',
        journal: JournalAnalytics(
          entryCount: 10,
          lastEntryDate: DateTime.now(),
          moodTrend: 'improving',
          moodDistribution: const {'happy': 6, 'neutral': 4},
          averageMoodScore: 80,
          thisWeekEntries: 4,
        ),
        behavior: BehaviorAnalytics(
          activityCount: 5,
          lastActivityDate: DateTime.now(),
          consistencyScore: 70,
          thisMonthCount: 5,
          currentStreak: 3,
          mostLoggedActivity: 'low',
        ),
        appointments: AppointmentAnalytics(
          totalCount: 3,
          completedCount: 2,
          upcomingCount: 1,
          nextAppointmentDate: DateTime.now().add(const Duration(days: 1)),
          averageRating: 4.5,
        ),
        companion: CompanionAnalytics(
          sessionCount: 7,
          lastActiveDate: DateTime.now(),
          totalMessages: 70,
          averageSessionDuration: 0,
          favoriteTopics: const ['Listener'],
        ),
      );

      expect(aggregated.userId, 'user-123');
      expect(aggregated.totalInteractions, 10 + 5 + 3 + 7);
      expect(aggregated.engagementScore, inInclusiveRange(0, 100));
    });
  });
}
