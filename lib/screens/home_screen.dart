import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../models/channel_model.dart';
import '../models/device_model.dart';
import '../providers/device_provider.dart';
import '../providers/knowledge_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/updates_provider.dart';
import '../providers/user_session_provider.dart';
import '../theme/app_theme.dart';
import '../views/channel_feed_view.dart';
import '../views/knowledge_view.dart';
import '../views/profile_view.dart';
import '../views/updates_view.dart';
import '../widgets/device_chat_view.dart';
import '../widgets/device_tile.dart';
import '../widgets/story_player.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _activeNavIndex = 0; // 0: Devices, 1: Updates, 2: Knowledge, 3: Profile
  String _activeFilter = 'All';
  bool _showMobileChat = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final session = context.read<UserSessionProvider>().session;
      final token = session.token;
      if (token != null) {
        try {
          await context.read<DeviceProvider>().fetchDevices(
            token,
            currentUserId: session.userId,
          );
        } catch (e) {
          print('Crash in fetchDevices: $e');
        }
        try {
          await context.read<KnowledgeProvider>().fetchChannels(token);
        } catch (e) {
          print('Crash in fetchChannels: $e');
        }
      }
      try {
        await context.read<UpdatesProvider>().fetchUpdates();
      } catch (e) {
        print('Crash in fetchUpdates: $e');
      }
    });
  }

  void _showAddDeviceDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final deviceIdController = TextEditingController();
    final deviceNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1D222B),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.cardBorder, width: 1),
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add Device',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: deviceIdController,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Device ID',
                      hintText: 'Enter device ID',
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                    ],
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter Device ID';
                      }
                      if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(val.trim())) {
                        return 'Special characters not allowed';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: deviceNameController,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Device Name',
                      hintText: 'Enter device name',
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9 ]')),
                    ],
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter Device Name';
                      }
                      if (!RegExp(r'^[a-zA-Z0-9 ]+$').hasMatch(val.trim())) {
                        return 'Special characters not allowed';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2B3240),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(100, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () {
                          if (formKey.currentState?.validate() ?? false) {
                            final deviceId = deviceIdController.text.trim();
                            final deviceName = deviceNameController.text.trim();

                            final token = context
                                .read<UserSessionProvider>()
                                .session
                                .token;
                            if (token != null) {
                              context.read<DeviceProvider>().addDevice(
                                token: token,
                                deviceId: deviceId,
                                deviceName: deviceName,
                              );
                            }

                            Navigator.of(dialogContext).pop();

                            final isDesktop =
                                MediaQuery.of(context).size.width > 768;
                            if (!isDesktop) {
                              setState(() {
                                _activeNavIndex = 0;
                                _showMobileChat = true;
                              });
                            }
                          }
                        },
                        child: const Text('Submit'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isDesktop = mediaQuery.size.width > 768;

    double sidebarWidth = mediaQuery.size.width * 0.33;
    if (sidebarWidth < 410) sidebarWidth = 410;
    if (sidebarWidth > 480) sidebarWidth = 480;

    final deviceProvider = context.watch<DeviceProvider>();
    final devices = deviceProvider.devices;
    final selectedDevice = deviceProvider.selectedDevice;

    final knowledgeProvider = context.watch<KnowledgeProvider>();
    final selectedChannel = knowledgeProvider.selectedChannel;

    final isDark = context.watch<ThemeProvider>().isDarkMode;

    final navStripColor = isDark
        ? const Color(0xFF111B21)
        : const Color(0xFFE2E8F0);
    final sidebarColor = isDark ? AppTheme.scaffoldBg : Colors.white;
    final cardBorderColor = isDark
        ? AppTheme.cardBorder
        : AppTheme.cardBorderLight;
    final textPrimaryColor = isDark
        ? AppTheme.textPrimary
        : AppTheme.textPrimaryLight;
    final textSecondaryColor = isDark
        ? AppTheme.textSecondary
        : AppTheme.textSecondaryLight;
    final searchBgColor = isDark
        ? AppTheme.inputBg
        : const Color(0xFFF1F5F9);

    // Mobile view full-screen modes
    if (!isDesktop) {
      if (_showMobileChat && selectedDevice != null && _activeNavIndex == 0) {
        return Scaffold(
          backgroundColor: isDark
              ? AppTheme.scaffoldBg
              : AppTheme.scaffoldBgLight,
          body: SafeArea(
            child: DeviceChatView(
              device: selectedDevice,
              isMobile: true,
              onBack: () {
                setState(() {
                  _showMobileChat = false;
                });
              },
            ),
          ),
        );
      }

      final updatesProvider = context.watch<UpdatesProvider>();
      final selectedUpdate = updatesProvider.selectedUpdate;

      if (_activeNavIndex == 1 && selectedUpdate != null) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: StoryPlayer(
              update: selectedUpdate,
              onClose: () {
                updatesProvider.selectUpdate(null);
              },
            ),
          ),
        );
      }

      if (_activeNavIndex == 2 && selectedChannel != null) {
        return Scaffold(
          backgroundColor: isDark
              ? AppTheme.scaffoldBg
              : AppTheme.scaffoldBgLight,
          body: SafeArea(
            child: ChannelFeedView(
              channel: selectedChannel,
              onBack: () {
                context.read<KnowledgeProvider>().selectChannel(null);
              },
            ),
          ),
        );
      }
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.scaffoldBg : AppTheme.scaffoldBgLight,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  // 1. Far-Left Navigation Strip (Desktop Only)
                  if (isDesktop) ...[
                    Container(
                      width: 60,
                      color: navStripColor,
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          _buildFarLeftNavIcon(
                            index: 0,
                            icon: Icons.chat_bubble_outline,
                            tooltip: 'Devices',
                            isDark: isDark,
                          ),
                          const SizedBox(height: 16),
                          _buildFarLeftNavIcon(
                            index: 1,
                            icon: Icons.sync,
                            tooltip: 'Updates',
                            isDark: isDark,
                          ),
                          const SizedBox(height: 16),
                          _buildFarLeftNavIcon(
                            index: 2,
                            icon: Icons.help_outline,
                            tooltip: 'Support',
                            isDark: isDark,
                          ),
                          const Spacer(),
                          _buildFarLeftNavIcon(
                            index: 3,
                            icon: Icons.person_outline,
                            tooltip: 'Profile',
                            isDark: isDark,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'v${ApiConfig.appVersion}',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.3)
                                  : Colors.black.withValues(alpha: 0.3),
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                    VerticalDivider(width: 1, color: cardBorderColor),
                  ],

                  // 2. Main Content Body Area
                  Expanded(
                    child: _buildActiveView(
                      isDesktop,
                      sidebarWidth,
                      deviceProvider,
                      devices,
                      selectedDevice,
                      selectedChannel,
                      isDark,
                      sidebarColor,
                      cardBorderColor,
                      textPrimaryColor,
                      textSecondaryColor,
                      searchBgColor,
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Navigation Capsule Bar (Mobile Only - 4 Tabs)
            if (!isDesktop) ...[
              Container(
                height: 64,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161A22) : Colors.white,
                  border: Border(
                    top: BorderSide(color: cardBorderColor, width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildBottomNavItem(
                      0,
                      Icons.chat_bubble_outline,
                      'Devices',
                      isDark,
                    ),
                    _buildBottomNavItem(1, Icons.sync, 'Updates', isDark),
                    _buildBottomNavItem(2, Icons.help_outline, 'Support', isDark),
                    _buildBottomNavItem(3, Icons.person_outline, 'Profile', isDark),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(
    int index,
    IconData icon,
    String label,
    bool isDark,
  ) {
    final isSelected = _activeNavIndex == index;
    // Updated active colors: Light teal/mint for text and icon in dark mode, darker green for light mode
    final activeColor = isDark ? const Color(0xFFC3E8D7) : const Color(0xFF005C4B); 
    // Indicator background pill: Dark muted green in dark mode, light mint in light mode
    final indicatorColor = isDark ? const Color(0xFF2A3C35) : const Color(0xFFC3E8D7).withValues(alpha: 0.6);
    
    final inactiveColor = isDark
        ? AppTheme.textSecondary
        : AppTheme.textSecondaryLight;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeNavIndex = index;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? indicatorColor : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: isSelected ? activeColor : inactiveColor,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : inactiveColor,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveView(
    bool isDesktop,
    double sidebarWidth,
    DeviceProvider deviceProvider,
    List<dynamic> devices,
    dynamic selectedDevice,
    Channel? selectedChannel,
    bool isDark,
    Color sidebarColor,
    Color cardBorderColor,
    Color textPrimaryColor,
    Color textSecondaryColor,
    Color searchBgColor,
  ) {
    if (isDesktop) {
      // Permanent two-column layout on Desktop across all tabs
      return Row(
        children: [
          // Left Sidebar Column
          Container(
            width: sidebarWidth,
            color: sidebarColor,
            child: _buildLeftSidebarContent(
              deviceProvider,
              devices,
              selectedDevice,
              isDark,
              sidebarColor,
              cardBorderColor,
              textPrimaryColor,
              textSecondaryColor,
              searchBgColor,
            ),
          ),
          VerticalDivider(width: 1, color: cardBorderColor),

          // Right Pane Column
          Expanded(
            child: _buildRightPaneContent(
              selectedDevice,
              selectedChannel,
              isDark,
            ),
          ),
        ],
      );
    } else {
      // Mobile View switches views full-width
      switch (_activeNavIndex) {
        case 1:
          return const UpdatesView();
        case 2:
          return const KnowledgeView();
        case 3:
          return const ProfileView();
        case 0:
        default:
          return _buildDevicesSidebar(
            deviceProvider,
            devices,
            selectedDevice,
            isDark,
            sidebarColor,
            cardBorderColor,
            textPrimaryColor,
            textSecondaryColor,
            searchBgColor,
            false,
          );
      }
    }
  }

  Widget _buildLeftSidebarContent(
    DeviceProvider deviceProvider,
    List<dynamic> devices,
    dynamic selectedDevice,
    bool isDark,
    Color sidebarColor,
    Color cardBorderColor,
    Color textPrimaryColor,
    Color textSecondaryColor,
    Color searchBgColor,
  ) {
    switch (_activeNavIndex) {
      case 1:
        return const UpdatesView();
      case 2:
        return const KnowledgeView();
      case 3:
        return const ProfileView();
      case 0:
      default:
        return _buildDevicesSidebar(
          deviceProvider,
          devices,
          selectedDevice,
          isDark,
          sidebarColor,
          cardBorderColor,
          textPrimaryColor,
          textSecondaryColor,
          searchBgColor,
          true,
        );
    }
  }

  Widget _buildRightPaneContent(
    dynamic selectedDevice,
    Channel? selectedChannel,
    bool isDark,
  ) {
    switch (_activeNavIndex) {
      case 0:
        return selectedDevice != null
            ? DeviceChatView(
                device: selectedDevice,
                onBack: () {
                  context.read<DeviceProvider>().selectDevice(null);
                },
              )
            : _buildEmptyState(isDark);
      case 2:
        return selectedChannel != null
            ? ChannelFeedView(
                channel: selectedChannel,
                onBack: () {
                  context.read<KnowledgeProvider>().selectChannel(null);
                },
              )
            : _buildEmptyState(isDark);
      case 1:
        final selectedUpdate = context.watch<UpdatesProvider>().selectedUpdate;
        return selectedUpdate != null
            ? StoryPlayer(
                update: selectedUpdate,
                onClose: () {
                  context.read<UpdatesProvider>().selectUpdate(null);
                },
              )
            : _buildEmptyState(isDark);
      case 3:
      default:
        return _buildEmptyState(isDark);
    }
  }

  Widget _buildDevicesSidebar(
    DeviceProvider deviceProvider,
    List<dynamic> devices,
    dynamic selectedDevice,
    bool isDark,
    Color sidebarColor,
    Color cardBorderColor,
    Color textPrimaryColor,
    Color textSecondaryColor,
    Color searchBgColor,
    bool isDesktop,
  ) {
    return Stack(
      children: [
        Column(
          children: [
            // Top Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Image.asset('assets/images/logo.png', height: 48),
                  const Spacer(),
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
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 2.0,
              ),
              child: TextField(
                onChanged: (query) => deviceProvider.setSearchQuery(query),
                style: TextStyle(color: textPrimaryColor, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search or start a new device chat',
                  hintStyle: TextStyle(
                    color: isDark
                        ? AppTheme.textMuted
                        : AppTheme.textMutedLight,
                    fontSize: 12.5,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 18,
                    color: textSecondaryColor,
                  ),
                  filled: true,
                  fillColor: searchBgColor,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            Align(
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    _buildFilterChip(
                      'All',
                      isSelected: _activeFilter == 'All',
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'Owned',
                      isSelected: _activeFilter == 'Owned',
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'Shared',
                      isSelected: _activeFilter == 'Shared',
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: cardBorderColor),

            // Device List or Empty View
            Expanded(
              child: devices.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.devices_other_outlined,
                              size: 48,
                              color: cardBorderColor,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No devices added yet',
                              style: TextStyle(
                                color: textSecondaryColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Click + button on the bottom right to add',
                              style: TextStyle(
                                color: isDark
                                    ? AppTheme.textMuted
                                    : AppTheme.textMutedLight,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: devices.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final device = devices[index];
                        final isSelected = selectedDevice?.id == device.id;

                        return DeviceTile(
                          device: device,
                          isSelected: isSelected,
                          onTap: () {
                            deviceProvider.selectDevice(device.id);
                            if (!isDesktop) {
                              setState(() {
                                _showMobileChat = true;
                              });
                            }
                          },
                          onDoubleTap: () => _showDeleteDeviceDialog(
                            context,
                            deviceProvider,
                            device,
                            isDark,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: () => _showAddDeviceDialog(context),
            backgroundColor: const Color(0xFF00695C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 28),
          ),
        ),
      ],
    );
  }

  void _showDeleteDeviceDialog(
    BuildContext context,
    DeviceProvider deviceProvider,
    Device device,
    bool isDark,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1D222B) : Colors.white,
        title: Text(
          'Delete Device',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        content: Text(
          'Are you sure you want to delete ${device.name}?',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF10B981)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final token = context.read<UserSessionProvider>().session.token;
              if (token != null) {
                await deviceProvider.deleteDevice(
                  token: token,
                  deviceId: device.id,
                );
                setState(() {
                  _showMobileChat = false;
                });
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFarLeftNavIcon({
    required int index,
    required IconData icon,
    required String tooltip,
    required bool isDark,
    String? badgeText,
  }) {
    final isSelected = _activeNavIndex == index;
    final secondaryTextColor = isDark
        ? AppTheme.textSecondary
        : AppTheme.textSecondaryLight;
        
    final activeColor = isDark ? const Color(0xFFC3E8D7) : const Color(0xFF005C4B); 
    final indicatorColor = isDark ? const Color(0xFF2A3C35) : const Color(0xFFC3E8D7).withValues(alpha: 0.6);

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeNavIndex = index;
          });
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? indicatorColor : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: isSelected ? activeColor : secondaryTextColor,
                size: 22,
              ),
            ),
            if (badgeText != null)
              Positioned(
                right: -4,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2DD4BF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String label, {
    required bool isSelected,
    required bool isDark,
  }) {
    final cardBorderColor = isDark
        ? AppTheme.cardBorder
        : AppTheme.cardBorderLight;
    final secondaryTextColor = isDark
        ? AppTheme.textSecondary
        : AppTheme.textSecondaryLight;

    return GestureDetector(
      onTap: () {
        final session = context.read<UserSessionProvider>().session;
        final token = session.token;
        setState(() {
          _activeFilter = label;
        });
        if (token != null) {
          String? type;
          if (label == 'Owned') {
            type = 'OWNER';
          } else if (label == 'Shared') {
            type = 'SHARED';
          }
          context.read<DeviceProvider>().fetchDevices(
            token,
            type: type,
            currentUserId: session.userId,
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF10B981).withValues(alpha: 0.2)
              : (isDark ? AppTheme.inputBg : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF10B981) : cardBorderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF10B981) : secondaryTextColor,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final textPrimaryColor = isDark
        ? AppTheme.textPrimary
        : AppTheme.textPrimaryLight;
    final textSecondaryColor = isDark
        ? AppTheme.textSecondary
        : AppTheme.textSecondaryLight;

    return Container(
      color: isDark ? const Color(0xFF111B21) : const Color(0xFFF8FAFC),
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 32.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. Centered Card Container
                Container(
                  width: 380,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF202C33) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF2A3942)
                          : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Styled stacked illustration
                      SizedBox(
                        width: 140,
                        height: 100,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              Icons.laptop_chromebook_rounded,
                              size: 80,
                              color: isDark
                                  ? const Color(0xFF8696A0)
                                  : const Color(0xFF64748B),
                            ),
                            Positioned(
                              right: 18,
                              bottom: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF111B21)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF8696A0)
                                        : const Color(0xFF64748B),
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(
                                  Icons.phone_android_rounded,
                                  size: 16,
                                  color: isDark
                                      ? const Color(0xFF00A884)
                                      : const Color(0xFF008069),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Title
                      Text(
                        'Download IONET for Mobile',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textPrimaryColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Subtitle
                      Text(
                        'Get extra features like device monitoring, screen sharing and remote commands.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textSecondaryColor,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Download button
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark
                              ? const Color(0xFF00A884)
                              : const Color(0xFF008069),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text(
                          'Download',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),

                // End-to-End Encrypted Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 12,
                      color: isDark
                          ? const Color(0xFF8696A0)
                          : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'End-to-end encrypted',
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFF8696A0)
                            : const Color(0xFF94A3B8),
                        fontSize: 12,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
