import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_mhproj/design_system/components/common_widgets.dart';
import 'package:flutter_application_mhproj/design_system/tokens/color_tokens.dart';
import 'package:flutter_application_mhproj/design_system/tokens/typography.dart';
import 'package:flutter_application_mhproj/features/clinic/presentation/clinic_dashboard_page.dart';
import 'package:flutter_application_mhproj/features/user/presentation/user_main_page.dart';
import 'package:flutter_application_mhproj/features/admin/presentation/admin_dashboard_page.dart';
import 'package:flutter_application_mhproj/features/auth/presentation/email_verification_page.dart';
import 'package:flutter_application_mhproj/models/models.dart';
import 'package:flutter_application_mhproj/ui/elements/responsive_page_scaffold.dart';
import 'package:flutter_application_mhproj/core/providers/app_providers.dart';
import 'package:flutter_application_mhproj/services/auth_service.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({
    super.key,
    required this.role,
    required this.onThemeChanged,
  });
  final Role role;
  final ValueChanged<bool> onThemeChanged;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _inviteCodeController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isRegisterMode = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  AuthService get _authService => ref.read(authServiceProvider);

  String get _title => switch (widget.role) {
    Role.user => _isRegisterMode ? 'User Registration' : 'User Login',
    Role.clinic => _isRegisterMode ? 'Clinic Registration' : 'Clinic Login',
    Role.admin => _isRegisterMode ? 'Admin Registration' : 'Admin Login',
  };

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final displayName = _nameController.text.trim();
    final inviteCode = widget.role != Role.user
        ? _inviteCodeController.text.trim()
        : null;
    try {
      AppUser user;
      if (_isRegisterMode) {
        // Registration flow
        try {
          user = await _authService.registerWithEmail(
            email: email,
            password: password,
            displayName: displayName,
            role: widget.role,
            inviteCode: inviteCode,
          );
        } catch (e) {
          final authError = e is AuthException
              ? e
              : AuthException(
                  code: 'registration-error',
                  message: e.toString(),
                );
          if (mounted) {
            await _showErrorDialog(
              title: 'Registration Failed',
              message: _mapAuthError(authError),
            );
          }
          setState(() => _isSubmitting = false);
          return;
        }

        // Show success dialog
        if (mounted) {
          await _showSuccessDialog(
            title: 'Registration Successful',
            message: 'Your account has been created. Please verify your email to continue.',
          );
        }

        // Navigate to email verification page
        if (mounted) {
          final verificationResult = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => EmailVerificationPage(
                email: email,
                user: user,
                onVerified: () {
                  Navigator.of(context).pop(true); // Return true on successful verification
                },
                onThemeChanged: widget.onThemeChanged,
              ),
            ),
          );

          // If verification was successful, navigate to dashboard
          if (verificationResult == true && mounted) {
            await _navigateToRole(user);
          } else if (mounted) {
            // User cancelled verification; clear auth state and stay on login
            await _authService.signOut();
            setState(() => _isSubmitting = false);
          }
        }
        return;
      } else {
        // Login flow
        try {
          user = await _authService.signInWithEmail(
            email: email,
            password: password,
          );
        } catch (e) {
          final authError = e is AuthException
              ? e
              : AuthException(
                  code: 'login-error',
                  message: e.toString(),
                );
          if (mounted) {
            await _showErrorDialog(
              title: 'Login Failed',
              message: _mapAuthError(authError),
            );
          }
          setState(() => _isSubmitting = false);
          return;
        }

        // Check if email is verified on login
        bool isVerified = false;
        try {
          isVerified = await _authService.isEmailVerified();
        } catch (e) {
          if (mounted) {
            await _showErrorDialog(
              title: 'Verification Check Failed',
              message: 'Failed to check email verification status. Please try again.',
            );
          }
          // Sign out on verification check failure
          await _authService.signOut();
          setState(() => _isSubmitting = false);
          return;
        }

        if (!isVerified && mounted) {
          // Show verification required dialog
          await _showInfoDialog(
            title: 'Email Verification Required',
            message: 'Please verify your email before accessing the app.',
          );
          
          // Navigate to email verification page
          if (mounted) {
            final verificationResult = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => EmailVerificationPage(
                  email: email,
                  user: user,
                  onVerified: () {
                    Navigator.of(context).pop(true); // Return true on successful verification
                  },
                  onThemeChanged: widget.onThemeChanged,
                ),
              ),
            );

            // If verification was successful, navigate to dashboard
            if (verificationResult == true && mounted) {
              await _navigateToRole(user);
            } else if (mounted) {
              // User cancelled verification; clear auth state before returning
              await _authService.signOut();
              setState(() => _isSubmitting = false);
            }
          }
          return;
        }
      }

      if (user.role != widget.role) {
        await _authService.signOut();
        if (mounted) {
          await _showErrorDialog(
            title: 'Wrong Portal',
            message: 'This account is registered for the ${_roleLabel(user.role)} portal. Please switch to the appropriate login.',
          );
        }
        setState(() => _isSubmitting = false);
        return;
      }

      await _navigateToRole(user);
    } on AuthException catch (e) {
      if (mounted) {
        await _showErrorDialog(
          title: 'Authentication Failed',
          message: _mapAuthError(e),
        );
      }
    } catch (e) {
      if (mounted) {
        await _showErrorDialog(
          title: 'Error',
          message: 'An unexpected error occurred. Please try again.',
        );
      }
      if (kDebugMode) {
        debugPrint('Unexpected error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _navigateToRole(AppUser user) async {
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    late final Widget target;
    switch (widget.role) {
      case Role.user:
        target = UserMainPage(
          userName: user.name.isNotEmpty ? user.name : user.email,
          isDarkMode: isDark,
          onThemeChanged: widget.onThemeChanged,
        );
        break;
      case Role.clinic:
        target = ClinicDashboardPage(onThemeChanged: widget.onThemeChanged);
        break;
      case Role.admin:
        target = AdminDashboardPage(onThemeChanged: widget.onThemeChanged);
        break;
    }
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => target),
      (route) => route.isFirst,
    );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w.+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  String? _validateName(String? value) {
    if (!_isRegisterMode) {
      return null;
    }
    final name = value?.trim() ?? '';
    if (name.isEmpty) {
      return 'Display name is required';
    }
    return null;
  }

  String? _validateConfirmation(String? value) {
    if (!_isRegisterMode) {
      return null;
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  String? _validateInviteCode(String? value) {
    if (!_isRegisterMode || widget.role == Role.user) {
      return null;
    }
    final code = value?.trim() ?? '';
    if (code.isEmpty) {
      return 'Invite code is required for ${_roleLabel(widget.role)} registration';
    }
    if (code.length < 10) {
      return 'Invite code must be at least 10 characters';
    }
    return null;
  }

  String _roleLabel(Role role) => switch (role) {
    Role.user => 'user',
    Role.clinic => 'clinic',
    Role.admin => 'admin',
  };

  String _mapAuthError(AuthException exception) {
    switch (exception.code) {
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'invalid-email':
        return 'The email address appears to be invalid.';
      case 'invalid-credentials':
      case 'invalid_credentials':
        return 'Incorrect email or password.';
      case 'user-not-found':
      case 'wrong-password':
        return 'Incorrect email or password.';
      case 'email-not-confirmed':
      case 'email_not_confirmed':
        return 'Please verify your email before continuing. You can resend the verification email from the next screen.';
      case 'network-request-failed':
        return 'Network problem detected. Check your connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a minute before trying again.';
      case 'weak-password':
        return 'Please choose a stronger password.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled for this project.';
      case 'missing-invite-code':
        return 'Invite code is required to register for this portal.';
      case 'invalid-invite-code':
        return 'The invite code is not valid for this portal.';
      case 'expired-invite-code':
        return 'This invite code has expired.';
      case 'used-invite-code':
        return 'This invite code has already been used.';
      case 'invalid-role':
        return 'This invite code does not match the selected role.';
      case 'missing-display-name':
        return 'Display name is required to continue.';
      case 'supabase-error':
        return 'Authentication service error: ${exception.message}';
      default:
        return exception.message ?? 'Authentication failed. Please try again.';
    }
  }

  /// Show error dialog with Material Design
  Future<void> _showErrorDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF232825)
            : Colors.white,
        titleTextStyle: MindWellTypography.sectionSubtitle(
          color: Colors.red.shade700,
        ).copyWith(fontSize: 18),
        contentTextStyle: MindWellTypography.body(
          color: Colors.grey.shade700,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: MindWellTypography.button(color: MindWellColors.darkGray),
            ),
          ),
        ],
      ),
    );
  }

  /// Show info dialog for informational messages
  Future<void> _showInfoDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF232825)
            : Colors.white,
        titleTextStyle: MindWellTypography.sectionSubtitle(
          color: MindWellColors.lightGreen,
        ).copyWith(fontSize: 18),
        contentTextStyle: MindWellTypography.body(
          color: Colors.grey.shade700,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: MindWellTypography.button(color: MindWellColors.darkGray),
            ),
          ),
        ],
      ),
    );
  }

  /// Show success dialog
  Future<void> _showSuccessDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF232825)
            : Colors.white,
        titleTextStyle: MindWellTypography.sectionSubtitle(
          color: MindWellColors.lightGreen,
        ).copyWith(fontSize: 18),
        contentTextStyle: MindWellTypography.body(
          color: Colors.grey.shade700,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Continue',
              style: MindWellTypography.button(color: MindWellColors.lightGreen),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MindWellResponsiveScaffold(
      backgroundColor: MindWellColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _title,
          style: MindWellTypography.sectionSubtitle(
            color: MindWellColors.darkGray,
          ).copyWith(fontSize: 22),
        ),
        actions: [
          Switch(value: isDark, onChanged: widget.onThemeChanged),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(isDark ? '☾' : '☀'),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isRegisterMode ? 'Create your account' : 'Secure access',
                  textAlign: TextAlign.center,
                  style: MindWellTypography.sectionSubtitle(
                    color: MindWellColors.darkGray,
                  ).copyWith(fontSize: 28),
                ),
                const SizedBox(height: 10),
                Text(
                  _isRegisterMode
                      ? 'Fill in the details below to get started with MindWell.'
                      : 'Enter your credentials to continue to the MindWell experience.',
                  textAlign: TextAlign.center,
                  style: MindWellTypography.body(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 32),
                if (_isRegisterMode) ...[
                  InputCard(
                    child: TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Display Name',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                        labelStyle: MindWellTypography.body(
                          color: MindWellColors.darkGray,
                        ),
                      ),
                      validator: _validateName,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                InputCard(
                  child: TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                      labelStyle: MindWellTypography.body(
                        color: MindWellColors.darkGray,
                      ),
                    ),
                    validator: _validateEmail,
                  ),
                ),
                const SizedBox(height: 16),
                InputCard(
                  child: TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: _isRegisterMode
                        ? TextInputAction.next
                        : TextInputAction.done,
                    onFieldSubmitted: (_) =>
                        _isRegisterMode ? null : _handleSubmit(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: MindWellColors.darkGray,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      labelStyle: MindWellTypography.body(
                        color: MindWellColors.darkGray,
                      ),
                    ),
                    validator: _validatePassword,
                  ),
                ),
                if (_isRegisterMode) ...[
                  const SizedBox(height: 16),
                  InputCard(
                    child: TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _handleSubmit(),
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: MindWellColors.darkGray,
                          ),
                          onPressed: () => setState(
                            () => _obscureConfirmPassword =
                                !_obscureConfirmPassword,
                          ),
                        ),
                        labelStyle: MindWellTypography.body(
                          color: MindWellColors.darkGray,
                        ),
                      ),
                      validator: _validateConfirmation,
                    ),
                  ),
                  if (widget.role != Role.user) ...[
                    const SizedBox(height: 16),
                    InputCard(
                      child: TextFormField(
                        controller: _inviteCodeController,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'Invite Code',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                          hintText: 'Enter your ${_roleLabel(widget.role)} invite code',
                          hintStyle: MindWellTypography.body(
                            color: Colors.grey.shade400,
                          ),
                          labelStyle: MindWellTypography.body(
                            color: MindWellColors.darkGray,
                          ),
                        ),
                        validator: _validateInviteCode,
                      ),
                    ),
                  ]
                ],
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: MindWellTypography.body(color: Colors.red.shade600),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 54),
                  ),
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Text(
                          (_isRegisterMode ? 'Register' : 'Login')
                              .toUpperCase(),
                          style: MindWellTypography.button(
                            color: MindWellColors.cream,
                          ).copyWith(fontSize: 14),
                        ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          setState(() {
                            _isRegisterMode = !_isRegisterMode;
                            _errorMessage = null;
                          });
                        },
                  child: Text(
                    _isRegisterMode
                        ? 'Already have an account? Login'
                        : 'Need an account? Register',
                    style: MindWellTypography.body(
                      color: MindWellColors.darkGray,
                    ),
                  ),
                ),
                if (!_isRegisterMode)
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password reset coming soon'),
                            ),
                          ),
                    child: Text(
                      'Forgot Password?',
                      style: MindWellTypography.body(
                        color: MindWellColors.darkGray,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    'If you picked the wrong portal or left email verification and were signed out, log in again with the same email to resume verification or switch to the correct portal.',
                    style: MindWellTypography.body(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const CopyrightBar(),
    );
  }
}
