import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'local_data_store.dart';

/// Supabase authentication service that integrates with existing auth system
class SupabaseAuthService {
  SupabaseAuthService({LocalDataStore? store});

  final StreamController<AppUser?> _authController =
      StreamController<AppUser?>.broadcast();

  AppUser? _currentUser;
  bool _isInitialized = false;

  /// Check if Supabase is configured
  bool get isEnabled => Supabase.instance.client.auth.currentSession != null ||
      _isInitialized;

  /// Get current access token for API calls
  String? get accessToken =>
      Supabase.instance.client.auth.currentSession?.accessToken;

  Stream<AppUser?> authStateChanges() {
    if (!_isInitialized) {
      _initializeAuthListener();
    }
    _authController.add(_currentUser);
    return _authController.stream;
  }

  void _initializeAuthListener() {
    _isInitialized = true;
    
    // Listen to Supabase auth state changes
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        _syncUserFromSupabase(session.user);
      } else {
        _currentUser = null;
        _authController.add(null);
      }
    });

    // Check for existing session
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      _syncUserFromSupabase(session.user);
    }
  }

  void _syncUserFromSupabase(User supabaseUser) {
    // Map Supabase user to AppUser
    final roleStr = supabaseUser.userMetadata?['role'] as String? ??
        supabaseUser.appMetadata['role'] as String? ??
        'user';
    
    Role role;
    try {
      role = Role.values.firstWhere(
        (r) => r.name == roleStr,
        orElse: () => Role.user,
      );
    } catch (_) {
      role = Role.user;
    }

    _currentUser = AppUser(
      id: supabaseUser.id,
      name: supabaseUser.userMetadata?['display_name'] as String? ??
          supabaseUser.email?.split('@').first ??
          'User',
      email: supabaseUser.email ?? '',
      role: role,
    );

    _authController.add(_currentUser);
  }

  Future<AppUser> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
    required Role role,
    String? inviteCode,
  }) async {
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'display_name': displayName,
          'role': role.name,
          if (inviteCode != null) 'invite_code': inviteCode,
        },
      );

      if (response.user == null) {
        throw Exception('Registration failed');
      }

      _syncUserFromSupabase(response.user!);
      return _currentUser!;
    } on AuthException catch (e) {
      throw Exception('Registration failed: ${e.message}');
    }
  }

  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Sign in failed');
      }

      _syncUserFromSupabase(response.user!);
      return _currentUser!;
    } on AuthException catch (e) {
      throw Exception('Sign in failed: ${e.message}');
    }
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
    _currentUser = null;
    _authController.add(null);
  }

  Future<AppUser?> getCurrentUser() async {
    if (_currentUser != null) {
      return _currentUser;
    }

    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      _syncUserFromSupabase(session.user);
      return _currentUser;
    }

    return null;
  }

  Future<void> sendEmailVerification() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw Exception('No user logged in');
    }

    // Supabase handles email verification automatically on signup
    await resendEmailVerification();
    if (kDebugMode) {
      debugPrint('Email verification sent to ${user.email}');
    }
  }

  Future<bool> isEmailVerified() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return false;
    }

    // Check if email is confirmed
    return user.emailConfirmedAt != null;
  }

  Future<void> resendEmailVerification() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('No user logged in');
    }
    await Supabase.instance.client.auth.resend(
      type: OtpType.signup,
      email: user.email!,
    );
  }

  Future<void> resetPassword(String email) async {
    await Supabase.instance.client.auth.resetPasswordForEmail(email);
  }

  Future<void> updatePassword(String newPassword) async {
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  Future<void> updateUserMetadata(Map<String, dynamic> metadata) async {
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(data: metadata),
    );
  }

  void dispose() {
    _authController.close();
  }
}
