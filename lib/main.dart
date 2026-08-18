// lib/main.dart
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/assessment/application/services/assessment_storage.dart';
import 'features/appointments/presentation/appointment_main_page.dart';
import 'features/behavior/presentation/behavior_tracker_page.dart';
import 'features/resources/presentation/my_resource_page.dart';
import 'features/companions/presentation/companions_page.dart';
import 'features/auth/presentation/role_selection_page.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/user/presentation/user_info_page.dart';
import 'features/landing/presentation/mindwell_landing_page.dart';
import 'design_system/tokens/color_tokens.dart';
import 'core/providers/app_providers.dart';
import 'core/routes/app_routes.dart';
import 'services/identity/identity_service.dart';
import 'services/local_data_store.dart';
import 'models/models.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseKey = String.fromEnvironment('SUPABASE_KEY');
  if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseKey,
    );
  } else if (kDebugMode) {
    // Keep the app usable locally when Supabase env vars aren't provided.
    debugPrint('Supabase env vars missing; skipping Supabase.initialize.');
  }

  await Hive.initFlutter();
  await AssessmentStorage.init();
  await LocalDataStore.instance.init();
  if (kIsWeb) {
    setUrlStrategy(PathUrlStrategy());
  }
  final prefs = await SharedPreferences.getInstance();
  final identityService = IdentityService(preferences: prefs);
  final visitorId = await identityService.ensureVisitorId();

  runApp(
    ProviderScope(
      overrides: [
        identityServiceProvider.overrideWithValue(identityService),
        visitorIdProvider.overrideWith((ref) async => visitorId),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MindWellApp(),
    ),
  );
}

class MindWellApp extends ConsumerStatefulWidget {
  const MindWellApp({super.key});

  @override
  ConsumerState<MindWellApp> createState() => _MindWellAppState();
}

class _MindWellAppState extends ConsumerState<MindWellApp> {
  bool _isDarkMode = false;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    ref.watch(identityContextProvider);
    ref.watch(experimentResolverProvider);

    final lightColorScheme = ColorScheme.fromSeed(
      seedColor: MindWellColors.darkGray,
      primary: MindWellColors.darkGray,
      secondary: MindWellColors.lightGreen,
      surface: Colors.white,
      background: MindWellColors.cream,
    );

    final darkColorScheme = ColorScheme.fromSeed(
      seedColor: MindWellColors.darkGray,
      brightness: Brightness.dark,
    );

    final lightTextTheme = _buildTextTheme(Brightness.light);
    final darkTextTheme = _buildTextTheme(Brightness.dark);

    void openRoleSelection() {
      _navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => RoleSelectionPage(
            isDarkMode: _isDarkMode,
            onThemeChanged: (value) => setState(() => _isDarkMode = value),
          ),
        ),
      );
    }

    void openAppointment() {
      _navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => AppointmentMainPage(
            onThemeChanged: (value) => setState(() => _isDarkMode = value),
            isDarkMode: _isDarkMode,
            userId: "100",
          ),
        ),
      );
    }

    void openCompanionsPreview() {
      _navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => CompanionsPage(
            isDarkMode: _isDarkMode,
            onThemeChanged: (value) => setState(() => _isDarkMode = value),
            isRegistered: false,
          ),
        ),
      );
    }

    return MaterialApp(
      navigatorKey: _navigatorKey,
      scrollBehavior: const _MindWellScrollBehavior(),
      title: config.environment == 'production'
          ? 'MindWell Clinic'
          : 'MindWell Clinic (${config.environment})',
      debugShowCheckedModeBanner: false,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: _buildTheme(
        colorScheme: lightColorScheme,
        textTheme: lightTextTheme,
        isDark: false,
      ),
      darkTheme: _buildTheme(
        colorScheme: darkColorScheme,
        textTheme: darkTextTheme,
        isDark: true,
      ),

      home: MindWellLandingPage(
        onOpenBooking: openAppointment,
        onOpenLogin: openRoleSelection,
        onOpenCompanionsPreview: openCompanionsPreview,
      ),

      // ===== 命名路由（可选用）=====
      routes: {
        AppRoutes.landing: (_) => MindWellLandingPage(
          onOpenBooking: openAppointment,
          onOpenLogin: openRoleSelection,
          onOpenCompanionsPreview: openCompanionsPreview,
        ),
        AppRoutes.roleSelection: (_) => RoleSelectionPage(
          isDarkMode: _isDarkMode,
          onThemeChanged: (v) => setState(() => _isDarkMode = v),
        ),
        AppRoutes.userLogin: (_) => LoginPage(
          role: Role.user,
          onThemeChanged: (v) => setState(() => _isDarkMode = v),
        ),
        AppRoutes.clinicLogin: (_) => LoginPage(
          role: Role.clinic,
          onThemeChanged: (v) => setState(() => _isDarkMode = v),
        ),
        AppRoutes.adminLogin: (_) => LoginPage(
          role: Role.admin,
          onThemeChanged: (v) => setState(() => _isDarkMode = v),
        ),
        AppRoutes.behavior: (_) => BehaviorTrackerPage(
          onThemeChanged: (v) => setState(() => _isDarkMode = v),
          isDarkMode: _isDarkMode,
        ),
        AppRoutes.appointment: (_) => AppointmentMainPage(
          onThemeChanged: (v) => setState(() => _isDarkMode = v),
          isDarkMode: _isDarkMode,
          userId: "100",
        ),
        AppRoutes.resources: (_) => MyResourcePage(
        onThemeChanged: (v) => setState(() => _isDarkMode = v),
        isDarkMode: _isDarkMode,
        ),
        AppRoutes.userProfile: (_) => UserInfoPage(
          onThemeChanged: (v) => setState(() => _isDarkMode = v),
        ),
      },
    );
  }

  TextTheme _buildTextTheme(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? GoogleFonts.latoTextTheme(ThemeData.dark().textTheme)
        : GoogleFonts.latoTextTheme();
    return base.copyWith(
      headlineLarge: GoogleFonts.openSans(
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
      titleMedium: GoogleFonts.openSans(fontWeight: FontWeight.w600),
      bodyLarge: GoogleFonts.lato(fontSize: 16, height: 1.6),
    );
  }

  ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required bool isDark,
  }) {
    final scaffoldColor = isDark
        ? const Color(0xFF1B1F1C)
        : MindWellColors.cream;
    final cardColor = isDark ? const Color(0xFF232825) : Colors.white;
    final primaryButtonBg = isDark
        ? MindWellColors.lightGreen
        : MindWellColors.darkGray;
    final primaryButtonFg = isDark
        ? MindWellColors.darkGray
        : MindWellColors.cream;
    final outlineColor = isDark
        ? MindWellColors.lightGreen
        : MindWellColors.darkGray;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: scaffoldColor,
      cardColor: cardColor,
      visualDensity: VisualDensity.standard,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryButtonBg,
          foregroundColor: primaryButtonFg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: outlineColor,
          side: BorderSide(color: outlineColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }
}

class _MindWellScrollBehavior extends MaterialScrollBehavior {
  const _MindWellScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.unknown,
  };
}
