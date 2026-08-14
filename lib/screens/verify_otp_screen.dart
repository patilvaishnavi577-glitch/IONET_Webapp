import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/user_session_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_auth_card.dart';

class VerifyOtpScreen extends StatefulWidget {
  const VerifyOtpScreen({super.key});

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  int _secondsRemaining = 120;
  Timer? _timer;
  bool _canResend = false;
  String? _errorMessage;

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final secondsStr = seconds.toString().padLeft(2, '0');
    return '$minutes:$secondsStr';
  }

  @override
  void initState() {
    super.initState();
    _startCountdownTimer();
  }

  void _startCountdownTimer() {
    setState(() {
      _secondsRemaining = 120;
      _canResend = false;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        setState(() {
          _secondsRemaining = 0;
          _canResend = true;
        });
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _handleVerifyOtp() async {
    final otpText = _otpController.text.trim();
    if (otpText.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the OTP code';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
    });

    final sessionProvider = context.read<UserSessionProvider>();
    final isNewUser = await sessionProvider.verifyOtp(otpText);

    if (mounted) {
      if (sessionProvider.otpVerified) {
        if (isNewUser) {
          context.go('/complete-profile');
        } else {
          context.go('/home');
        }
      } else {
        setState(() {
          _errorMessage = 'Invalid or expired OTP code. Please try again.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification failed. Please enter the correct OTP code.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _handleResendCode() {
    if (!_canResend) return;

    _startCountdownTimer();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 12),
            Text('A new OTP code has been sent!'),
          ],
        ),
        backgroundColor: AppTheme.buttonBg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionProvider = context.watch<UserSessionProvider>();
    final isLoading = sessionProvider.isLoading;
    final userEmail = sessionProvider.email ?? 'user@example.com';

    return ResponsiveAuthCard(
      title: 'Login',
      showBackButton: true,
      onBackPressed: () => context.go('/auth'),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // 1. Email Field (Disabled / ReadOnly matching screenshot 2)
            TextFormField(
              initialValue: userEmail,
              readOnly: true,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.textPrimary
                    : AppTheme.textPrimaryLight,
                fontSize: 16,
              ),
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined, size: 22),
              ),
            ),
            const SizedBox(height: 20),

            // 2. OTP Field (With Lock Icon matching screenshot 2)
            TextFormField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              enabled: !isLoading,
              autofocus: true,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.textPrimary
                    : AppTheme.textPrimaryLight,
                fontSize: 16,
                letterSpacing: 2,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: const InputDecoration(
                labelText: 'OTP',
                hintText: 'OTP',
                prefixIcon: Icon(Icons.lock_outline, size: 22),
              ),
              onFieldSubmitted: (_) => _handleVerifyOtp(),
            ),
            const SizedBox(height: 16),

            // Error validation message if present
            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppTheme.errorColor, fontSize: 13),
              ),
              const SizedBox(height: 16),
            ],

            // 3. Centered "Verify OTP" Pill Button
            Center(
              child: ElevatedButton(
                onPressed: isLoading ? null : _handleVerifyOtp,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(160, 48),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Verify OTP',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 28),



            // Resend Code timer
            Center(
              child: _canResend
                  ? TextButton(
                      onPressed: isLoading ? null : _handleResendCode,
                      child: Text(
                        'Resend OTP',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.textSecondary
                              : AppTheme.textSecondaryLight,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    )
                  : Text(
                      'Resend in ${_formatTime(_secondsRemaining)}',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.textMuted
                            : AppTheme.textMutedLight,
                        fontSize: 13,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
