import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Clean responsive layout matching the mobile developer screenshot design.
/// Includes top Ionet logo header bar, back button, and 450px desktop container.
class ResponsiveAuthCard extends StatelessWidget {
  final String title;
  final Widget child;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const ResponsiveAuthCard({
    super.key,
    required this.title,
    required this.child,
    this.showBackButton = false,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isDesktop = mediaQuery.size.width > 600;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 24.0 : 20.0,
              vertical: 20.0,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Top Ionet Header Bar with optional back button
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      if (showBackButton)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
                            onPressed: onBackPressed ?? () => Navigator.of(context).maybePop(),
                          ),
                        ),
                      // Image Ionet Brand Logo
                      Image.asset(
                        'assets/images/logo.png',
                        height: 64, // Adjust height as needed
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // Title ("Create Account", "Login", or "Complete Profile")
                  Padding(
                    padding: const EdgeInsets.only(bottom: 36.0),
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w400,
                            fontSize: 28,
                          ),
                    ),
                  ),

                  // Child Form Content
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
