import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/device_model.dart';
import '../providers/device_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../views/device_profile_view.dart';
import 'package:flutter/gestures.dart';

class DeviceChatView extends StatefulWidget {
  final Device device;
  final bool isMobile;
  final VoidCallback? onBack;

  const DeviceChatView({
    super.key,
    required this.device,
    this.isMobile = false,
    this.onBack,
  });

  @override
  State<DeviceChatView> createState() => _DeviceChatViewState();
}

class _DeviceChatViewState extends State<DeviceChatView> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _showProfilePane = false;

  @override
  void didUpdateWidget(DeviceChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.device.id != widget.device.id) {
      setState(() {
        _showProfilePane = false;
      });
      _scrollToBottom();
    } else if (oldWidget.device.messages.length != widget.device.messages.length) {
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend([String? prefilledCommand, String? displayText]) {
    if (!widget.device.isOnline) return;
    final text = prefilledCommand ?? _textController.text;
    if (text.trim().isEmpty) return;

    if (prefilledCommand == null) {
      _textController.clear();
    }

    context.read<DeviceProvider>().sendMessage(text, displayText: displayText);
    _scrollToBottom();
  }



  
  void _showConfigurationDialog(BuildContext context, DeviceProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        return DeviceConfigDialog(
          provider: provider,
          device: widget.device,
        );
      },
    );
  }

  void _showWifiSetupDialog(BuildContext context, DeviceProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        return WifiSetupDialog(
          provider: provider,
          device: widget.device,
        );
      },
    );
  }

  void _showCommandPaletteBottomSheet(
    BuildContext context,
    DeviceProvider provider,
    bool isDark,
    Color accentGreen,
  ) {
    final devId = widget.device.deviceId.isNotEmpty ? widget.device.deviceId : widget.device.id;
    final allCommands = provider.getQuickCommands(devId);
    final customCommands = provider.getCustomCommands(devId);

    showDialog(
      context: context,
      builder: (dialogCtx) {
        final cardBg = isDark ? const Color(0xFF1F2C34) : Colors.white;
        final textPrimary = isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight;
        final textSecondary = isDark ? AppTheme.textSecondary : AppTheme.textSecondaryLight;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440, maxHeight: 600),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppTheme.cardBorder : AppTheme.cardBorderLight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: accentGreen.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.bolt_rounded, color: accentGreen, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Quick Commands',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),

                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        color: textSecondary,
                        onPressed: () => Navigator.pop(dialogCtx),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (allCommands.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24.0),
                              child: Center(
                                child: Text(
                                  'No live commands received from device yet.\nSend /status to request available device commands.',
                                  style: TextStyle(color: textSecondary, fontSize: 13),
                                ),
                              ),
                            )
                          else
                            ...allCommands.map((cmd) {
                              final isCustom = customCommands.any((c) => c.message == cmd.message);
                              IconData icon = Icons.chevron_right_rounded;
                              final lowerLabel = cmd.label.toLowerCase();
                              final lowerMsg = cmd.message.toLowerCase();

                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF2A3942).withOpacity(0.5) : const Color(0xFFF7F9FA),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
                                  ),
                                ),
                                child: ListTile(
                                  dense: true,
                                  leading: Icon(icon, color: accentGreen, size: 20),
                                  title: Text(
                                    cmd.label,
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    cmd.message,
                                    style: TextStyle(color: textSecondary, fontSize: 11),
                                  ),
                                  trailing: isCustom
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: Icon(Icons.edit_outlined, size: 16, color: textSecondary),
                                              onPressed: () {
                                                Navigator.pop(dialogCtx);
                                                _showEditCustomDialog(context, cmd, isDark);
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                              onPressed: () {
                                                provider.deleteDeviceQuickCommand(devId, cmd);
                                                Navigator.pop(dialogCtx);
                                              },
                                            ),
                                          ],
                                        )
                                      : const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                                  onTap: () {
                                    Navigator.pop(dialogCtx);
                                    _handleSend(cmd.message, cmd.label);
                                  },
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showEditCustomDialog(BuildContext context, QuickCommand cmd, bool isDark) {
    final formKey = GlobalKey<FormState>();
    final labelController = TextEditingController(text: cmd.label);
    final messageController = TextEditingController(text: cmd.message);
    final devId = widget.device.deviceId.isNotEmpty ? widget.device.deviceId : widget.device.id;

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F2C34) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? AppTheme.cardBorder : AppTheme.cardBorderLight,
                width: 1,
              ),
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Edit Custom Button',
                    style: TextStyle(
                      color: isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: labelController,
                    decoration: const InputDecoration(labelText: 'Button Label'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: messageController,
                    decoration: const InputDecoration(labelText: 'Command Text'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (formKey.currentState?.validate() ?? false) {
                            final newLabel = labelController.text.trim();
                            final newMsg = messageController.text.trim();
                            context.read<DeviceProvider>().editDeviceQuickCommand(
                              devId,
                              cmd,
                              QuickCommand(label: newLabel, message: newMsg, isCustom: true),
                            );
                            Navigator.pop(dialogContext);
                          }
                        },
                        child: const Text('Save'),
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
    final messages = widget.device.messages;
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    final headerBg = isDark ? AppTheme.cardBg : const Color(0xFFF0F2F5);
    final borderCol = isDark ? AppTheme.cardBorder : AppTheme.cardBorderLight;
    final textPrimaryColor = isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight;
    final textSecondaryColor = isDark ? AppTheme.textSecondary : AppTheme.textSecondaryLight;
    final chatBg = isDark ? AppTheme.scaffoldBg : const Color(0xFFEFEAE2);
    final inputBarBg = isDark ? AppTheme.cardBg : const Color(0xFFF0F2F5);
    final textInputFill = isDark ? const Color(0xFF2A3942) : Colors.white;
    final accentGreen = isDark ? const Color(0xFF00A884) : const Color(0xFF008069);

    final chatContent = Column(
      children: [
        // 1. Header Bar
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: headerBg,
            border: Border(
              bottom: BorderSide(color: borderCol, width: 1),
            ),
          ),
          child: GestureDetector(
            onTap: () {
              if (widget.isMobile) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DeviceProfileView(device: widget.device)),
                );
              } else {
                setState(() {
                  _showProfilePane = !_showProfilePane;
                });
              }
            },
            child: Row(
              children: [
                if (widget.isMobile || widget.onBack != null)
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: textPrimaryColor),
                    onPressed: widget.onBack,
                  ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: widget.device.imageUrl != null
                        ? Colors.transparent
                        : (isDark ? const Color(0xFF2A3942) : Colors.white),
                    shape: BoxShape.circle,
                  ),
                  padding: widget.device.imageUrl != null ? EdgeInsets.zero : const EdgeInsets.all(4),
                  child: ClipOval(
                    child: widget.device.imageUrl != null
                        ? Image.network(
                            widget.device.imageUrl!,
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Padding(
                              padding: const EdgeInsets.all(4),
                              child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                            ),
                          )
                        : Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.device.name,
                        style: TextStyle(
                          color: textPrimaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      InkWell(
                      onTap: widget.device.isOnline ? null : () {
                        context.read<DeviceProvider>().reconnectCurrentDevice();
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: widget.device.isOnline 
                                  ? const Color(0xFF2DD4BF) 
                                  : (widget.device.statusMessage == 'Connecting...' ? Colors.orangeAccent : Colors.redAccent),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                                                    Text(
                            widget.device.isOnline
                                ? 'Online'
                                : (widget.device.statusMessage == 'Connecting...'
                                    ? 'Connecting...'
                                    : (widget.device.lastActiveTime.isNotEmpty && widget.device.lastActiveTime != 'Never'
                                        ? 'Offline • ${widget.device.lastActiveTime}'
                                        : 'Offline • Tap to retry')),
                            style: TextStyle(
                              color: widget.device.isOnline ? const Color(0xFF2DD4BF) : (widget.device.statusMessage == 'Connecting...' ? Colors.orangeAccent : textSecondaryColor),
                              fontSize: 12,
                              decoration: !widget.device.isOnline && widget.device.statusMessage != 'Connecting...'
                                  ? TextDecoration.underline
                                  : TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!widget.device.isShared) ...[
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: textPrimaryColor),
                  tooltip: 'Device Options',
                  onSelected: (val) {
                    final prov = context.read<DeviceProvider>();
                    if (val == 'config') {
                      _showConfigurationDialog(context, prov);
                    } else if (val == 'wifi_setup') {
                      _showWifiSetupDialog(context, prov);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      value: 'config',
                      child: Row(
                        children: [
                          Icon(Icons.tune_rounded, size: 20, color: accentGreen),
                          const SizedBox(width: 10),
                          const Text('Configuration'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'wifi_setup',
                      child: Row(
                        children: [
                          Icon(Icons.wifi_rounded, size: 20, color: accentGreen),
                          const SizedBox(width: 10),
                          const Text('Wi-Fi Setup'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),



        // 2. Chat Message Stream (WhatsApp classic chat background)
        Expanded(
          child: Container(
            color: chatBg,
            child: (!widget.device.isOnline || messages.isEmpty)
                ? _buildEmptyState(isDark, textPrimaryColor, textSecondaryColor, accentGreen)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      return _buildMessageBubble(msg, isDark, accentGreen);
                    },
                  ),
          ),
        ),

        // 4. Message / Command Input Bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          color: inputBarBg,
          child: Row(
            children: [
                            // STATUS Button
              GestureDetector(
                onTap: widget.device.isOnline ? () => _handleSend('/status') : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: widget.device.isOnline ? accentGreen : textSecondaryColor.withOpacity(0.3),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.show_chart_rounded, color: widget.device.isOnline ? accentGreen : textSecondaryColor.withOpacity(0.5), size: 20),
                      const SizedBox(height: 2),
                      Text(
                        'STATUS',
                        style: TextStyle(
                          color: widget.device.isOnline ? accentGreen : textSecondaryColor.withOpacity(0.5),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _textController,
                  enabled: widget.device.isOnline && messages.isNotEmpty,
                  style: TextStyle(color: textPrimaryColor, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: widget.device.isOnline 
                        ? (messages.isNotEmpty ? 'Send command...' : 'Request status first')
                        : (widget.device.statusMessage == 'Connecting...' ? 'Connecting...' : 'Device offline'),
                    hintStyle: TextStyle(color: textSecondaryColor),
                    filled: true,
                    fillColor: textInputFill,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.bolt_rounded, color: accentGreen),
                      tooltip: 'Quick Commands',
                      onPressed: () {
                        final provider = context.read<DeviceProvider>();
                        _showCommandPaletteBottomSheet(context, provider, isDark, accentGreen);
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _handleSend(),
                ),
              ),
              const SizedBox(width: 10),

              // Circular WhatsApp Styled Send Button
              GestureDetector(
                onTap: (widget.device.isOnline && messages.isNotEmpty) ? () => _handleSend() : null,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: (widget.device.isOnline && messages.isNotEmpty) ? accentGreen : (isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB)),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (widget.isMobile || !_showProfilePane) {
      return chatContent;
    }

    return Row(
      children: [
        Expanded(child: chatContent),
        Container(
          width: 380,
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: isDark ? AppTheme.cardBorder : AppTheme.cardBorderLight, width: 1),
            ),
          ),
          child: DeviceProfileView(
            device: widget.device,
            onClose: () {
              setState(() {
                _showProfilePane = false;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isDark, Color accentGreen) {
    final isUser = msg.isUser;
    final primaryTextColor = isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight;
    final secondaryTextColor = isDark ? AppTheme.textSecondary : AppTheme.textSecondaryLight;

    final userBubbleColor = isDark ? const Color(0xFF005C4B) : const Color(0xFFD9FDD3);
    final deviceBubbleColor = isDark ? AppTheme.cardBg : Colors.white;

    // Clean bubble text: filter out commands from message body
    final filteredLines = msg.text.split('\n').where((l) => !l.trim().startsWith('/')).join('\n');
    final bubbleContent = CommandText(
      text: filteredLines.isNotEmpty ? filteredLines : msg.text,
      isUser: isUser,
      isDark: isDark,
      accentGreen: accentGreen,
      primaryTextColor: primaryTextColor,
      onCommandTap: (cmd) => _handleSend(cmd),
    );

    final isResendable = isUser &&
        !msg.text.startsWith('Sent Configuration:') &&
        !msg.text.startsWith('Sent Wi-Fi Setup:');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: isResendable
                ? () {
                    final cmd = msg.command ?? msg.text;
                    _handleSend(cmd, msg.text);
                  }
                : null,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? userBubbleColor : deviceBubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    bubbleContent,
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isResendable) ...[
                          Icon(
                            Icons.replay_rounded,
                            size: 11,
                            color: isDark ? Colors.white.withOpacity(0.7) : AppTheme.textSecondaryLight,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          msg.formattedTime,
                          style: TextStyle(
                            color: isUser
                                ? (isDark ? Colors.white.withOpacity(0.7) : AppTheme.textSecondaryLight)
                                : secondaryTextColor,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'D';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  Widget _buildEmptyState(bool isDark, Color textPrimaryColor, Color textSecondaryColor, Color accentGreen) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: isDark ? const Color(0xFFD1D7DB) : const Color(0xFFE0E0E0),
            backgroundImage: widget.device.imageUrl != null
                ? NetworkImage(widget.device.imageUrl!)
                : null,
            child: widget.device.imageUrl == null
                ? ClipOval(
                    child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
                  )
                : null,
          ),
          const SizedBox(height: 24),
          Text(
            'Start chat with ${widget.device.name}',
            style: TextStyle(
              color: textPrimaryColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Request a live status report to see device data\nand available commands.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textSecondaryColor,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: widget.device.isOnline ? () => _handleSend('/status') : null,
            icon: const Icon(Icons.show_chart_rounded),
            label: const Text('Get device status'),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.device.isOnline ? accentGreen : (isDark ? const Color(0xFF2A3942) : const Color(0xFFE0E0E0)),
              foregroundColor: widget.device.isOnline ? Colors.white : (isDark ? Colors.white54 : textSecondaryColor),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 0,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.device.isOnline 
                ? 'Device is online. Ready to send commands.' 
                : (widget.device.statusMessage == 'Connecting...' ? 'Connecting to device...' : 'Device is offline.'),
            style: TextStyle(
              color: widget.device.isOnline ? accentGreen : (widget.device.statusMessage == 'Connecting...' ? Colors.orangeAccent : textSecondaryColor),
              fontSize: 13,
              fontWeight: widget.device.isOnline || widget.device.statusMessage == 'Connecting...' ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class CommandText extends StatefulWidget {
  final String text;
  final bool isUser;
  final bool isDark;
  final Color accentGreen;
  final Color primaryTextColor;
  final Function(String) onCommandTap;

  const CommandText({
    super.key,
    required this.text,
    required this.isUser,
    required this.isDark,
    required this.accentGreen,
    required this.primaryTextColor,
    required this.onCommandTap,
  });

  @override
  State<CommandText> createState() => _CommandTextState();
}

class _CommandTextState extends State<CommandText> {
  late List<TapGestureRecognizer> _recognizers;

  @override
  void initState() {
    super.initState();
    _recognizers = [];
  }

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Clear old recognizers if rebuilding
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    final RegExp commandRegex = RegExp(r'(/\w+)|(\b(?:On|Off)\b)');
    final Iterable<RegExpMatch> matches = commandRegex.allMatches(widget.text);

    if (matches.isEmpty) {
      return Text(
        widget.text,
        style: TextStyle(
          color: widget.isUser
              ? (widget.isDark ? Colors.white : AppTheme.textPrimaryLight)
              : widget.primaryTextColor,
          fontSize: 14.5,
          height: 1.3,
          fontFamily: 'monospace',
        ),
      );
    }

    List<TextSpan> spans = [];
    int lastMatchEnd = 0;
    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: widget.text.substring(lastMatchEnd, match.start)));
      }
      
      if (match.group(1) != null) {
        final command = match.group(1)!;
        final recognizer = TapGestureRecognizer()..onTap = () => widget.onCommandTap(command);
        _recognizers.add(recognizer);

        spans.add(
          TextSpan(
            text: command,
            style: TextStyle(
              color: widget.accentGreen,
              fontWeight: FontWeight.w600,
            ),
            recognizer: recognizer,
          ),
        );
      } else if (match.group(2) != null) {
        final status = match.group(2)!;
        final color = status == 'On' ? widget.accentGreen : const Color(0xFFF87171); // Red for Off
        spans.add(
          TextSpan(
            text: status,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }
      
      lastMatchEnd = match.end;
    }
    if (lastMatchEnd < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(lastMatchEnd)));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: widget.isUser
              ? (widget.isDark ? Colors.white : AppTheme.textPrimaryLight)
              : widget.primaryTextColor,
          fontSize: 14.5,
          height: 1.3,
          fontFamily: 'monospace', // To make device output align better like in the image
        ),
        children: spans,
      ),
    );
  }
}


// -----------------------------------------------------------------------------
// Device Configuration Dialog
// -----------------------------------------------------------------------------

class DeviceConfigDialog extends StatefulWidget {
  final DeviceProvider provider;
  final Device device;

  const DeviceConfigDialog({
    super.key,
    required this.provider,
    required this.device,
  });

  @override
  State<DeviceConfigDialog> createState() => _DeviceConfigDialogState();
}

class _DeviceConfigDialogState extends State<DeviceConfigDialog> {
  final List<ConfigItem> configItems = [];

  @override
  void initState() {
    super.initState();
    refillData();
  }

  void refillData() {
    for (final item in configItems) {
      item.dispose();
    }
    configItems.clear();

    final devId = widget.device.deviceId.isNotEmpty ? widget.device.deviceId : widget.device.id;
    final latestData = widget.provider.getLatestDeviceStatusData(devId) ??
        widget.provider.getLatestDeviceStatusData(widget.device.id);

    if (latestData != null && latestData.isNotEmpty) {
      latestData.forEach((key, val) {
        final isNA = key.toUpperCase().startsWith('NA');
        configItems.add(ConfigItem(key: key, value: isNA ? '' : key));
      });
    }
  }

  @override
  void dispose() {
    for (final item in configItems) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF00A884).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.tune_rounded, color: Color(0xFF00A884), size: 20),
          ),
          const SizedBox(width: 10),
          const Text('Device Configuration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TELEMETRY ITEMS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => refillData()),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Reset', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (configItems.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Center(
                    child: Text(
                      'No status configuration data available.\nPlease query device status in the chat first.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                ...configItems.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.key,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: item.valueController,
                          decoration: InputDecoration(
                            hintText: 'Enter custom name for ${item.key}',
                            hintStyle: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? Colors.grey[500] : Colors.grey[400],
                            ),
                            suffixIcon: item.valueController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 16),
                                    onPressed: () {
                                      setState(() {
                                        item.valueController.clear();
                                      });
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            isDense: true,
                          ),
                          style: const TextStyle(fontSize: 13.5),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: configItems.isEmpty
              ? null
              : () {
                  final Map<String, dynamic> configData = {};
                  for (final item in configItems) {
                    final val = item.valueController.text.trim();
                    configData[item.key] = val.isNotEmpty ? val : item.key;
                  }

                  final devId = widget.device.deviceId.isNotEmpty ? widget.device.deviceId : widget.device.id;
                  widget.provider.sendConfig(devId, configData);
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Configuration command sent successfully')),
                  );
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00A884),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Send'),
        ),
      ],
    );
  }
}

class ConfigItem {
  final String key;
  final TextEditingController valueController;

  ConfigItem({required this.key, required String value})
      : valueController = TextEditingController(text: value);

  void dispose() {
    valueController.dispose();
  }
}

// -----------------------------------------------------------------------------
// Wi-Fi Setup Dialog
// -----------------------------------------------------------------------------

class WifiSetupDialog extends StatefulWidget {
  final DeviceProvider provider;
  final Device device;

  const WifiSetupDialog({
    super.key,
    required this.provider,
    required this.device,
  });

  @override
  State<WifiSetupDialog> createState() => _WifiSetupDialogState();
}

class _WifiSetupDialogState extends State<WifiSetupDialog> {
  final _ssidController = TextEditingController();
  final _passController = TextEditingController();
  bool _obscurePassword = true;
  String? _ssidError;

  @override
  void dispose() {
    _ssidController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.wifi, color: Color(0xFF00A884)),
          SizedBox(width: 8),
          Text('Wi-Fi Setup'),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the Wi-Fi credentials to configure on your device.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _ssidController,
                decoration: InputDecoration(
                  labelText: 'Wi-Fi SSID',
                  hintText: 'e.g. Home Network',
                  prefixIcon: const Icon(Icons.wifi_rounded, size: 20),
                  errorText: _ssidError,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                onChanged: (val) {
                  if (_ssidError != null && val.trim().isNotEmpty) {
                    setState(() => _ssidError = null);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Wi-Fi Password',
                  hintText: 'Enter network password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final ssid = _ssidController.text.trim();
            final pass = _passController.text;

            if (ssid.isEmpty) {
              setState(() => _ssidError = 'SSID is required');
              return;
            }

            final devId = widget.device.deviceId.isNotEmpty ? widget.device.deviceId : widget.device.id;
            widget.provider.sendWifiSetup(devId, ssid, pass);
            Navigator.pop(context);

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Wi-Fi setup command sent successfully')),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00A884),
            foregroundColor: Colors.white,
          ),
          child: const Text('Send'),
        ),
      ],
    );
  }
}
