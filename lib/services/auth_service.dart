import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../models/models.dart';
import 'local_data_store.dart';
import 'supabase_auth_service.dart';

class AuthException implements Exception {
  AuthException({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => 'AuthException($code, $message)';
}

/// Lightweight email/password auth service with Supabase integration.
/// Falls back to [LocalDataStore] when Supabase is not configured.
class AuthService {
  AuthService({LocalDataStore? store})
      : _store = store ?? LocalDataStore.instance {
    _initSupabase();
  }

  final LocalDataStore _store;
  final StreamController<AppUser?> _authController =
      StreamController<AppUser?>.broadcast();
  final Map<String, Map<String, dynamic>> _inviteCodes =
      <String, Map<String, dynamic>>{
    'CLINIC2024': {
      'role': Role.clinic,
      'expiresAt': DateTime.now().add(const Duration(days: 90)),
    },
    'ADMIN2024': {
      'role': Role.admin,
      'expiresAt': DateTime.now().add(const Duration(days: 90)),
    },
  };

  AppUser? _currentUser;
  SupabaseAuthService? _supabaseAuth;
  bool _useSupabase = false;

  void _initSupabase() {
    try {
      // Check if Supabase is initialized
      final _ = supa.Supabase.instance.client.auth.currentSession;
      _useSupabase = true;
      _supabaseAuth = SupabaseAuthService(store: _store);
      
      // Listen to Supabase auth state changes
      _supabaseAuth!.authStateChanges().listen((user) {
        _currentUser = user;
        _authController.add(user);
      });
    } catch (e) {
      // Supabase not initialized, use local auth
      _useSupabase = false;
      if (kDebugMode) {
        debugPrint('Supabase not configured, using local auth: $e');
      }
    }
  }

  /// Get current access token for API calls (Supabase JWT)
  String? get accessToken => _supabaseAuth?.accessToken;

  Stream<AppUser?> authStateChanges() {
    _authController.add(_currentUser);
    return _authController.stream;
  }

  Future<AppUser> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
    required Role role,
    String? inviteCode,
  }) async {
    if (displayName.trim().isEmpty) {
      throw AuthException(
        code: 'missing-display-name',
        message: 'Display name is required.',
      );
    }

    await _requireInviteIfNeeded(role: role, inviteCode: inviteCode);

    try {
      // Use Supabase if available
      if (_useSupabase && _supabaseAuth != null) {
        final user = await _supabaseAuth!.registerWithEmail(
          email: email,
          password: password,
          displayName: displayName,
          role: role,
          inviteCode: inviteCode,
        );
        _currentUser = user;
        _store.upsertUser(user);
        _markEmailPending(user.id);
        return user;
      }
    } on supa.AuthException catch (error) {
      throw AuthException(
        code: error.code ?? error.statusCode ?? 'supabase-error',
        message: error.message,
      );
    } catch (e) {
      throw AuthException(code: 'registration-error', message: e.toString());
    }

    // Fall back to local auth
    final existing = _store.findUserByEmail(email);
    if (existing != null) {
      throw AuthException(
        code: 'email-already-in-use',
        message: 'An account already exists for $email.',
      );
    }

    final user = _store.registerUser(
      email: email,
      password: password,
      displayName: displayName,
      role: role,
    );
    _currentUser = user;
    _authController.add(user);
    _scheduleAutoVerification(user.id);
    return user;
  }

  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      // Use Supabase if available
      if (_useSupabase && _supabaseAuth != null) {
        final user = await _supabaseAuth!.signInWithEmail(
          email: email,
          password: password,
        );
        _currentUser = user;
        _store.upsertUser(user);
        return user;
      }
    } on supa.AuthException catch (error) {
      throw AuthException(
        code: error.code ?? error.statusCode ?? 'supabase-error',
        message: error.message,
      );
    } catch (e) {
      throw AuthException(code: 'login-error', message: e.toString());
    }

    // Fall back to local auth
    final user = _store.authenticate(email: email, password: password);
    if (user == null) {
      throw AuthException(
        code: 'invalid-credentials',
        message: 'No account matched that email/password combination.',
      );
    }
    _currentUser = user;
    _store.setEmailVerification(
      user.id,
      verified: _store.isEmailVerified(user.id),
    );
    _authController.add(user);
    return user;
  }

  Future<void> signOut() async {
    if (_useSupabase && _supabaseAuth != null) {
      await _supabaseAuth!.signOut();
    }
    _currentUser = null;
    _authController.add(null);
  }

  Future<AppUser?> getCurrentUser() async {
    if (_useSupabase && _supabaseAuth != null) {
      return await _supabaseAuth!.getCurrentUser();
    }
    return _currentUser;
  }

  Future<void> sendEmailVerification() async {
    final user = _requireUser();
    if (_useSupabase && _supabaseAuth != null) {
      await _supabaseAuth!.sendEmailVerification();
      return;
    }
    _scheduleAutoVerification(user.id, reset: true);
    if (kDebugMode) {
      debugPrint('Simulating verification email for ${user.email}');
    }
  }

  Future<bool> isEmailVerified() async {
    final user = _requireUser();
    if (_useSupabase && _supabaseAuth != null) {
      return _supabaseAuth!.isEmailVerified();
    }
    return _store.isEmailVerified(user.id);
  }

  Future<bool> resendEmailVerification() async {
    final user = _requireUser();
    if (_useSupabase && _supabaseAuth != null) {
      await _supabaseAuth!.resendEmailVerification();
      return true;
    }
    if (_store.isEmailVerified(user.id)) {
      return false;
    }
    _scheduleAutoVerification(user.id, reset: true);
    return true;
  }

  Future<Map<String, dynamic>> validateInviteCode({
    required String code,
    required Role role,
  }) async {
    final formatted = code.trim().toUpperCase();
    final record = _inviteCodes[formatted];
    if (record == null) {
      throw AuthException(
        code: 'invalid-invite-code',
        message: 'The invite code you entered is not valid.',
      );
    }
    if (record['role'] != role) {
      throw AuthException(
        code: 'invalid-role',
        message: 'This invite code cannot be used for ${role.name} accounts.',
      );
    }
    final expiresAt = record['expiresAt'] as DateTime?;
    if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
      throw AuthException(
        code: 'expired-invite-code',
        message: 'This invite code has expired.',
      );
    }
    return {
      'id': formatted,
      'code': formatted,
      'role': role.name,
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }

  AppUser _requireUser() {
    final user = _currentUser;
    if (user == null) {
      throw AuthException(
        code: 'no-user',
        message: 'No authenticated user found.',
      );
    }
    return user;
  }

  void _scheduleAutoVerification(String userId, {bool reset = false}) {
    if (reset) {
      _markEmailPending(userId);
    }
    Future<void>.delayed(const Duration(seconds: 2), () {
      _store.setEmailVerification(userId, verified: true);
    });
  }

  void _markEmailPending(String userId) {
    _store.setEmailVerification(userId, verified: false);
  }

  Future<void> _requireInviteIfNeeded({
    required Role role,
    required String? inviteCode,
  }) async {
    if (role == Role.user) {
      return;
    }
    if (inviteCode == null || inviteCode.trim().isEmpty) {
      throw AuthException(
        code: 'missing-invite-code',
        message: 'Invite code is required for ${role.name} accounts.',
      );
    }
    await validateInviteCode(code: inviteCode, role: role);
  }
}
