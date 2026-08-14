import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../providers/theme_provider.dart';
import '../providers/user_session_provider.dart';
import 'help_view.dart';
import 'account_profile_view.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  bool _showHelp = false;
  bool _showAccountProfile = false;

  void _viewPhotoDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showHelp) {
      return HelpView(
        onBack: () {
          setState(() {
            _showHelp = false;
          });
        },
      );
    }

    if (_showAccountProfile) {
      return AccountProfileView(
        onBack: () {
          setState(() {
            _showAccountProfile = false;
          });
        },
      );
    }

    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final sessionProvider = context.watch<UserSessionProvider>();
    final session = sessionProvider.session;

    // WhatsApp Web Colors
    final bgColor = isDark ? const Color(0xFF111B21) : const Color(0xFFF0F2F5);
    final headerColor = isDark ? const Color(0xFF202C33) : const Color(0xFF008069);
    final textPrimary = isDark ? const Color(0xFFE9EDEF) : const Color(0xFF111B21);
    final textSecondary = isDark ? const Color(0xFF8696A0) : const Color(0xFF667781);
    final dividerColor = isDark ? const Color(0xFF202C33) : const Color(0xFFE9EDEF);
    final labelColor = isDark ? const Color(0xFF00A884) : const Color(0xFF008069);

    return Material(
      color: bgColor,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Row(
              children: [
                Text(
                  'Profile',
                  style: TextStyle(
                    color: isDark ? const Color(0xFFE9EDEF) : const Color(0xFF111B21),
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  
                  // Avatar Section (View Only)
                  GestureDetector(
                    onTap: () {
                      if (session.profilePictureUrl != null) {
                        _viewPhotoDialog(context, session.profilePictureUrl!);
                      }
                    },
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFF00695C),
                      backgroundImage: session.profilePictureUrl != null
                          ? NetworkImage(session.profilePictureUrl!)
                          : null,
                      child: session.profilePictureUrl == null
                          ? const Icon(Icons.person, size: 60, color: Colors.white)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Name and Status
                  Text(
                    session.fullName ?? 'player',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF005C4B).withValues(alpha: 0.3)
                          : const Color(0xFFD9FDD3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.attach_money,
                          size: 18,
                          color: isDark
                              ? const Color(0xFF00A884)
                              : const Color(0xFF008069),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '1000',
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFF00A884)
                                : const Color(0xFF008069),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  Divider(color: dividerColor, height: 1, thickness: 1),

                  // Account Profile Option
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    leading: Icon(Icons.person_outline, color: textSecondary, size: 28),
                    title: Text('Account Profile', style: TextStyle(color: textPrimary, fontSize: 16)),
                    subtitle: Text('Privacy, security, change number', style: TextStyle(color: textSecondary, fontSize: 13)),
                    onTap: () {
                      setState(() {
                        _showAccountProfile = true;
                      });
                    },
                  ),
                  
                  Divider(color: dividerColor, height: 1, thickness: 1),

                  // Toggle Theme Option
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    leading: Icon(
                      isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                      color: textSecondary,
                      size: 28,
                    ),
                    title: Text('Toggle Theme', style: TextStyle(color: textPrimary, fontSize: 16)),
                    subtitle: Text(isDark ? 'Dark Mode' : 'Light Mode', style: TextStyle(color: textSecondary, fontSize: 13)),
                    trailing: Switch(
                      value: isDark,
                      activeTrackColor: labelColor.withValues(alpha: 0.5),
                      activeThumbColor: labelColor,
                      onChanged: (val) {
                        themeProvider.toggleTheme(val);
                      },
                    ),
                    onTap: () {
                      themeProvider.toggleTheme(!isDark);
                    },
                  ),
                  
                  Divider(color: dividerColor, height: 1, thickness: 1),

                  // Help Option
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    leading: Icon(Icons.help_outline, color: textSecondary, size: 28),
                    title: Text('Help', style: TextStyle(color: textPrimary, fontSize: 16)),
                    subtitle: Text('Help center, contact us, privacy policy', style: TextStyle(color: textSecondary, fontSize: 13)),
                    onTap: () {
                      setState(() {
                        _showHelp = true;
                      });
                    },
                  ),
                  
                  Divider(color: dividerColor, height: 1, thickness: 1),

                  // Logout Option
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    leading: const Icon(Icons.logout, color: Colors.redAccent, size: 28),
                    title: const Text('Logout', style: TextStyle(color: Colors.redAccent, fontSize: 16)),
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (dialogCtx) {
                          return AlertDialog(
                            backgroundColor: isDark ? const Color(0xFF1D222B) : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isDark ? const Color(0xFF2A3942) : const Color(0xFFDFE5E7),
                                width: 1,
                              ),
                            ),
                            title: Text(
                              'Logout',
                              style: TextStyle(
                                color: isDark ? const Color(0xFFE9EDEF) : const Color(0xFF111B21),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            content: Text(
                              'Are you sure you want to log out?',
                              style: TextStyle(
                                color: isDark ? const Color(0xFF8696A0) : const Color(0xFF667781),
                                fontSize: 14,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(dialogCtx).pop(false),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFF8696A0) : const Color(0xFF667781),
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                ),
                                onPressed: () => Navigator.of(dialogCtx).pop(true),
                                child: const Text(
                                  'Logout',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          );
                        },
                      );

                      if (confirm == true && context.mounted) {
                        context.read<UserSessionProvider>().logout();
                        context.go('/auth');
                      }
                    },
                  ),
                  
                  Divider(color: dividerColor, height: 1, thickness: 1),

                  const SizedBox(height: 32),
                  Center(
                    child: Text(
                      'Version ${ApiConfig.appVersion}',
                      style: TextStyle(
                        color: textSecondary.withValues(alpha: 0.35),
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
