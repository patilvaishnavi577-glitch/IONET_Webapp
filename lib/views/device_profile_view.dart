import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/device_model.dart';
import '../providers/device_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/user_session_provider.dart';
import '../services/api_service.dart';
import 'package:file_picker/file_picker.dart';
import '../utils/toast_service.dart';

class DeviceProfileView extends StatefulWidget {
  final Device device;
  final VoidCallback? onClose;

  const DeviceProfileView({super.key, required this.device, this.onClose});

  @override
  State<DeviceProfileView> createState() => _DeviceProfileViewState();
}

class _DeviceProfileViewState extends State<DeviceProfileView> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    final token = context.read<UserSessionProvider>().session.token;
    if (token == null) return;
    
    setState(() => _isLoading = true);
    await context.read<DeviceProvider>().fetchDeviceDetails(
          token: token,
          dbId: widget.device.id,
          hwId: widget.device.deviceId,
        );
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _showShareDeviceDialog(BuildContext context, bool isDark) {
    final searchController = TextEditingController();
    String selectedUserId = '';
    String selectedUserName = '';
    String selectedUserEmail = '';
    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (stateContext, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1D222B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Share Device', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                 Text(
                   'Search user by Email or Phone number:',
                   style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13),
                 ),
                 const SizedBox(height: 8),
                 TextField(
                   controller: searchController,
                   style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                   onChanged: (val) async {
                     final query = val.trim();
                     if (query.isEmpty) {
                       setDialogState(() {
                         searchResults = [];
                         selectedUserId = '';
                         selectedUserName = '';
                         selectedUserEmail = '';
                       });
                       return;
                     }
                     final token = context.read<UserSessionProvider>().session.token;
                     if (token == null) return;

                     // Debounce: wait 300ms
                     await Future.delayed(const Duration(milliseconds: 300));
                     if (!stateContext.mounted) return;
                     if (searchController.text.trim() != query) return;

                     final results = await ApiService().searchUsers(token: token, query: query);
                     if (!stateContext.mounted) return;

                     final filtered = results ?? [];

                     setDialogState(() {
                       searchResults = filtered;
                       if (filtered.isNotEmpty) {
                         selectedUserId = filtered[0]['id']?.toString() ?? filtered[0]['_id']?.toString() ?? '';
                         selectedUserName = filtered[0]['name']?.toString() ?? '';
                         selectedUserEmail = filtered[0]['email']?.toString() ?? '';
                       } else {
                         selectedUserId = '';
                         selectedUserName = '';
                         selectedUserEmail = '';
                       }
                     });
                   },
                   onSubmitted: (val) async {
                     final query = val.trim();
                     if (query.isEmpty) return;
                     setDialogState(() {
                       isSearching = true;
                     });
                     final token = context.read<UserSessionProvider>().session.token;
                     final results = await ApiService().searchUsers(token: token!, query: query);
                     
                     final filtered = results ?? [];

                     setDialogState(() {
                       isSearching = false;
                       searchResults = filtered;
                       if (filtered.isNotEmpty) {
                         selectedUserId = filtered[0]['id']?.toString() ?? filtered[0]['_id']?.toString() ?? '';
                         selectedUserName = filtered[0]['name']?.toString() ?? '';
                         selectedUserEmail = filtered[0]['email']?.toString() ?? '';
                       } else {
                         selectedUserId = '';
                         selectedUserName = '';
                         selectedUserEmail = '';
                       }
                     });
                   },
                   decoration: InputDecoration(
                     hintText: 'Enter full email or phone...',
                     suffixIcon: isSearching
                         ? const SizedBox(
                             width: 20,
                             height: 20,
                             child: Padding(
                               padding: EdgeInsets.all(10),
                               child: CircularProgressIndicator(strokeWidth: 2),
                             ),
                           )
                         : IconButton(
                             icon: const Icon(Icons.search),
                             onPressed: () async {
                               final query = searchController.text.trim();
                               if (query.isEmpty) return;
                               setDialogState(() {
                                 isSearching = true;
                               });
                               final token = context.read<UserSessionProvider>().session.token;
                               final results = await ApiService().searchUsers(token: token!, query: query);

                               final filtered = results ?? [];

                               setDialogState(() {
                                 isSearching = false;
                                 searchResults = filtered;
                                 if (filtered.isNotEmpty) {
                                   selectedUserId = filtered[0]['id']?.toString() ?? filtered[0]['_id']?.toString() ?? '';
                                   selectedUserName = filtered[0]['name']?.toString() ?? '';
                                   selectedUserEmail = filtered[0]['email']?.toString() ?? '';
                                 } else {
                                   selectedUserId = '';
                                   selectedUserName = '';
                                   selectedUserEmail = '';
                                 }
                               });
                             },
                           ),
                   ),
                 ),
                if (searchResults.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    width: double.maxFinite,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: searchResults.length,
                      itemBuilder: (context, idx) {
                        final user = searchResults[idx];
                        final name = user['name'] ?? 'User';
                        final email = user['email'] ?? '';
                        final phone = user['phoneNumber'] ?? user['mobileNumber'] ?? user['phone'] ?? '';
                        final subtitleText = [email, phone].where((s) => s.toString().isNotEmpty).join(' • ');
                        final id = user['id'] ?? user['_id'] ?? '';
                        return Material(
                          color: Colors.transparent,
                          child: ListTile(
                            title: Text(name, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13)),
                            subtitle: Text(subtitleText, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 11)),
                            trailing: selectedUserId == id
                                ? Icon(Icons.check, color: isDark ? const Color(0xFF00A884) : const Color(0xFF008069))
                                : null,
                            onTap: () {
                              setDialogState(() {
                                selectedUserId = id;
                                selectedUserName = name;
                                selectedUserEmail = email;
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
                if (selectedUserId.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1B2F2A) : const Color(0xFFE6F4F1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person,
                          color: isDark ? const Color(0xFF00A884) : const Color(0xFF008069),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Selected: $selectedUserName ($selectedUserEmail)',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF00A884) : const Color(0xFF008069),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final token = context.read<UserSessionProvider>().session.token;
                final deviceProvider = context.read<DeviceProvider>();

                String targetUserId = selectedUserId;

                if (targetUserId.isEmpty) {
                  final query = searchController.text.trim();
                  if (query.isEmpty) {
                    ToastService.show(context, 'Please select a user to share with.', isError: true);
                    return;
                  }

                  // Perform automatic search fallback
                  setDialogState(() {
                    isSearching = true;
                  });
                  final results = await ApiService().searchUsers(token: token!, query: query);
                  setDialogState(() {
                    isSearching = false;
                  });

                  if (results == null || results.isEmpty) {
                    ToastService.show(context, 'No user found matching "$query".', isError: true);
                    return;
                  }

                  if (results.length == 1) {
                    // Exactly one user found - automatically select
                    final user = results.first;
                    targetUserId = user['id']?.toString() ?? user['_id']?.toString() ?? '';
                  } else {
                    // Multiple users found - show list and ask user to select
                    setDialogState(() {
                      searchResults = results;
                    });
                    ToastService.show(context, 'Multiple matches found. Please tap the correct user below.', isError: true);
                    return;
                  }
                }

                Navigator.of(dialogContext).pop();

                final error = await deviceProvider.shareDevice(
                  token: token!,
                  dbId: widget.device.id,
                  hwId: widget.device.deviceId,
                  targetUserId: targetUserId,
                );
                
                if (error == null) {
                  _fetchDetails(); // Refresh list after sharing
                }

                if (!stateContext.mounted) return;

                if (mounted) {
                  String messageText = 'Device shared successfully!';
                  bool isError = false;
                  
                  if (error != null) {
                    isError = true;
                    // Custom validation/exception handling for share limits
                    if (error.toLowerCase().contains('limit')) {
                      messageText = 'Share limit exceeded! You cannot share this device with more users.';
                    } else {
                      messageText = 'Failed to share: $error';
                    }
                  }
                  
                  ToastService.show(context, messageText, isError: isError);
                }
              },
              child: const Text('Share'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleUnshareUser(String targetUserId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('Remove User'),
        content: const Text('Are you sure you want to remove this user\'s access to the device?'),
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

    final token = context.read<UserSessionProvider>().session.token;
    if (token == null) return;
    
    final success = await context.read<DeviceProvider>().unshareDevice(
      token: token,
      dbId: widget.device.id,
      hwId: widget.device.deviceId,
      targetUserId: targetUserId,
    );
    
    if (success) {
      if (!mounted) return;
      ToastService.show(context, 'User removed successfully.');
      _fetchDetails();
    } else {
      if (!mounted) return;
      ToastService.show(context, 'Failed to remove user.', isError: true);
    }
  }

  Future<void> _handleLeaveDevice() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('Leave Device'),
        content: const Text('Are you sure you want to leave this device? You will lose access to it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final token = context.read<UserSessionProvider>().session.token;
    if (token == null) return;
    
    final success = await context.read<DeviceProvider>().deleteDevice(
      token: token,
      deviceId: widget.device.id,
    );
    
    if (success) {
      if (mounted) {
        if (widget.onClose != null) {
          widget.onClose!();
        } else {
          Navigator.of(context).pop();
        }
      }
    } else {
      if (!mounted) return;
      ToastService.show(context, 'Failed to leave device.', isError: true);
    }
  }

  Future<void> _handleDeleteDevice() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('Delete Device'),
        content: const Text('Are you sure you want to delete this device? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final token = context.read<UserSessionProvider>().session.token;
    if (token == null) return;
    
    final success = await context.read<DeviceProvider>().deleteDevice(
      token: token,
      deviceId: widget.device.id,
    );
    
    if (success) {
      if (mounted) {
        if (widget.onClose != null) {
          widget.onClose!();
        } else {
          Navigator.of(context).pop();
        }
      }
    } else {
      if (!mounted) return;
      ToastService.show(context, 'Failed to delete device.', isError: true);
    }
  }

  void _showRenameDialog(BuildContext context, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('Rename Device'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Device Name',
            hintText: 'Enter new device name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty || newName == currentName) {
                Navigator.of(dialogCtx).pop();
                return;
              }
              final token = context.read<UserSessionProvider>().session.token;
              if (token == null) return;
              
              Navigator.of(dialogCtx).pop();
              final success = await context.read<DeviceProvider>().updateDeviceName(
                token: token,
                deviceId: widget.device.id,
                deviceName: newName,
              );
              
              if (mounted) {
                ToastService.show(context, success ? 'Device renamed successfully!' : 'Failed to rename device.', isError: !success);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bgCol = isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5);
    final cardCol = isDark ? const Color(0xFF111B21) : Colors.white;
    final textPri = isDark ? Colors.white : Colors.black87;
    final textSec = isDark ? Colors.white54 : Colors.black54;
    final accentGreen = isDark ? const Color(0xFF00A884) : const Color(0xFF008069);

    final device = context.watch<DeviceProvider>().devices.firstWhere(
          (d) => d.id == widget.device.id,
          orElse: () => widget.device,
        );

    final isOwner = !device.isShared;

    Future<void> _pickAndUploadDeviceImage(BuildContext context) async {
      final userSession = context.read<UserSessionProvider>();
      final deviceProv = context.read<DeviceProvider>();

      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          withData: true,
        );

        if (result == null || result.files.isEmpty) return;

        final file = result.files.first;
        final bytes = file.bytes;

        if (bytes == null) {
          ToastService.show(context, 'Failed to read file data.', isError: true);
          return;
        }

        if (bytes.length > 5 * 1024 * 1024) {
          ToastService.show(context, 'Image size must be less than 5MB.', isError: true);
          return;
        }

        final token = userSession.session.token;
        final success = await deviceProv.uploadDeviceImage(
              token: token!,
              dbId: device.id,
              hwId: device.deviceId,
              bytes: bytes,
              filename: file.name,
            );

        if (!mounted) return;
        ToastService.show(context, success ? 'Device picture updated successfully!' : 'Failed to upload device picture.', isError: !success);
        if (success) _fetchDetails();
      } catch (_) {
        ToastService.show(context, 'Error selecting or uploading image.', isError: true);
      }
    }

    Future<void> _deleteDeviceImage(BuildContext context) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: const Text('Remove Photo'),
          content: const Text('Are you sure you want to remove the device photo?'),
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

      final userSession = context.read<UserSessionProvider>();
      final deviceProv = context.read<DeviceProvider>();

      final token = userSession.session.token;
      final success = await deviceProv.deleteDeviceImage(
            token: token!,
            dbId: device.id,
            hwId: device.deviceId,
          );

      if (!mounted) return;
      ToastService.show(context, success ? 'Device photo removed successfully!' : 'Failed to remove device photo.', isError: !success);
      if (success) _fetchDetails();
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

    void _showImageMenu(BuildContext context, Offset tapPosition) {
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
          if (device.imageUrl != null)
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
          if (device.imageUrl != null)
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
      ).then((value) {
        if (value == null) return;
        if (value == 'view') {
          _viewPhotoDialog(context, device.imageUrl!);
        } else if (value == 'upload') {
          _pickAndUploadDeviceImage(context);
        } else if (value == 'remove') {
          _deleteDeviceImage(context);
        }
      });
    }

    return Scaffold(
      backgroundColor: bgCol,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF111B21) : const Color(0xFF008069),
        leading: widget.onClose != null
            ? IconButton(
                icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.white),
                onPressed: widget.onClose,
              )
            : null,
        title: Text('Device Profile', style: TextStyle(color: isDark ? Colors.white : Colors.white)),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTapDown: (details) {
                      if (isOwner) {
                        _showImageMenu(context, details.globalPosition);
                      } else if (device.imageUrl != null) {
                        _viewPhotoDialog(context, device.imageUrl!);
                      }
                    },
                    child: MouseRegion(
                      cursor: (isOwner || device.imageUrl != null) ? SystemMouseCursors.click : SystemMouseCursors.basic,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: accentGreen,
                            backgroundImage: device.imageUrl != null ? NetworkImage(device.imageUrl!) : null,
                            child: device.imageUrl == null
                                ? ClipOval(
                                    child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
                                  )
                                : null,
                          ),
                          if (isOwner)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Colors.blueAccent,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          device.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: textPri, fontSize: 24, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isOwner) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20, color: Colors.blueAccent),
                          onPressed: () => _showRenameDialog(context, device.name),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 40),
                  
                  // Device Details Card
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Device Details',
                      style: TextStyle(color: accentGreen, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: cardCol,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildDetailRow(
                          icon: Icons.fingerprint,
                          title: 'Device ID',
                          value: device.deviceId,
                          iconColor: textSec,
                          textColor: textPri,
                        ),
                        const Divider(height: 24),
                        _buildDetailRow(
                          icon: Icons.security,
                          title: 'Access Level',
                          value: isOwner ? 'OWNED' : 'SHARED',
                          iconColor: accentGreen,
                          textColor: textPri,
                        ),

                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),

                  // Shared Access Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Shared Access (${device.sharedUsers.length})',
                        style: TextStyle(color: accentGreen, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      if (isOwner)
                        IconButton(
                          icon: Icon(Icons.person_add_alt_1, color: accentGreen),
                          onPressed: () => _showShareDeviceDialog(context, isDark),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  if (device.sharedUsers.isEmpty)
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: cardCol,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      child: Text(
                        isOwner
                            ? 'This device is not shared with anyone.'
                            : 'No shared users listed for this device.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: textSec),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: cardCol,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: device.sharedUsers.length,
                        separatorBuilder: (ctx, idx) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final u = device.sharedUsers[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: accentGreen.withValues(alpha: 0.2),
                              child: Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : '?', style: TextStyle(color: accentGreen)),
                            ),
                            title: Text(u.name, style: TextStyle(color: textPri)),
                            subtitle: Text(u.email, style: TextStyle(color: textSec)),
                            trailing: isOwner
                                ? IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    onPressed: () => _handleUnshareUser(u.id),
                                  )
                                : null,
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 24),
                  
                  if (isOwner) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _handleDeleteDevice,
                        icon: const Icon(Icons.delete_forever),
                        label: const Text('Delete Device', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: cardCol,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      child: Column(
                        children: [
                          Text(
                            'You are a shared user on this device.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: textSec),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                            onPressed: _handleLeaveDevice,
                            icon: const Icon(Icons.exit_to_app),
                            label: const Text('Leave Device'),
                          )
                        ],
                      ),
                    )
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String title,
    required String value,
    required Color iconColor,
    required Color textColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        )
      ],
    );
  }
}
