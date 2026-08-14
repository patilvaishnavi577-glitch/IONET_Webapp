import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../providers/theme_provider.dart';
import '../providers/user_session_provider.dart';
import '../utils/toast_service.dart';

class AccountProfileView extends StatefulWidget {
  final VoidCallback onBack;

  const AccountProfileView({super.key, required this.onBack});

  @override
  State<AccountProfileView> createState() => _AccountProfileViewState();
}

class _AccountProfileViewState extends State<AccountProfileView> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isSaving = false;

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
          ToastService.show(context, 'Failed to read file data.', isError: true);
        }
        return;
      }

      if (bytes.length > 5 * 1024 * 1024) {
        if (mounted) {
          ToastService.show(context, 'Image size must be less than 5MB.', isError: true);
        }
        return;
      }

      final success = await sessionProvider.uploadAvatar(
        bytes: bytes,
        filename: file.name,
      );

      if (mounted) {
        ToastService.show(context, success ? 'Avatar uploaded successfully!' : 'Failed to upload avatar.', isError: !success);
      }
    } catch (_) {
      if (mounted) {
        ToastService.show(context, 'Error selecting or uploading image.', isError: true);
      }
    }
  }

  Future<void> _saveChanges(UserSessionProvider sessionProvider) async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      ToastService.show(context, 'Name cannot be empty.', isError: true);
      return;
    }

    if (phone.isNotEmpty && phone.length != 10) {
      ToastService.show(context, 'Mobile number must be exactly 10 digits.', isError: true);
      return;
    }

    setState(() {
      _isSaving = true;
    });
    
    final success = await sessionProvider.updateProfile(
      name: name,
      mobileNumber: phone,
    );
    
    if (mounted) {
      setState(() {
        _isSaving = false;
      });
      ToastService.show(context, success ? 'Profile updated successfully!' : 'Failed to update profile.', isError: !success);
    }
  }

  Widget _buildTextField(
    String label,
    IconData icon,
    TextEditingController? controller, {
    bool readOnly = false,
    String? initialValue,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    
    final inputBg = isDark ? const Color(0xFF202C33) : Colors.white;
    final textSecondary = isDark ? const Color(0xFF8696A0) : const Color(0xFF667781);
    final primaryTextColor = isDark ? const Color(0xFFE9EDEF) : const Color(0xFF111B21);
    final accentGreen = isDark ? const Color(0xFF00A884) : const Color(0xFF008069);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3942) : const Color(0xFFDFE5E7),
          width: 1.5,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: accentGreen,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(icon, color: textSecondary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: readOnly
                    ? Text(
                        initialValue ?? '',
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    : TextField(
                        controller: controller,
                        keyboardType: keyboardType,
                        inputFormatters: inputFormatters,
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: const InputDecoration(
                          filled: false,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          enabledBorder: InputBorder.none,
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final sessionProvider = context.watch<UserSessionProvider>();
    final session = sessionProvider.session;

    final bgColor = isDark ? const Color(0xFF111B21) : const Color(0xFFF0F2F5);
    final headerColor = isDark ? const Color(0xFF202C33) : const Color(0xFF008069);
    final textPrimary = isDark ? const Color(0xFFE9EDEF) : Colors.white;

    return Container(
      color: bgColor,
      child: Column(
        children: [
          // Header
          Container(
            height: 108,
            width: double.infinity,
            color: headerColor,
            padding: const EdgeInsets.only(left: 10, bottom: 16),
            alignment: Alignment.bottomLeft,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: textPrimary),
                  onPressed: widget.onBack,
                ),
                const SizedBox(width: 8),
                Text(
                  'Profile',
                  style: TextStyle(
                    color: textPrimary,
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
                  const SizedBox(height: 40),
                  
                  // Avatar with Camera Icon Overlay
                  GestureDetector(
                    onTap: () => _pickAndUploadAvatar(sessionProvider),
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 70,
                          backgroundColor: const Color(0xFF00695C),
                          backgroundImage: session.profilePictureUrl != null
                              ? NetworkImage(session.profilePictureUrl!)
                              : null,
                          child: session.profilePictureUrl == null
                              ? const Icon(Icons.person, size: 80, color: Colors.white)
                              : null,
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00A884),
                            shape: BoxShape.circle,
                            border: Border.all(color: bgColor, width: 3),
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),

                  // Fields
                  _buildTextField('Email', Icons.email_outlined, null, readOnly: true, initialValue: session.email),
                  _buildTextField('Name', Icons.person_outline, _nameController),
                  _buildTextField(
                    'Mobile Number',
                    Icons.phone_outlined,
                    _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // Save Changes Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : () => _saveChanges(sessionProvider),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00A884),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving 
                          ? const SizedBox(
                              width: 24, height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Save Changes',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
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
