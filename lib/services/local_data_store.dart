import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../data/mindwell_repository.dart';
import '../features/appointments/domain/appointment.dart';
import '../features/behavior/domain/behavior_log.dart';
import '../features/companions/domain/companion_session.dart';
import '../features/journal/domain/journal_models.dart';
import '../models/models.dart';
import '../models/user_info.dart' as profile;

/// Hive-backed local data store that replaces Firebase/Firestore.
class LocalDataStore {
  LocalDataStore._();

  static final LocalDataStore instance = LocalDataStore._();

  static const _boxName = 'mindwell_store';
  static const _usersKey = 'users';
  static const _passwordsKey = 'passwords';
  static const _profilesKey = 'profiles';
  static const _journalKey = 'journal_entries';
  static const _behaviorKey = 'behavior_logs';
  static const _appointmentKey = 'appointments';
  static const _companionKey = 'companion_sessions';
  static const _verificationKey = 'email_verification';

  Box<dynamic>? _box;
  bool _initialized = false;

  final Map<String, AppUser> _users = <String, AppUser>{};
  final Map<String, String> _passwords = <String, String>{};
  final Map<String, profile.UserInfo> _profiles = <String, profile.UserInfo>{};
  final Map<String, List<JournalEntry>> _journalEntries =
      <String, List<JournalEntry>>{};
  final Map<String, List<BehaviorLog>> _behaviorLogs =
      <String, List<BehaviorLog>>{};
  final Map<String, List<Appointment>> _appointments =
      <String, List<Appointment>>{};
  final Map<String, List<CompanionSessionSummary>> _companionSessions =
      <String, List<CompanionSessionSummary>>{};
  final Map<String, bool> _emailVerification = <String, bool>{};

  final StreamController<List<AppUser>> _usersController =
      StreamController<List<AppUser>>.broadcast();
  final Map<String, StreamController<AppUser?>> _userControllers =
      <String, StreamController<AppUser?>>{};
  final Map<String, StreamController<profile.UserInfo?>> _profileControllers =
      <String, StreamController<profile.UserInfo?>>{};
  final Map<String, StreamController<List<JournalEntry>>> _journalControllers =
      <String, StreamController<List<JournalEntry>>>{};
  final Map<String, StreamController<List<BehaviorLog>>> _behaviorControllers =
      <String, StreamController<List<BehaviorLog>>>{};
  final Map<String, StreamController<List<Appointment>>>
  _appointmentControllers = <String, StreamController<List<Appointment>>>{};
  final Map<String, StreamController<List<CompanionSessionSummary>>>
  _companionControllers =
      <String, StreamController<List<CompanionSessionSummary>>>{};

  final Random _random = Random(42);

  bool get isInitialized => _initialized;

  Future<void> init({bool forceReset = false}) async {
    _box ??= await Hive.openBox<dynamic>(_boxName);
    if (forceReset) {
      await _box!.clear();
      _clearInMemory();
      _seed();
      await _persistAll();
      _initialized = true;
      return;
    }
    if (_initialized) return;
    _loadFromDisk();
    if (_users.isEmpty) {
      _seed();
      await _persistAll();
    }
    _initialized = true;
  }

  // ===== User helpers =====

  List<AppUser> get users => _users.values.toList(growable: false);

  void _emitUsers() {
    _usersController.add(users);
  }

  AppUser? fetchUser(String userId) => _users[userId];

  bool isEmailVerified(String userId) {
    return _emailVerification[userId] ?? true;
  }

  void setEmailVerification(String userId, {required bool verified}) {
    _emailVerification[userId] = verified;
    _persistEmailVerification();
  }

  Stream<List<AppUser>> watchUsers() {
    _emitUsers();
    return _usersController.stream;
  }

  Stream<AppUser?> watchUser(String userId) {
    final controller = _userControllers.putIfAbsent(
      userId,
      () => StreamController<AppUser?>.broadcast(),
    );
    controller.add(_users[userId]);
    return controller.stream;
  }

  AppUser? findUserByEmail(String email) {
    final lower = email.toLowerCase();
    try {
      return _users.values.firstWhere(
        (user) => user.email.toLowerCase() == lower,
      );
    } catch (_) {
      return null;
    }
  }

  AppUser? authenticate({required String email, required String password}) {
    final lower = email.toLowerCase();
    final stored = _passwords[lower];
    if (stored == null || stored != password) {
      return null;
    }
    return findUserByEmail(email);
  }

  AppUser registerUser({
    required String email,
    required String password,
    required String displayName,
    required Role role,
  }) {
    final id = 'local-${_users.length + 1}';
    final user = AppUser(id: id, name: displayName, email: email, role: role);
    _users[id] = user;
    _passwords[email.toLowerCase()] = password;
    setEmailVerification(id, verified: false);
    _profiles[id] = profile.UserInfo(
      userId: id,
      email: email,
      displayName: displayName,
      createdAt: DateTime.now(),
      lastProfileUpdate: DateTime.now(),
    );
    _emitUsers();
    _emitProfile(id);
    _persistUsers();
    _persistPasswords();
    _persistProfiles();
    return user;
  }

  void upsertUser(AppUser user) {
    _users[user.id] = user;
    _emailVerification.putIfAbsent(user.id, () => true);
    _emitUsers();
    _userControllers[user.id]?.add(user);
    _persistUsers();
    _persistEmailVerification();
  }

  void deleteUser(String userId) {
    final removed = _users.remove(userId);
    if (removed != null) {
      _passwords.remove(removed.email.toLowerCase());
      _persistPasswords();
    }
    _emailVerification.remove(userId);
    _profiles.remove(userId);
    _journalEntries.remove(userId);
    _behaviorLogs.remove(userId);
    _appointments.remove(userId);
    _companionSessions.remove(userId);
    _emitUsers();
    _userControllers[userId]?.add(null);
    _emitProfile(userId);
    _persistUsers();
    _persistProfiles();
    _persistJournalEntries();
    _persistBehaviorLogs();
    _persistAppointments();
    _persistCompanionSessions();
    _persistEmailVerification();
  }

  // ===== Profile helpers =====

  profile.UserInfo? getUserInfo(String userId) => _profiles[userId];

  Future<profile.UserInfo?> fetchUserInfo(String userId) async {
    return _profiles[userId];
  }

  profile.UserInfo upsertUserInfo(profile.UserInfo info) {
    final updated = info.copyWith(lastProfileUpdate: DateTime.now());
    _profiles[info.userId] = updated;
    _emitProfile(info.userId);
    _persistProfiles();
    return updated;
  }

  void deleteUserInfo(String userId) {
    _profiles.remove(userId);
    _emitProfile(userId);
    _persistProfiles();
  }

  Stream<profile.UserInfo?> watchUserInfo(String userId) {
    final controller = _profileControllers.putIfAbsent(
      userId,
      () => StreamController<profile.UserInfo?>.broadcast(),
    );
    controller.add(_profiles[userId]);
    return controller.stream;
  }

  void _emitProfile(String userId) {
    final controller = _profileControllers[userId];
    controller?.add(_profiles[userId]);
  }

  // ===== Journal helpers =====

  List<JournalEntry> _journalList(String userId) =>
      _journalEntries.putIfAbsent(userId, () => <JournalEntry>[]);

  Stream<List<JournalEntry>> watchJournalEntries(String userId) {
    final controller = _journalControllers.putIfAbsent(
      userId,
      () => StreamController<List<JournalEntry>>.broadcast(),
    );
    controller.add(List<JournalEntry>.unmodifiable(_journalList(userId)));
    return controller.stream;
  }

  Future<List<JournalEntry>> fetchJournalEntries(String userId) async {
    return List<JournalEntry>.unmodifiable(_journalList(userId));
  }

  void saveJournalEntry(String userId, JournalEntry entry) {
    final entries = _journalList(userId);
    entries.removeWhere((existing) => existing.dayKey == entry.dayKey);
    entries.add(entry);
    entries.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _journalControllers[userId]?.add(List<JournalEntry>.unmodifiable(entries));
    _persistJournalEntries();
  }

  // ===== Behavior helpers =====

  List<BehaviorLog> _behaviorList(String userId) =>
      _behaviorLogs.putIfAbsent(userId, () => <BehaviorLog>[]);

  Stream<List<BehaviorLog>> watchBehaviorLogs(String userId) {
    final controller = _behaviorControllers.putIfAbsent(
      userId,
      () => StreamController<List<BehaviorLog>>.broadcast(),
    );
    controller.add(List<BehaviorLog>.unmodifiable(_behaviorList(userId)));
    return controller.stream;
  }

  Future<List<BehaviorLog>> fetchBehaviorLogs(String userId) async {
    return List<BehaviorLog>.unmodifiable(_behaviorList(userId));
  }

  void addBehaviorLog(String userId, BehaviorLog log) {
    final logs = _behaviorList(userId);
    logs.add(log);
    logs.sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    _behaviorControllers[userId]?.add(List<BehaviorLog>.unmodifiable(logs));
    _persistBehaviorLogs();
  }

  // ===== Appointment helpers =====

  List<Appointment> _appointmentList(String userId) =>
      _appointments.putIfAbsent(userId, () => <Appointment>[]);

  Stream<List<Appointment>> watchAppointments(String userId) {
    final controller = _appointmentControllers.putIfAbsent(
      userId,
      () => StreamController<List<Appointment>>.broadcast(),
    );
    controller.add(List<Appointment>.unmodifiable(_appointmentList(userId)));
    return controller.stream;
  }

  Future<List<Appointment>> fetchAppointments(String userId) async {
    return List<Appointment>.unmodifiable(_appointmentList(userId));
  }

  Future<void> upsertAppointment({
    required String userId,
    required String appointmentId,
    required Appointment appointment,
  }) async {
    final list = _appointmentList(userId);
    list.removeWhere((existing) => existing.id == appointmentId);
    list.add(appointment);
    list.sort((a, b) => a.date.compareTo(b.date));
    _appointmentControllers[userId]?.add(List<Appointment>.unmodifiable(list));
    _persistAppointments();
  }

  Future<void> deleteAppointment({
    required String userId,
    required String appointmentId,
  }) async {
    final list = _appointmentList(userId);
    list.removeWhere((appointment) => appointment.id == appointmentId);
    _appointmentControllers[userId]?.add(List<Appointment>.unmodifiable(list));
    _persistAppointments();
  }

  // ===== Companion helpers =====

  List<CompanionSessionSummary> _companionList(String userId) =>
      _companionSessions.putIfAbsent(userId, () => <CompanionSessionSummary>[]);

  List<CompanionSessionSummary> _sortedSessions(
    String userId, {
    bool includeArchived = false,
  }) {
    final source = includeArchived
        ? _companionList(userId)
        : _companionList(userId).where((session) => !session.isArchived);
    final sessions = List<CompanionSessionSummary>.from(source);
    sessions.sort(
      (a, b) => (b.lastMessageAt ?? b.createdAt).compareTo(
        a.lastMessageAt ?? a.createdAt,
      ),
    );
    return sessions;
  }

  Stream<List<CompanionSessionSummary>> watchCompanionSessions(
    String userId, {
    bool includeArchived = false,
  }) {
    final controller = _companionControllers.putIfAbsent(
      userId,
      () => StreamController<List<CompanionSessionSummary>>.broadcast(),
    );
    controller.add(
      List<CompanionSessionSummary>.unmodifiable(
        _sortedSessions(userId, includeArchived: includeArchived),
      ),
    );
    return controller.stream;
  }

  Future<List<CompanionSessionSummary>> fetchCompanionSessions(
    String userId, {
    bool includeArchived = false,
  }) async {
    final list = _sortedSessions(userId, includeArchived: includeArchived);
    return List<CompanionSessionSummary>.unmodifiable(list);
  }

  void addCompanionMessage({
    required String userId,
    required CompanionSessionSummary session,
  }) {
    final list = _companionList(userId);
    list.removeWhere((existing) => existing.id == session.id);
    list.add(session);
    _companionControllers[userId]?.add(
      List<CompanionSessionSummary>.unmodifiable(_sortedSessions(userId)),
    );
    _persistCompanionSessions();
  }

  CompanionSessionSummary? updateCompanionSession({
    required String userId,
    required String sessionId,
    String? title,
    bool? isArchived,
    String? summary,
    int? tokenCount,
    int? latencyMs,
  }) {
    final list = _companionList(userId);
    final index = list.indexWhere((session) => session.id == sessionId);
    if (index == -1) return null;
    final current = list[index];
    final updated = CompanionSessionSummary(
      id: current.id,
      companionId: current.companionId,
      companionName: current.companionName,
      title: title ?? current.title ?? current.companionName,
      summary: summary ?? current.summary,
      createdAt: current.createdAt,
      lastMessageAt: current.lastMessageAt,
      messageCount: current.messageCount,
      tokenCount: tokenCount ?? current.tokenCount,
      latencyMs: latencyMs ?? current.latencyMs,
      archivedAt: (isArchived ?? current.isArchived)
          ? (current.archivedAt ?? DateTime.now())
          : null,
      isArchived: isArchived ?? current.isArchived,
    );
    list[index] = updated;
    _companionControllers[userId]?.add(
      List<CompanionSessionSummary>.unmodifiable(_sortedSessions(userId)),
    );
    _persistCompanionSessions();
    return updated;
  }

  void deleteCompanionSession({
    required String userId,
    required String sessionId,
  }) {
    final list = _companionList(userId);
    list.removeWhere((session) => session.id == sessionId);
    _companionControllers[userId]?.add(
      List<CompanionSessionSummary>.unmodifiable(_sortedSessions(userId)),
    );
    _persistCompanionSessions();
  }

  // ===== Persistence helpers =====

  void _loadFromDisk() {
    _clearInMemory();
    final rawUsers = _box?.get(_usersKey);
    if (rawUsers is Map) {
      rawUsers.forEach((key, value) {
        if (value is Map) {
          _users[key as String] = AppUser.fromMap(
            Map<String, dynamic>.from(value.cast<String, dynamic>()),
            id: key as String,
          );
        }
      });
    }

    final rawPasswords = _box?.get(_passwordsKey);
    if (rawPasswords is Map) {
      _passwords
        ..clear()
        ..addAll(
          rawPasswords.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ),
        );
    }

    final rawProfiles = _box?.get(_profilesKey);
    if (rawProfiles is Map) {
      rawProfiles.forEach((key, value) {
        if (value is Map) {
          _profiles[key as String] = profile.UserInfo.fromMap(
            Map<String, dynamic>.from(value.cast<String, dynamic>()),
          );
        }
      });
    }

    final rawJournal = _box?.get(_journalKey);
    if (rawJournal is Map) {
      rawJournal.forEach((key, value) {
        if (value is List) {
          _journalEntries[key as String] = value
              .whereType<Map>()
              .map(
                (item) => _journalEntryFromStorage(
                  Map<String, dynamic>.from(item.cast<String, dynamic>()),
                ),
              )
              .toList();
        }
      });
    }

    final rawBehavior = _box?.get(_behaviorKey);
    if (rawBehavior is Map) {
      rawBehavior.forEach((key, value) {
        if (value is List) {
          _behaviorLogs[key as String] = value
              .whereType<Map>()
              .map(
                (item) => BehaviorLog.fromMap(
                  Map<String, dynamic>.from(item.cast<String, dynamic>()),
                  id: (item['id'] as String?) ?? '',
                ),
              )
              .toList();
        }
      });
    }

    final rawAppointments = _box?.get(_appointmentKey);
    if (rawAppointments is Map) {
      rawAppointments.forEach((key, value) {
        if (value is List) {
          _appointments[key as String] = value
              .whereType<Map>()
              .map(
                (item) => Appointment.fromMap(
                  Map<String, dynamic>.from(item.cast<String, dynamic>()),
                  id: item['id'] as String?,
                ),
              )
              .toList();
        }
      });
    }

    final rawCompanions = _box?.get(_companionKey);
    if (rawCompanions is Map) {
      rawCompanions.forEach((key, value) {
        if (value is List) {
          _companionSessions[key as String] = value
              .whereType<Map>()
              .map(
                (item) => CompanionSessionSummary.fromMap(
                  Map<String, dynamic>.from(item.cast<String, dynamic>()),
                  id: item['id'] as String? ?? '',
                ),
              )
              .toList();
        }
      });
    }

    final rawVerification = _box?.get(_verificationKey);
    if (rawVerification is Map) {
      _emailVerification
        ..clear()
        ..addAll(
          rawVerification.map(
            (key, value) => MapEntry(key.toString(), value == true),
          ),
        );
    }
  }

  Future<void> _persistAll() async {
    _persistUsers();
    _persistPasswords();
    _persistProfiles();
    _persistJournalEntries();
    _persistBehaviorLogs();
    _persistAppointments();
    _persistCompanionSessions();
    _persistEmailVerification();
  }

  void _persistUsers() {
    final data = _users.map((key, value) => MapEntry(key, value.toMap()));
    _box?.put(_usersKey, data);
  }

  void _persistPasswords() {
    _box?.put(_passwordsKey, _passwords);
  }

  void _persistProfiles() {
    final data = <String, dynamic>{};
    _profiles.forEach((key, value) {
      data[key] = _serializeUserInfo(value);
    });
    _box?.put(_profilesKey, data);
  }

  void _persistJournalEntries() {
    final data = <String, dynamic>{};
    _journalEntries.forEach((key, value) {
      data[key] = value.map(_journalEntryToStorage).toList();
    });
    _box?.put(_journalKey, data);
  }

  void _persistBehaviorLogs() {
    final data = <String, dynamic>{};
    _behaviorLogs.forEach((key, value) {
      data[key] = value.map(_behaviorLogToStorage).toList();
    });
    _box?.put(_behaviorKey, data);
  }

  void _persistAppointments() {
    final data = <String, dynamic>{};
    _appointments.forEach((key, value) {
      data[key] = value.map((appointment) => appointment.toMap()).toList();
    });
    _box?.put(_appointmentKey, data);
  }

  void _persistCompanionSessions() {
    final data = <String, dynamic>{};
    _companionSessions.forEach((key, value) {
      data[key] = value.map(_companionToStorage).toList();
    });
    _box?.put(_companionKey, data);
  }

  void _persistEmailVerification() {
    _box?.put(_verificationKey, _emailVerification);
  }

  // ===== Serialization helpers =====

  Map<String, dynamic> _serializeUserInfo(profile.UserInfo info) {
    final map = info.toMap();
    final serialized = <String, dynamic>{};
    map.forEach((key, value) {
      if (value is DateTime) {
        serialized[key] = value.toIso8601String();
      } else if (value is Map) {
        serialized[key] = Map<String, dynamic>.from(value);
      } else {
        serialized[key] = value;
      }
    });
    return serialized;
  }

  Map<String, dynamic> _journalEntryToStorage(JournalEntry entry) {
    return {
      'createdAt': entry.createdAt.toIso8601String(),
      'mood': entry.mood,
      'tags': entry.tags,
      'note': entry.note,
      'sentiment': {
        'label': entry.sentiment.label,
        'confidence': entry.sentiment.confidence,
        'scores': entry.sentiment.scores,
        'version': entry.sentiment.version,
      },
      'risk': {
        'level': entry.risk.level,
        'score': entry.risk.score,
        'reason': entry.risk.reason,
        'triggers': entry.risk.triggers,
        'version': entry.risk.version,
      },
    };
  }

  JournalEntry _journalEntryFromStorage(Map<String, dynamic> data) {
    final createdAt =
        DateTime.tryParse(data['createdAt'] as String? ?? '') ?? DateTime.now();
    final sentimentData = (data['sentiment'] as Map?) ?? const {};
    final riskData = (data['risk'] as Map?) ?? const {};
    return JournalEntry(
      createdAt: createdAt,
      mood: (data['mood'] as num?)?.toInt() ?? 3,
      tags: (data['tags'] as List?)?.cast<String>() ?? const <String>[],
      note: (data['note'] as String?) ?? '',
      sentiment: SentimentInsight(
        label: (sentimentData['label'] as String?) ?? 'neutral',
        confidence: (sentimentData['confidence'] as num?)?.toDouble() ?? 0.5,
        scores: (sentimentData['scores'] as Map?)?.map(
          (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
        ),
        version: (sentimentData['version'] as String?) ?? 'remote',
      ),
      risk: RiskInsight(
        level: (riskData['level'] as String?) ?? 'low',
        score: (riskData['score'] as num?)?.toDouble() ?? 0,
        reason: (riskData['reason'] as String?) ?? '',
        triggers:
            (riskData['triggers'] as List?)?.cast<String>() ?? const <String>[],
        version: (riskData['version'] as String?) ?? 'remote',
      ),
    );
  }

  Map<String, dynamic> _behaviorLogToStorage(BehaviorLog log) {
    final map = log.toMap();
    map['id'] = log.id;
    map['loggedAt'] = log.loggedAt.toIso8601String();
    return map;
  }

  Map<String, dynamic> _companionToStorage(CompanionSessionSummary session) {
    final map = session.toMap();
    map['id'] = session.id;
    map['createdAt'] = session.createdAt.toIso8601String();
    map['lastMessageAt'] = session.lastMessageAt?.toIso8601String();
    map['archivedAt'] = session.archivedAt?.toIso8601String();
    return map;
  }

  void _clearInMemory() {
    _users.clear();
    _passwords.clear();
    _profiles.clear();
    _journalEntries.clear();
    _behaviorLogs.clear();
    _appointments.clear();
    _companionSessions.clear();
    _emailVerification.clear();
  }

  void _seed() {
    final repository = MindWellRepository.instance;
    repository.seed();
    _users
      ..clear()
      ..addEntries(repository.users.map((user) => MapEntry(user.id, user)));
    for (final user in repository.users) {
      _passwords[user.email.toLowerCase()] = 'password123';
      _profiles[user.id] = profile.UserInfo(
        userId: user.id,
        email: user.email,
        displayName: user.name,
        phoneNumber: '+65 1234 5678',
        location: 'Singapore',
        gender: user.gender,
        preferences: const {'darkMode': false, 'notifications': true},
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        lastProfileUpdate: DateTime.now().subtract(const Duration(days: 2)),
      );
      _journalEntries[user.id] = _generateJournalEntries();
      _behaviorLogs[user.id] = _generateBehaviorLogs();
      _appointments[user.id] = _generateAppointments(user.id);
      _companionSessions[user.id] = _generateCompanionSessions();
      _emailVerification[user.id] = true;
    }
  }

  List<JournalEntry> _generateJournalEntries() {
    final now = DateTime.now();
    return List<JournalEntry>.generate(7, (index) {
      final day = now.subtract(Duration(days: index));
      final mood = 2 + _random.nextInt(3);
      return JournalEntry(
        createdAt: day,
        mood: mood,
        tags: const <String>['gratitude', 'reflection'],
        note: 'Daily reflection for ${day.toLocal()}',
        sentiment: SentimentInsight(
          label: mood >= 4 ? 'positive' : 'neutral',
          confidence: 0.6,
        ),
        risk: RiskInsight(
          level: mood <= 2 ? 'moderate' : 'low',
          score: (5 - mood) * 10,
          reason: 'Self-reported mood',
        ),
      );
    }).reversed.toList();
  }

  List<BehaviorLog> _generateBehaviorLogs() {
    final now = DateTime.now();
    return List<BehaviorLog>.generate(10, (index) {
      final day = now.subtract(Duration(days: index));
      final riskScore = _random.nextInt(80) / 10 + 2;
      return BehaviorLog(
        id: 'behavior-$index',
        loggedAt: day,
        riskScore: riskScore,
        label: riskScore > 6 ? 'high' : 'low',
        notes: 'Automated insight for ${day.toLocal()}',
      );
    }).reversed.toList();
  }

  List<Appointment> _generateAppointments(String userId) {
    final now = DateTime.now();
    return List<Appointment>.generate(4, (index) {
      final date = now.add(Duration(days: index * 7));
      return Appointment(
        id: 'appt-$index',
        date: DateTime(date.year, date.month, date.day),
        time: TimeOfDay(hour: 9 + index, minute: 0),
        mode: index.isEven ? 'In-person' : 'Virtual',
        userId: userId,
        counselorId: 'counselor-$index',
        medication: index.isEven ? 'Vitamin D' : null,
        remark: 'Follow-up session',
      );
    });
  }

  List<CompanionSessionSummary> _generateCompanionSessions() {
    final now = DateTime.now();
    return List<CompanionSessionSummary>.generate(3, (index) {
      return CompanionSessionSummary(
        id: 'session-$index',
        companionId: 'companion-$index',
        companionName: 'Mindful Bot ${index + 1}',
        title: 'Mindful Bot ${index + 1}',
        summary: 'Recent chat covering topic #$index.',
        createdAt: now.subtract(Duration(days: 10 - index)),
        lastMessageAt: now.subtract(Duration(days: index)),
        messageCount: 4 + index,
        tokenCount: 400 + (index * 25),
        latencyMs: 800 - (index * 50),
        archivedAt: null,
        isArchived: false,
      );
    });
  }
}
