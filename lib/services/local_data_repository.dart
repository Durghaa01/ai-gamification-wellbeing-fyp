import '../features/appointments/domain/appointment.dart';
import '../features/behavior/domain/behavior_log.dart';
import '../features/companions/domain/companion_session.dart';
import '../features/journal/domain/journal_models.dart';
import '../models/models.dart';
import '../models/user_info.dart';
import 'appointment_data_service.dart';
import 'behavior_data_service.dart';
import 'cache_service.dart';
import 'companion_data_service.dart';
import 'journal_data_service.dart';
import 'user_data_service.dart';
import 'user_info_service.dart';

/// Consolidates local data access with caching semantics similar to Firestore.
class LocalDataRepository {
  LocalDataRepository({
    CacheService? cacheService,
    UserDataService? userService,
    UserInfoService? userInfoService,
    JournalDataService? journalService,
    BehaviorDataService? behaviorService,
    AppointmentDataService? appointmentService,
    CompanionDataService? companionService,
  }) : _cache = cacheService ?? CacheService(),
       _userService = userService ?? UserDataService(),
       _userInfoService = userInfoService ?? UserInfoService(),
       _journalService = journalService ?? JournalDataService(),
       _behaviorService = behaviorService ?? BehaviorDataService(),
       _appointmentService = appointmentService ?? AppointmentDataService(),
       _companionService = companionService ?? CompanionDataService();

  final CacheService _cache;
  final UserDataService _userService;
  final UserInfoService _userInfoService;
  final JournalDataService _journalService;
  final BehaviorDataService _behaviorService;
  final AppointmentDataService _appointmentService;
  final CompanionDataService _companionService;

  static const _userKey = 'user:';
  static const _profileKey = 'userProfile:';
  static const _journalKey = 'journal:';
  static const _behaviorKey = 'behavior:';
  static const _appointmentKey = 'appointment:';
  static const _companionKey = 'companion:';

  Future<AppUser?> fetchUser(String userId, {bool forceRefresh = false}) async {
    final key = '$_userKey$userId';
    if (!forceRefresh) {
      final cached = _cache.get<AppUser>(key);
      if (cached != null) return cached;
    }
    final user = await _userService.fetchUser(userId);
    if (user == null) {
      _cache.remove(key);
      return null;
    }
    _cache.set(key, user);
    return user;
  }

  Stream<AppUser?> watchUser(String userId) {
    final key = '$_userKey$userId';
    return _userService.watchUser(userId).map((user) {
      if (user != null) {
        _cache.set(key, user);
      } else {
        _cache.remove(key);
      }
      return user;
    });
  }

  Future<UserInfo?> fetchUserProfile(
    String userId, {
    bool forceRefresh = false,
  }) async {
    final key = '$_profileKey$userId';
    if (!forceRefresh) {
      final cached = _cache.get<UserInfo>(key);
      if (cached != null) return cached;
    }
    final info = await _userInfoService.getUserInfo(userId);
    if (info != null) {
      _cache.set(key, info);
    } else {
      _cache.remove(key);
    }
    return info;
  }

  Stream<UserInfo?> watchUserProfile(String userId) {
    final key = '$_profileKey$userId';
    return _userInfoService.watchUserInfo(userId).map((info) {
      if (info != null) {
        _cache.set(key, info);
      } else {
        _cache.remove(key);
      }
      return info;
    });
  }

  Future<List<JournalEntry>> fetchJournalEntries(
    String userId, {
    bool forceRefresh = false,
  }) async {
    final key = '$_journalKey$userId';
    if (!forceRefresh) {
      final cached = _cache.get<List<JournalEntry>>(key);
      if (cached != null) return cached;
    }
    final entries = await _journalService.fetchEntries(userId);
    final snapshot = List<JournalEntry>.unmodifiable(entries);
    _cache.set(key, snapshot);
    return snapshot;
  }

  Stream<List<JournalEntry>> watchJournalEntries(String userId) {
    final key = '$_journalKey$userId';
    return _journalService.watchEntries(userId).map((entries) {
      final snapshot = List<JournalEntry>.unmodifiable(entries);
      _cache.set(key, snapshot);
      return snapshot;
    });
  }

  Future<List<BehaviorLog>> fetchBehaviorLogs(
    String userId, {
    bool forceRefresh = false,
  }) async {
    final key = '$_behaviorKey$userId';
    if (!forceRefresh) {
      final cached = _cache.get<List<BehaviorLog>>(key);
      if (cached != null) return cached;
    }
    final logs = await _behaviorService.fetchLogs(userId);
    final snapshot = List<BehaviorLog>.unmodifiable(logs);
    _cache.set(key, snapshot);
    return snapshot;
  }

  Stream<List<BehaviorLog>> watchBehaviorLogs(String userId) {
    final key = '$_behaviorKey$userId';
    return _behaviorService.watchLogs(userId).map((logs) {
      final snapshot = List<BehaviorLog>.unmodifiable(logs);
      _cache.set(key, snapshot);
      return snapshot;
    });
  }

  Future<List<Appointment>> fetchAppointments(
    String userId, {
    bool forceRefresh = false,
  }) async {
    final key = '$_appointmentKey$userId';
    if (!forceRefresh) {
      final cached = _cache.get<List<Appointment>>(key);
      if (cached != null) return cached;
    }
    final appointments = await _appointmentService.fetchAppointments(userId);
    final snapshot = List<Appointment>.unmodifiable(appointments);
    _cache.set(key, snapshot);
    return snapshot;
  }

  Stream<List<Appointment>> watchAppointments(String userId) {
    final key = '$_appointmentKey$userId';
    return _appointmentService.watchAppointments(userId).map((appointments) {
      final snapshot = List<Appointment>.unmodifiable(appointments);
      _cache.set(key, snapshot);
      return snapshot;
    });
  }

  Future<List<CompanionSessionSummary>> fetchCompanionSessions(
    String userId, {
    bool forceRefresh = false,
  }) async {
    final key = '$_companionKey$userId';
    if (!forceRefresh) {
      final cached = _cache.get<List<CompanionSessionSummary>>(key);
      if (cached != null) return cached;
    }
    final sessions = await _companionService.fetchSessions(userId);
    final snapshot = List<CompanionSessionSummary>.unmodifiable(sessions);
    _cache.set(key, snapshot);
    return snapshot;
  }

  Stream<List<CompanionSessionSummary>> watchCompanionSessions(
    String userId, {
    bool includeArchived = false,
  }) {
    final key = '$_companionKey$userId';
    return _companionService
        .watchSessions(userId, includeArchived: includeArchived)
        .map((sessions) {
          final snapshot = List<CompanionSessionSummary>.unmodifiable(sessions);
          _cache.set(key, snapshot);
          return snapshot;
        });
  }
}
