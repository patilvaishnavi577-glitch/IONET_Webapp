import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../config/api_config.dart';
import '../providers/theme_provider.dart';
import '../providers/user_session_provider.dart';
import 'help_view.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  bool _showHelp = false;
  bool _isEditingName = false;
  bool _isEditingPhone = false;
  bool _isAvatarHovered = false;
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = context.read<UserSessionProvider>().session;
      _nameController.text = session.fullName ?? '';
      _phoneController.text = session.mobileNumber ?? '';
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

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

  Future<void> _handleAvatarTap(
      BuildContext context, UserSessionProvider sessionProvider, bool isDark, Offset tapPosition) async {
    final hasAvatar = sessionProvider.session.profilePictureUrl != null;
    final size = MediaQuery.of(context).size;

    final menuBg = isDark ? const Color(0xFF202C33) : Colors.white;
    final menuText = isDark ? const Color(0xFFD1D7DB) : Colors.black87;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        tapPosition.dx,
        tapPosition.dy,
        size.width - tapPosition.dx,
        size.height - tapPosition.dy,
      ),
      color: menuBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: [
        if (hasAvatar)
          PopupMenuItem(
            value: 'view',
            child: Row(
              children: [
                Icon(Icons.visibility_outlined, color: menuText, size: 20),
                const SizedBox(width: 12),
                Text('View photo', style: TextStyle(color: menuText)),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'upload',
          child: Row(
            children: [
              Icon(Icons.photo_camera_outlined, color: menuText, size: 20),
              const SizedBox(width: 12),
              Text('Upload photo', style: TextStyle(color: menuText)),
            ],
          ),
        ),
        if (hasAvatar)
          PopupMenuItem(
            value: 'remove',
            child: Row(
              children: [
                Icon(Icons.delete_outline_outlined, color: Colors.redAccent, size: 20),
                const SizedBox(width: 12),
                const Text('Remove photo', style: TextStyle(color: Colors.redAccent)),
              ],
            ),
          ),
      ],
    ).then((value) async {
      if (value == null) return;
      if (value == 'view') {
        _viewPhotoDialog(context, sessionProvider.session.profilePictureUrl!);
      } else if (value == 'upload') {
        _pickAndUploadAvatar(sessionProvider);
      } else if (value == 'remove') {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            title: const Text('Remove Avatar'),
            content: const Text('Are you sure you want to remove your profile picture?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                child: const Text('Remove'),
              ),
            ],
          ),
        );

        if (confirmed != true) return;

        final success = await sessionProvider.deleteAvatar();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success ? 'Avatar removed successfully!' : 'Failed to remove avatar.'),
              backgroundColor: success ? Colors.green : Colors.redAccent,
            ),
          );
        }
      }
    });
  }

  Future<void> _pickAndUploadAvatar(UserSessionProvider sessionProvider) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;

      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to read file data.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      if (bytes.length > 5 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image size must be less than 5MB.'),
              backgroundColor: Colors.orangeAccent,
            ),
          );
        }
        return;
      }

      final success = await sessionProvider.uploadAvatar(
        bytes: bytes,
        filename: file.name,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Avatar uploaded successfully!' : 'Failed to upload avatar.'),
            backgroundColor: success ? Colors.green : Colors.redAccent,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error selecting or uploading image.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _saveProfileChanges(UserSessionProvider sessionProvider) async {
    final success = await sessionProvider.updateProfile(
      name: _nameController.text.trim(),
      mobileNumber: _phoneController.text.trim(),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Profile updated successfully!' : 'Failed to update profile.'),
          backgroundColor: success ? Colors.green : Colors.redAccent,
        ),
      );
    }
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

    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final sessionProvider = context.watch<UserSessionProvider>();
    final session = sessionProvider.session;

    // WhatsApp Web Colors
    final bgColor = isDark ? const Color(0xFF111B21) : const Color(0xFFF0F2F5);
    final sectionBgColor = isDark ? const Color(0xFF111B21) : Colors.white; 
    final headerColor = isDark ? const Color(0xFF202C33) : const Color(0xFF008069);
    final labelColor = isDark ? const Color(0xFF00A884) : const Color(0xFF008069);
    final textPrimary = isDark ? const Color(0xFFE9EDEF) : const Color(0xFF111B21);
    final textSecondary = isDark ? const Color(0xFF8696A0) : const Color(0xFF667781);
    final dividerColor = isDark ? const Color(0xFF202C33) : const Color(0xFFE9EDEF);

    return Container(
      color: bgColor,
      child: Column(
        children: [
          // Header
          Container(
            height: 108,
            width: double.infinity,
            color: headerColor,
            padding: const EdgeInsets.only(left: 20, bottom: 16),
            alignment: Alignment.bottomLeft,
            child: Row(
              children: [
                const SizedBox(width: 8),
                Text(
                  'Profile',
                  style: TextStyle(
                    color: isDark ? const Color(0xFFE9EDEF) : Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 28),
                  
                  // Avatar Section
                  GestureDetector(
                    onTapDown: (details) => _handleAvatarTap(context, sessionProvider, isDark, details.globalPosition),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      onEnter: (_) => setState(() => _isAvatarHovered = true),
                      onExit: (_) => setState(() => _isAvatarHovered = false),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 100,
                            backgroundColor: const Color(0xFFDFE5E7),
                            backgroundImage: session.profilePictureUrl != null
                                ? NetworkImage(session.profilePictureUrl!)
                                : null,
                            child: session.profilePictureUrl == null
                                ? const Icon(Icons.person, size: 120, color: Colors.white)
                                : null,
                          ),
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 150),
                            opacity: _isAvatarHovered ? 1.0 : 0.0,
                            child: Container(
                              width: 200,
                              height: 200,
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.camera_alt, color: Colors.white, size: 32),
                                  const SizedBox(height: 8),
                                  Text(
                                    session.profilePictureUrl != null ? 'CHANGE\nPROFILE PHOTO' : 'ADD\nPROFILE PHOTO',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Name Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                    color: sectionBgColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your name', style: TextStyle(color: labelColor, fontSize: 14)),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _isEditingName
                                  ? TextField(
                                      controller: _nameController,
                                      style: TextStyle(color: textPrimary, fontSize: 17),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding: const EdgeInsets.only(bottom: 8),
                                        border: UnderlineInputBorder(borderSide: BorderSide(color: labelColor)),
                                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: labelColor, width: 2)),
                                      ),
                                    )
                                  : Text(
                                      session.fullName ?? '',
                                      style: TextStyle(color: textPrimary, fontSize: 17),
                                    ),
                            ),
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: () {
                                if (_isEditingName) {
                                  _saveProfileChanges(sessionProvider);
                                }
                                setState(() {
                                  _isEditingName = !_isEditingName;
                                });
                              },
                              child: Icon(
                                _isEditingName ? Icons.check : Icons.edit,
                                color: textSecondary,
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'This is not your username or pin. This name will be visible to your Ionet contacts.',
                      style: TextStyle(color: textSecondary, fontSize: 14),
                    ),
                  ),

                  // Email Section (Read-only)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                    color: sectionBgColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Email address', style: TextStyle(color: labelColor, fontSize: 14)),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                session.email ?? '',
                                style: TextStyle(color: textSecondary, fontSize: 17),
                              ),
                            ),
                            const Icon(Icons.lock_outline, color: Colors.grey, size: 20),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  Divider(color: dividerColor, height: 1, thickness: 1),

                  // Phone Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                    color: sectionBgColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mobile number', style: TextStyle(color: labelColor, fontSize: 14)),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _isEditingPhone
                                  ? TextField(
                                      controller: _phoneController,
                                      style: TextStyle(color: textPrimary, fontSize: 17),
                                      keyboardType: TextInputType.phone,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding: const EdgeInsets.only(bottom: 8),
                                        border: UnderlineInputBorder(borderSide: BorderSide(color: labelColor)),
                                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: labelColor, width: 2)),
                                      ),
                                    )
                                  : Text(
                                      session.mobileNumber ?? '',
                                      style: TextStyle(color: textPrimary, fontSize: 17),
                                    ),
                            ),
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: () {
                                if (_isEditingPhone) {
                                  _saveProfileChanges(sessionProvider);
                                }
                                setState(() {
                                  _isEditingPhone = !_isEditingPhone;
                                });
                              },
                              child: Icon(
                                _isEditingPhone ? Icons.check : Icons.edit,
                                color: textSecondary,
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Help
                  Container(
                    color: sectionBgColor,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 4),
                      title: Text(
                        'Help',
                        style: TextStyle(color: textPrimary, fontSize: 16),
                      ),
                      leading: Icon(Icons.help_outline, color: textSecondary),
                      onTap: () {
                        setState(() {
                          _showHelp = true;
                        });
                      },
                    ),
                  ),

                  Divider(color: dividerColor, height: 1, thickness: 1),

                  // Theme Toggle
                  Container(
                    color: sectionBgColor,
                    child: SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 30),
                      title: Text(
                        'Dark Theme',
                        style: TextStyle(color: textPrimary, fontSize: 16),
                      ),
                      value: isDark,
                      activeTrackColor: labelColor.withValues(alpha: 0.5),
                      activeThumbColor: labelColor,
                      onChanged: (val) {
                        themeProvider.toggleTheme(val);
                      },
                    ),
                  ),

                  Divider(color: dividerColor, height: 1, thickness: 1),

                  // Logout
                  Container(
                    color: sectionBgColor,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 4),
                      title: const Text(
                        'Log out',
                        style: TextStyle(color: Colors.redAccent, fontSize: 16),
                      ),
                      leading: const Icon(Icons.logout, color: Colors.redAccent),
                      onTap: () {
                        context.read<UserSessionProvider>().logout();
                        context.go('/auth');
                      },
                    ),
                  ),
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
