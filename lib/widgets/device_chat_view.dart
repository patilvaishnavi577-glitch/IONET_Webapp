import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/device_model.dart';
import '../providers/device_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../views/device_profile_view.dart';

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

  void _handleSend([String? prefilledCommand]) {
    final text = prefilledCommand ?? _textController.text;
    if (text.trim().isEmpty) return;

    if (prefilledCommand == null) {
      _textController.clear();
    }

    context.read<DeviceProvider>().sendMessage(text);
    _scrollToBottom();
  }



  void _showAddCommandDialog(BuildContext context, bool isDark) {
    final formKey = GlobalKey<FormState>();
    final labelController = TextEditingController();
    final messageController = TextEditingController();

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
                    'Add Command',
                    style: TextStyle(
                      color: isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: labelController,
                    style: TextStyle(
                      color: isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight,
                      fontSize: 15,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Display Label',
                      hintText: 'e.g. Status, Reset',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter display label';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: messageController,
                    style: TextStyle(
                      color: isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight,
                      fontSize: 15,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Command Message',
                      hintText: 'Payload message to send',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter command message';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: isDark ? const Color(0xFF00A884) : const Color(0xFF008069),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          if (formKey.currentState?.validate() ?? false) {
                            final label = labelController.text.trim();
                            final message = messageController.text.trim();

                            context.read<DeviceProvider>().addQuickCommand(
                                  widget.device.id,
                                  label,
                                  message,
                                );
                            Navigator.of(dialogContext).pop();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0D221F) : const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            'Save',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF00A884) : const Color(0xFF008069),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
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
    );
  }

  void _showEditCommandDialog(BuildContext context, int indexToEdit, QuickCommand cmd, bool isDark) {
    final formKey = GlobalKey<FormState>();
    final labelController = TextEditingController(text: cmd.label);
    final messageController = TextEditingController(text: cmd.message);

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
                    'Edit Command',
                    style: TextStyle(
                      color: isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: labelController,
                    style: TextStyle(
                      color: isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight,
                      fontSize: 15,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Display Label',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter display label';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: messageController,
                    style: TextStyle(
                      color: isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight,
                      fontSize: 15,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Command Message',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter command message';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          context.read<DeviceProvider>().deleteQuickCommand(
                                widget.device.id,
                                indexToEdit,
                              );
                          Navigator.of(dialogContext).pop();
                        },
                        child: const Text(
                          'Delete',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: isDark ? const Color(0xFF00A884) : const Color(0xFF008069),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          if (formKey.currentState?.validate() ?? false) {
                            final label = labelController.text.trim();
                            final message = messageController.text.trim();

                            context.read<DeviceProvider>().editQuickCommand(
                                  widget.device.id,
                                  indexToEdit,
                                  label,
                                  message,
                                );
                            Navigator.of(dialogContext).pop();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0D221F) : const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            'Save',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF00A884) : const Color(0xFF008069),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.device.messages;
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    final headerBg = isDark ? const Color(0xFF111B21) : const Color(0xFFF0F2F5);
    final borderCol = isDark ? AppTheme.cardBorder : AppTheme.cardBorderLight;
    final textPrimaryColor = isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight;
    final textSecondaryColor = isDark ? AppTheme.textSecondary : AppTheme.textSecondaryLight;
    final chatBg = isDark ? const Color(0xFF0B141A) : const Color(0xFFEFEAE2);
    final inputBarBg = isDark ? const Color(0xFF1F2C34) : const Color(0xFFF0F2F5);
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
                CircleAvatar(
                  radius: 18,
                  backgroundColor: accentGreen,
                  backgroundImage: widget.device.imageUrl != null
                      ? NetworkImage(widget.device.imageUrl!)
                      : null,
                  child: widget.device.imageUrl == null
                      ? const Icon(Icons.hub_outlined, color: Colors.white, size: 20)
                      : null,
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: widget.device.isOnline ? const Color(0xFF2DD4BF) : Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.device.isOnline
                                ? 'Online'
                                : (widget.device.lastActiveTime.isNotEmpty && widget.device.lastActiveTime != 'Never'
                                    ? 'Offline • ${widget.device.lastActiveTime}'
                                    : 'Offline'),
                            style: TextStyle(
                              color: widget.device.isOnline ? const Color(0xFF2DD4BF) : textSecondaryColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

            ],
          ),
        ),
      ),

        // 2. Chat Message Stream (WhatsApp classic chat background)
        Expanded(
          child: Container(
            color: chatBg,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                return _buildMessageBubble(msg, isDark);
              },
            ),
          ),
        ),

        // 3. Quick Action Chips Row with working + Button
        Container(
          height: 48,
          color: headerBg,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ...Iterable.generate(widget.device.quickCommands.length).map((index) {
                final cmd = widget.device.quickCommands[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: GestureDetector(
                    onLongPress: () => _showEditCommandDialog(context, index, cmd, isDark),
                    child: ActionChip(
                      onPressed: () => _handleSend(cmd.message),
                      label: Text(cmd.label),
                      labelStyle: TextStyle(
                        color: textPrimaryColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      backgroundColor: textInputFill,
                      side: BorderSide(color: borderCol),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    ),
                  ),
                );
              }),

              // Working Add Quick Command (+) Button
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentGreen,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.add, color: Colors.white, size: 20),
                  onPressed: () => _showAddCommandDialog(context, isDark),
                  tooltip: 'Add Quick Command',
                ),
              ),
            ],
          ),
        ),

        // 4. Message / Command Input Bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          color: inputBarBg,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  style: TextStyle(color: textPrimaryColor, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(color: textSecondaryColor),
                    filled: true,
                    fillColor: textInputFill,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                onTap: () => _handleSend(),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: accentGreen,
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

  Widget _buildMessageBubble(ChatMessage msg, bool isDark) {
    final isUser = msg.isUser;
    final primaryTextColor = isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight;
    final secondaryTextColor = isDark ? AppTheme.textSecondary : AppTheme.textSecondaryLight;

    final userBubbleColor = isDark ? const Color(0xFF005C4B) : const Color(0xFFD9FDD3);
    final deviceBubbleColor = isDark ? const Color(0xFF202C33) : Colors.white;

    Widget bubbleContent;

    if (!isUser && msg.text.contains('Available Commands:')) {
      final parts = msg.text.split('Available Commands:');
      final statusText = parts[0].trim();
      final commandsBlock = parts.length > 1 ? parts[1].trim() : '';

      final lines = commandsBlock.split('\n');
      final parsedList = <Map<String, String>>[];
      for (final line in lines) {
        if (line.trim().startsWith('•')) {
          final cleanLine = line.replaceFirst('•', '').trim();
          final cmdParts = cleanLine.split(' : ');
          if (cmdParts.isNotEmpty) {
            final cmdKey = cmdParts[0].trim();
            final cmdDesc = cmdParts.length > 1 ? cmdParts[1].trim() : '';
            parsedList.add({'command': cmdKey, 'description': cmdDesc});
          }
        }
      }

      bubbleContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (statusText.isNotEmpty) ...[
            _buildRelayStatusHeader(statusText, isDark),
            const SizedBox(height: 12),
            Divider(color: secondaryTextColor.withOpacity(0.12), height: 1),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Icon(
                Icons.settings_remote_rounded,
                color: isDark ? const Color(0xFF2DD4BF).withOpacity(0.8) : const Color(0xFF008069).withOpacity(0.8),
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                'AVAILABLE ACTIONS',
                style: TextStyle(
                  color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF008069),
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: parsedList.map((cmd) => _buildCommandChip(
                  command: cmd['command']!,
                  isDark: isDark,
                )).toList(),
          ),
        ],
      );
    } else {
      bubbleContent = Text(
        msg.text,
        style: TextStyle(
          color: isUser
              ? (isDark ? Colors.white : AppTheme.textPrimaryLight)
              : primaryTextColor,
          fontSize: 14.5,
          height: 1.3,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bubbleContent,
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  msg.formattedTime,
                  style: TextStyle(
                    color: isUser
                        ? (isDark ? Colors.white.withOpacity(0.7) : AppTheme.textSecondaryLight)
                        : secondaryTextColor,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRelayStatusHeader(String statusText, bool isDark) {
    final statusList = statusText.split('|');
    final widgets = <Widget>[];

    for (final status in statusList) {
      final parts = status.split(':');
      if (parts.length == 2) {
        final name = parts[0].trim();
        final state = parts[1].trim();
        final isOn = state.toLowerCase() == 'on';

        final activeColor = isOn ? const Color(0xFF10B981) : const Color(0xFFEF4444); // Emerald Green vs Red
        final badgeColor = activeColor.withOpacity(0.12);

        widgets.add(
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F2C34).withOpacity(0.6) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08),
                ),
                boxShadow: isOn
                    ? [
                        BoxShadow(
                          color: activeColor.withOpacity(0.15),
                          blurRadius: 10,
                          spreadRadius: -2,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: isDark ? AppTheme.textSecondary : AppTheme.textSecondaryLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: activeColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: activeColor.withOpacity(0.5),
                              blurRadius: 6,
                              spreadRadius: 1,
                            )
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isOn ? 'ACTIVE' : 'INACTIVE',
                          style: TextStyle(
                            color: activeColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return Row(
      children: widgets,
    );
  }

  Color _getCommandColor(String command) {
    final lower = command.toLowerCase();
    if (lower.contains('on')) return const Color(0xFF10B981); // Emerald Green
    if (lower.contains('off')) return const Color(0xFFEF4444); // Red
    if (lower.contains('status')) return const Color(0xFF3B82F6); // Blue
    return const Color(0xFF8B5CF6); // Purple
  }

  Widget _buildCommandChip({
    required String command,
    required bool isDark,
  }) {
    final cmdColor = _getCommandColor(command);
    final cardBg = isDark ? const Color(0xFF1F2C34) : const Color(0xFFF8FAFC);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleSend(command),
        borderRadius: BorderRadius.circular(16),
        hoverColor: cmdColor.withOpacity(0.08),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: cmdColor.withOpacity(0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.play_arrow_rounded,
                color: cmdColor,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                command,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                  color: cmdColor,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
