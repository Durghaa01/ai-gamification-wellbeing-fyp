import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../experiments/experiments.dart';
import '../../data/mindwell_repository.dart';
import '../../services/api/companion_remote_api.dart';
import '../../services/api/journal_remote_api.dart';
import '../../services/api/mindwell_api_client.dart';
import '../../services/auth_service.dart';
import '../../services/user_data_service.dart';
import '../../services/identity/identity_service.dart';
import '../../services/user_info_service.dart';
import '../../services/user_analytics_service.dart';
import '../../models/models.dart';
import '../../models/user_info.dart' as user_profile;
import '../../models/user_analytics.dart';
import '../../services/journal_data_service.dart';
import '../../features/journal/domain/journal_models.dart';
import '../../services/appointment_data_service.dart';
import '../../services/behavior_data_service.dart';
import '../../features/behavior/domain/behavior_log.dart';
import '../../services/companion_data_service.dart';
import '../../features/companions/domain/companion_session.dart';
import '../../services/cache_service.dart';
import '../../services/local_data_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

final mindWellRepositoryProvider = ChangeNotifierProvider<MindWellRepository>((
  ref,
) {
  final repository = MindWellRepository.instance;
  repository.seed();
  return repository;
});

final cacheServiceProvider = Provider<CacheService>((ref) {
  final cache = CacheService();
  ref.onDispose(cache.dispose);
  return cache;
});

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

final mindWellApiClientProvider = Provider<MindWellApiClient?>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.remoteBackendEnabled) {
    return null;
  }
  final client = MindWellApiClient(baseUrl: config.backendBaseUrl);
  ref.onDispose(client.dispose);
  return client;
});

final journalRemoteApiProvider = Provider<JournalRemoteApi?>((ref) {
  final client = ref.watch(mindWellApiClientProvider);
  if (client == null) {
    return null;
  }
  return JournalRemoteApi(client: client);
});

final companionRemoteApiProvider = Provider<CompanionRemoteApi?>((ref) {
  final client = ref.watch(mindWellApiClientProvider);
  if (client == null) {
    return null;
  }
  return CompanionRemoteApi(client: client);
});

final identityServiceProvider = Provider<IdentityService>(
  (ref) => IdentityService(),
);

final visitorIdProvider = FutureProvider<String>((ref) async {
  final service = ref.watch(identityServiceProvider);
  return service.ensureVisitorId();
});

final identityContextProvider = FutureProvider<IdentityContext>((ref) async {
  final service = ref.watch(identityServiceProvider);
  final visitorId = await ref.watch(visitorIdProvider.future);
  return service.composeIdentity(visitorId: visitorId);
});

final experimentServiceProvider = Provider<ExperimentService>(
  (ref) => ExperimentService(),
);

final experimentResolverProvider = FutureProvider<ExperimentResolver>((
  ref,
) async {
  final service = ref.watch(experimentServiceProvider);
  final visitorId = await ref.watch(visitorIdProvider.future);
  return ExperimentResolver(service: service, visitorId: visitorId);
});

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authServiceProvider).authStateChanges(),
);

final currentAppUserProvider = FutureProvider<AppUser?>(
  (ref) => ref.watch(authServiceProvider).getCurrentUser(),
);

final userDataServiceProvider = Provider<UserDataService>(
  (ref) => UserDataService(),
);

final usersProvider = StreamProvider<List<AppUser>>(
  (ref) => ref.watch(userDataServiceProvider).watchUsers(),
);

// ===== User Info Providers =====

final userInfoServiceProvider = Provider<UserInfoService>(
  (ref) => UserInfoService(),
);

/// Get current user's ID from local auth service
final currentUserIdProvider = FutureProvider<String?>((ref) async {
  final authService = ref.watch(authServiceProvider);
  final user = await authService.getCurrentUser();
  return user?.id;
});

/// Get UserInfo for current user
final currentUserInfoProvider = FutureProvider<user_profile.UserInfo?>((
  ref,
) async {
  final userId = await ref.watch(currentUserIdProvider.future);
  if (userId == null) {
    return null;
  }
  final userInfoService = ref.watch(userInfoServiceProvider);
  return userInfoService.getUserInfo(userId);
});

/// Watch UserInfo for real-time updates
final watchCurrentUserInfoProvider = StreamProvider<user_profile.UserInfo?>((
  ref,
) async* {
  final userId = await ref.watch(currentUserIdProvider.future);
  if (userId == null) {
    yield null;
    return;
  }
  final userInfoService = ref.watch(userInfoServiceProvider);
  yield* userInfoService.watchUserInfo(userId);
});

/// Get profile completeness score
final profileCompletenessProvider = FutureProvider<int>((ref) async {
  final userId = await ref.watch(currentUserIdProvider.future);
  if (userId == null) {
    return 0;
  }
  final userInfoService = ref.watch(userInfoServiceProvider);
  return userInfoService.getProfileCompletenessScore(userId);
});

// ===== User Analytics Providers =====

final userAnalyticsServiceProvider = Provider<UserAnalyticsService>(
  (ref) => UserAnalyticsService(),
);

final journalDataServiceProvider = Provider<JournalDataService>((ref) {
  final remoteApi = ref.watch(journalRemoteApiProvider);
  return JournalDataService(remoteApi: remoteApi);
});

final appointmentDataServiceProvider = Provider<AppointmentDataService>(
  (ref) => AppointmentDataService(),
);

final behaviorDataServiceProvider = Provider<BehaviorDataService>(
  (ref) => BehaviorDataService(),
);

final companionDataServiceProvider = Provider<CompanionDataService>((ref) {
  final remoteApi = ref.watch(companionRemoteApiProvider);
  return CompanionDataService(remoteApi: remoteApi);
});

final localDataRepositoryProvider = Provider<LocalDataRepository>((ref) {
  final cache = ref.watch(cacheServiceProvider);
  final userService = ref.watch(userDataServiceProvider);
  final userInfoService = ref.watch(userInfoServiceProvider);
  final journalService = ref.watch(journalDataServiceProvider);
  final behaviorService = ref.watch(behaviorDataServiceProvider);
  final appointmentService = ref.watch(appointmentDataServiceProvider);
  final companionService = ref.watch(companionDataServiceProvider);

  return LocalDataRepository(
    cacheService: cache,
    userService: userService,
    userInfoService: userInfoService,
    journalService: journalService,
    behaviorService: behaviorService,
    appointmentService: appointmentService,
    companionService: companionService,
  );
});

final journalEntriesProvider = StreamProvider<List<JournalEntry>>((ref) async* {
  final userId = await ref.watch(currentUserIdProvider.future);
  if (userId == null) {
    yield const <JournalEntry>[];
    return;
  }
  final service = ref.watch(journalDataServiceProvider);
  yield* service.watchEntries(userId);
});

final behaviorLogsProvider = StreamProvider.family<List<BehaviorLog>, String>((
  ref,
  userId,
) {
  final service = ref.watch(behaviorDataServiceProvider);
  return service.watchLogs(userId);
});

final companionSessionsProvider =
    StreamProvider.family<List<CompanionSessionSummary>, String>((ref, userId) {
      final service = ref.watch(companionDataServiceProvider);
      return service.watchSessions(userId, includeArchived: true);
    });

/// Get aggregated user analytics
final userAnalyticsProvider = FutureProvider<UserAnalytics>((ref) async {
  final userId = await ref.watch(currentUserIdProvider.future);
  if (userId == null) {
    throw Exception('User not authenticated');
  }

  final journalService = ref.watch(journalDataServiceProvider);
  final journalEntries = await journalService.fetchEntries(userId);
  JournalRepository.instance.replaceAll(journalEntries);
  final journalAnalytics = UserAnalyticsService.extractJournalAnalytics(
    journalEntries,
  );
  final behaviorService = ref.watch(behaviorDataServiceProvider);
  final behaviorLogs = await behaviorService.fetchLogs(userId);
  final behaviorAnalytics = UserAnalyticsService.extractBehaviorAnalytics(
    behaviorLogs,
  );
  final appointmentService = ref.watch(appointmentDataServiceProvider);
  final appointmentEntries = await appointmentService.fetchAppointments(userId);
  final appointmentAnalytics = UserAnalyticsService.extractAppointmentAnalytics(
    appointmentEntries,
  );
  final companionService = ref.watch(companionDataServiceProvider);
  final companionSessions = await companionService.fetchSessions(userId);
  final companionAnalytics = UserAnalyticsService.extractCompanionAnalytics(
    companionSessions,
  );

  return UserAnalyticsService.aggregateAnalytics(
    userId: userId,
    journal: journalAnalytics,
    behavior: behaviorAnalytics,
    appointments: appointmentAnalytics,
    companion: companionAnalytics,
  );
});
