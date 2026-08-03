import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/user_session_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_auth_card.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final sessionProvider = context.read<UserSessionProvider>();
    final email = _emailController.text.trim();

    final success = await sessionProvider.sendOtp(
      email: email,
      isRegisterMode: false,
    );

    if (success) {
      if (mounted) {
        context.go('/verify-otp');
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to request OTP. Please verify your connection or try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionProvider = context.watch<UserSessionProvider>();
    final isLoading = sessionProvider.isLoading;

    return ResponsiveAuthCard(
      title: 'Login',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Email Input Field
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              enabled: !isLoading,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'Email',
                prefixIcon: Icon(
                  Icons.email_outlined,
                  size: 22,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your email address';
                }
                if (!_emailRegex.hasMatch(value.trim())) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 36),

            // Centered "Send OTP" Pill Button
            Center(
              child: ElevatedButton(
                onPressed: isLoading ? null : _handleSendOtp,
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
                        'Send OTP',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
