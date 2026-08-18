import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/components/common_widgets.dart';
import '../../../design_system/tokens/color_tokens.dart';
import '../../../design_system/tokens/typography.dart';
import '../../../ui/elements/responsive_page_scaffold.dart';
import '../../../core/providers/app_providers.dart';
import '../../../services/auth_service.dart';
import '../../../models/models.dart';

class EmailVerificationPage extends ConsumerStatefulWidget {
  const EmailVerificationPage({
    super.key,
    required this.email,
    required this.user,
    required this.onVerified,
    required this.onThemeChanged,
  });

  final String email;
  final AppUser user;
  final VoidCallback onVerified;
  final ValueChanged<bool> onThemeChanged;

  @override
  ConsumerState<EmailVerificationPage> createState() =>
      _EmailVerificationPageState();
}

class _EmailVerificationPageState extends ConsumerState<EmailVerificationPage> {
  Timer? _autoCheckTimer;
  Timer? _resendCooldownTimer;
  bool _isChecking = false;
  bool _isResending = false;
  String? _errorMessage;
  int _resendCooldownSeconds = 0;
  int _checkAttempts = 0;
  static const int _maxCheckAttempts = 30; // 5 minutes with 10s interval

  AuthService get _authService => ref.read(authServiceProvider);

  @override
  void initState() {
    super.initState();
    _startAutoCheck();
  }

  @override
  void dispose() {
    _autoCheckTimer?.cancel();
    _resendCooldownTimer?.cancel();
    super.dispose();
  }

  void _startAutoCheck() {
    _autoCheckTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (mounted && _checkAttempts < _maxCheckAttempts) {
        await _checkEmailVerified();
      } else if (_checkAttempts >= _maxCheckAttempts && mounted) {
        _autoCheckTimer?.cancel();
        setState(() {
          _isChecking = false;
          _errorMessage =
              "Automatic checks paused after a few minutes. Tap 'I've Verified My Email' to try again or resend the email.";
        });
      }
    });
  }

  Future<void> _checkEmailVerified() async {
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
      _errorMessage = null;
      _checkAttempts++;
    });

    try {
      final isVerified = await _authService.isEmailVerified();
      if (!mounted) return;

      if (isVerified) {
        _autoCheckTimer?.cancel();
        // Show success dialog
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Email Verified'),
            content: const Text('Your email has been verified successfully. You can now access your dashboard.'),
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
        // Return true to signal successful verification
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() => _isChecking = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isChecking = false;
          _errorMessage = 'Failed to check verification status. Please try again.';
        });
        // Show error dialog for check failures
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Verification Check Failed'),
            content: const Text('Failed to check email verification status. Please check your internet connection and try again.'),
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
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (_isResending || _resendCooldownSeconds > 0) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      final sent = await _authService.resendEmailVerification();
      if (!mounted) return;

      if (sent) {
        setState(() {
          _isResending = false;
          _resendCooldownSeconds = 60;
        });
        _startResendCooldown();
        // Show success snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email resent. Check your inbox.'),
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        setState(() {
          _isResending = false;
          _errorMessage = 'Email already verified. You can continue.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isResending = false;
          _errorMessage = 'Failed to resend verification email. Please try again.';
        });
        // Show error dialog for resend failures
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Resend Failed'),
            content: const Text('Failed to resend verification email. Please check your internet connection and try again.'),
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
    }
  }

  void _startResendCooldown() {
    _resendCooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _resendCooldownSeconds--;
          if (_resendCooldownSeconds <= 0) {
            _resendCooldownTimer?.cancel();
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MindWellResponsiveScaffold(
      backgroundColor: MindWellColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: MindWellColors.darkGray),
          onPressed: () {
            // Pop without verification success
            Navigator.of(context).pop(false);
          },
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: MindWellColors.lightGreen.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mail_outline,
                    size: 40,
                    color: MindWellColors.lightGreen,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Title
              Text(
                'Verify Your Email',
                textAlign: TextAlign.center,
                style: MindWellTypography.sectionSubtitle(
                  color: MindWellColors.darkGray,
                ).copyWith(fontSize: 28),
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                'We\'ve sent a verification link to ${widget.email}. Click the link in your email to verify your account.',
                textAlign: TextAlign.center,
                style: MindWellTypography.body(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 32),

              // Auto-checking status
              if (_isChecking)
                Center(
                  child: Column(
                    children: [
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Checking verification status...',
                        style: MindWellTypography.body(
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

              // Error message
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: MindWellTypography.body(
                      color: Colors.red.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              if (!_isChecking) const SizedBox(height: 32),

              // Resend button
              ElevatedButton(
                onPressed: (_isResending || _resendCooldownSeconds > 0)
                    ? null
                    : _resendVerificationEmail,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 54),
                ),
                child: _isResending
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text(
                        _resendCooldownSeconds > 0
                            ? 'Resend Email ($_resendCooldownSeconds)s'
                            : 'Resend Verification Email',
                        style: MindWellTypography.button(
                          color: MindWellColors.cream,
                        ),
                      ),
              ),
              const SizedBox(height: 12),

              // Check manually button
              OutlinedButton(
                onPressed: _isChecking ? null : _checkEmailVerified,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 54),
                ),
                child: Text(
                  'I\'ve Verified My Email',
                  style: MindWellTypography.button(
                    color: MindWellColors.darkGray,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Troubleshooting',
                      style: MindWellTypography.body(
                        color: MindWellColors.darkGray,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• If you have not received the email, tap "Resend Verification Email", check spam, then tap "I\'ve Verified My Email" to refresh.',
                      style: MindWellTypography.body(
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• Network issues or "too many requests": switch networks or wait a minute before trying again.',
                      style: MindWellTypography.body(
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Hint text
              Text(
                'Checking automatically every 10 seconds',
                textAlign: TextAlign.center,
                style: MindWellTypography.body(
                  color: Colors.grey.shade500,
                ).copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const CopyrightBar(),
    );
  }
}
