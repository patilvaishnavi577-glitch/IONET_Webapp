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

  void _handleSend([String? prefilledCommand]) {
    if (!widget.device.isOnline) return;
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
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (dialogCtx) => AlertDialog(
                              backgroundColor: Theme.of(context).cardColor,
                              title: const Text('Delete Command'),
                              content: const Text('Are you sure you want to delete this quick command?'),
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

                          if (confirmed == true) {
                            context.read<DeviceProvider>().deleteQuickCommand(
                                  widget.device.id,
                                  indexToEdit,
                                );
                            if (mounted) Navigator.of(dialogContext).pop();
                          }
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
                                        : 'Offline')),
                            style: TextStyle(
                              color: widget.device.isOnline ? const Color(0xFF2DD4BF) : (widget.device.statusMessage == 'Connecting...' ? Colors.orangeAccent : textSecondaryColor),
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

    final bubbleContent = CommandText(
      text: msg.text,
      isUser: isUser,
      isDark: isDark,
      accentGreen: accentGreen,
      primaryTextColor: primaryTextColor,
      onCommandTap: (cmd) => _handleSend(cmd),
    );

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
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
            child: Text(
              _getInitials(widget.device.name),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.scaffoldBg : const Color(0xFF54656F),
              ),
            ),
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
