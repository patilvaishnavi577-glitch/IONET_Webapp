import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/user_session_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_auth_card.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveAndContinue() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final sessionProvider = context.read<UserSessionProvider>();

    final success = await sessionProvider.completeProfile(
      name: _nameController.text.trim(),
      mobileNumber: _mobileController.text.trim(),
      countryCode: '+91',
    );

    if (success) {
      if (mounted) {
        context.go('/home');
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to complete profile. Please verify your connection or try again.'),
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
      title: 'Complete Profile',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Name Input Field (Matching developer screenshot 3 & 4)
            TextFormField(
              controller: _nameController,
              keyboardType: TextInputType.name,
              enabled: !isLoading,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Name',
                prefixIcon: Icon(
                  Icons.person_outline,
                  size: 22,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Mobile Number Input Field (Matching developer screenshot 3 & 4)
            TextFormField(
              controller: _mobileController,
              keyboardType: TextInputType.phone,
              enabled: !isLoading,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: const InputDecoration(
                labelText: 'Mobile Number',
                hintText: 'Mobile Number',
                prefixIcon: Icon(
                  Icons.phone_outlined,
                  size: 22,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter mobile number';
                }
                if (!RegExp(r'^\d{10}$').hasMatch(value.trim())) {
                  return 'Enter valid 10-digit mobile number';
                }
                return null;
              },
            ),
            const SizedBox(height: 36),

            // Centered "Complete Profile" Pill Button
            Center(
              child: ElevatedButton(
                onPressed: isLoading ? null : _handleSaveAndContinue,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(180, 48),
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
                        'Complete Profile',
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
