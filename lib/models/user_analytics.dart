/// Journal entry analytics
class JournalAnalytics {
  const JournalAnalytics({
    required this.entryCount,
    required this.lastEntryDate,
    this.moodTrend = 'stable',
    this.moodDistribution = const {},
    this.averageMoodScore = 0.0,
    this.thisWeekEntries = 0,
  });

  /// Total number of journal entries
  final int entryCount;

  /// Date of the most recent entry
  final DateTime? lastEntryDate;

  /// Mood trend (improving/stable/declining)
  final String moodTrend;

  /// Distribution of moods: {happy: count, neutral: count, sad: count}
  final Map<String, int> moodDistribution;

  /// Average mood score (0-100)
  final double averageMoodScore;

  /// Number of entries this week
  final int thisWeekEntries;

  /// Days since last entry
  int get daysSinceLastEntry {
    if (lastEntryDate == null) return -1;
    return DateTime.now().difference(lastEntryDate!).inDays;
  }

  factory JournalAnalytics.empty() => const JournalAnalytics(
    entryCount: 0,
    lastEntryDate: null,
    moodTrend: 'stable',
    moodDistribution: {},
    averageMoodScore: 0.0,
    thisWeekEntries: 0,
  );

  @override
  String toString() =>
      'JournalAnalytics(entryCount: $entryCount, trend: $moodTrend, '
      'lastEntry: ${lastEntryDate?.toLocal().toString().split(' ')[0]})';
}

/// Behavior tracker analytics
class BehaviorAnalytics {
  const BehaviorAnalytics({
    required this.activityCount,
    required this.lastActivityDate,
    this.consistencyScore = 0,
    this.thisMonthCount = 0,
    this.currentStreak = 0,
    this.mostLoggedActivity = '',
  });

  /// Total activities logged
  final int activityCount;

  /// Date of most recent activity
  final DateTime? lastActivityDate;

  /// Consistency score (0-100, percentage of days with activities)
  final int consistencyScore;

  /// Activities logged this month
  final int thisMonthCount;

  /// Current consecutive days with activities
  final int currentStreak;

  /// Most frequently logged activity
  final String mostLoggedActivity;

  /// Days since last activity
  int get daysSinceLastActivity {
    if (lastActivityDate == null) return -1;
    return DateTime.now().difference(lastActivityDate!).inDays;
  }

  factory BehaviorAnalytics.empty() => const BehaviorAnalytics(
    activityCount: 0,
    lastActivityDate: null,
    consistencyScore: 0,
    thisMonthCount: 0,
    currentStreak: 0,
    mostLoggedActivity: '',
  );

  @override
  String toString() =>
      'BehaviorAnalytics(activityCount: $activityCount, '
      'consistency: $consistencyScore%, streak: $currentStreak days)';
}

/// Appointment analytics
class AppointmentAnalytics {
  const AppointmentAnalytics({
    required this.totalCount,
    required this.completedCount,
    required this.upcomingCount,
    this.nextAppointmentDate,
    this.averageRating = 0.0,
  });

  /// Total appointments (all time)
  final int totalCount;

  /// Completed appointments
  final int completedCount;

  /// Upcoming appointments
  final int upcomingCount;

  /// Date of next appointment
  final DateTime? nextAppointmentDate;

  /// Average rating of completed appointments
  final double averageRating;

  /// Completion rate percentage
  int get completionRate => totalCount == 0 ? 0 : (completedCount * 100) ~/ totalCount;

  factory AppointmentAnalytics.empty() => const AppointmentAnalytics(
    totalCount: 0,
    completedCount: 0,
    upcomingCount: 0,
    nextAppointmentDate: null,
    averageRating: 0.0,
  );

  @override
  String toString() =>
      'AppointmentAnalytics(total: $totalCount, completed: $completedCount, '
      'upcoming: $upcomingCount, rate: $completionRate%)';
}

/// Companion AI chat analytics
class CompanionAnalytics {
  const CompanionAnalytics({
    required this.sessionCount,
    required this.lastActiveDate,
    this.totalMessages = 0,
    this.averageSessionDuration = 0,
    this.favoriteTopics = const [],
  });

  /// Total chat sessions
  final int sessionCount;

  /// Date of last active session
  final DateTime? lastActiveDate;

  /// Total messages exchanged
  final int totalMessages;

  /// Average session duration in minutes
  final int averageSessionDuration;

  /// Most discussed topics
  final List<String> favoriteTopics;

  /// Days since last session
  int get daysSinceLastSession {
    if (lastActiveDate == null) return -1;
    return DateTime.now().difference(lastActiveDate!).inDays;
  }

  factory CompanionAnalytics.empty() => const CompanionAnalytics(
    sessionCount: 0,
    lastActiveDate: null,
    totalMessages: 0,
    averageSessionDuration: 0,
    favoriteTopics: [],
  );

  @override
  String toString() =>
      'CompanionAnalytics(sessions: $sessionCount, messages: $totalMessages, '
      'lastActive: ${lastActiveDate?.toLocal().toString().split(' ')[0]})';
}

/// Aggregated user analytics from all features
class UserAnalytics {
  const UserAnalytics({
    required this.userId,
    required this.journal,
    required this.behavior,
    required this.appointments,
    required this.companion,
    required this.generatedAt,
  });

  /// User ID
  final String userId;

  /// Journal analytics
  final JournalAnalytics journal;

  /// Behavior tracker analytics
  final BehaviorAnalytics behavior;

  /// Appointment analytics
  final AppointmentAnalytics appointments;

  /// Companion analytics
  final CompanionAnalytics companion;

  /// Timestamp when analytics were generated
  final DateTime generatedAt;

  /// Total interactions across all features
  int get totalInteractions =>
      journal.entryCount +
      behavior.activityCount +
      appointments.totalCount +
      companion.sessionCount;

  /// Overall engagement score (0-100)
  int get engagementScore {
    final weights = {
      'journal': journal.entryCount * 5,
      'behavior': behavior.activityCount * 3,
      'appointments': appointments.completedCount * 10,
      'companion': companion.sessionCount * 2,
    };

    final total = weights.values.fold<int>(0, (a, b) => a + b);
    // Normalize to 0-100
    if (total == 0) return 0;
    return (total / 20).ceil().clamp(0, 100);
  }

  /// Get engagement level description
  String get engagementLevel {
    if (engagementScore >= 80) return 'Excellent';
    if (engagementScore >= 60) return 'Good';
    if (engagementScore >= 40) return 'Moderate';
    if (engagementScore >= 20) return 'Low';
    return 'Very Low';
  }

  factory UserAnalytics.empty(String userId) => UserAnalytics(
    userId: userId,
    journal: JournalAnalytics.empty(),
    behavior: BehaviorAnalytics.empty(),
    appointments: AppointmentAnalytics.empty(),
    companion: CompanionAnalytics.empty(),
    generatedAt: DateTime.now(),
  );

  @override
  String toString() =>
      'UserAnalytics(interactions: $totalInteractions, '
      'engagement: $engagementScore% ($engagementLevel))';
}
