import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';

class SupportBotView extends StatefulWidget {
  final VoidCallback onBack;

  const SupportBotView({
    super.key,
    required this.onBack,
  });

  @override
  State<SupportBotView> createState() => _SupportBotViewState();
}

class _SupportBotViewState extends State<SupportBotView> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [
    {
      'text': 'Hi there! I am the IONet support bot. How can I help you today?',
      'isUser': false,
      'time': '10:41',
    },
  ];

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

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();

    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    setState(() {
      _messages.add({
        'text': text,
        'isUser': true,
        'time': timeStr,
      });
    });
    _scrollToBottom();

    // Auto Response Delay
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      final responseText = _generateBotResponse(text);
      final rTime = DateTime.now();
      final rTimeStr = '${rTime.hour.toString().padLeft(2, '0')}:${rTime.minute.toString().padLeft(2, '0')}';

      setState(() {
        _messages.add({
          'text': responseText,
          'isUser': false,
          'time': rTimeStr,
        });
      });
      _scrollToBottom();
    });
  }

  String _generateBotResponse(String query) {
    final q = query.toLowerCase();
    if (q.contains('add') || q.contains('device')) {
      return 'To add a device, go to the Devices tab and click the + floating action button.';
    } else if (q.contains('command') || q.contains('quick')) {
      return 'Quick commands are shortcut actions (like Status, Reboot) located right above the input box in a device chat.';
    } else if (q.contains('qr') || q.contains('scan')) {
      return 'You can scan a QR code by clicking the scanner icon inside the Add Device dialog.';
    } else if (q.contains('credits')) {
      return 'Credits are demo points shown in the top-left corner of the home screen.';
    } else {
      return 'I understand you are asking about "$query". As a mock bot, I recommend checking our FAQs!';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    final headerBg = isDark ? const Color(0xFF111B21) : const Color(0xFFF0F2F5);
    final borderCol = isDark ? AppTheme.cardBorder : AppTheme.cardBorderLight;
    final textPrimaryColor = isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight;
    final textSecondaryColor = isDark ? AppTheme.textSecondary : AppTheme.textSecondaryLight;
    final chatBg = isDark ? const Color(0xFF0B141A) : const Color(0xFFEFEAE2);
    final inputBarBg = isDark ? const Color(0xFF1F2C34) : const Color(0xFFF0F2F5);
    final textInputFill = isDark ? const Color(0xFF2A3942) : Colors.white;
    final accentGreen = isDark ? const Color(0xFF00A884) : const Color(0xFF008069);

    final userBubbleColor = isDark ? const Color(0xFF005C4B) : const Color(0xFFD9FDD3);
    final botBubbleColor = isDark ? const Color(0xFF202C33) : Colors.white;

    return Column(
      children: [
        // 1. Header Bar (Screenshot 3)
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: headerBg,
            border: Border(
              bottom: BorderSide(
                color: borderCol,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: textPrimaryColor,
                ),
                onPressed: widget.onBack,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Center(
                  child: Text(
                    'Support Bot',
                    style: TextStyle(
                      color: textPrimaryColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 48), // Spacing placeholder for balanced alignment
            ],
          ),
        ),

        // 2. Chat Message Stream (Screenshot 3)
        Expanded(
          child: Container(
            color: chatBg,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['isUser'] as bool;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isUser ? userBubbleColor : botBubbleColor,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isUser ? 18 : 4),
                          bottomRight: Radius.circular(isUser ? 4 : 18),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            msg['text'] as String,
                            style: TextStyle(
                              color: isUser
                                  ? (isDark ? Colors.white : AppTheme.textPrimaryLight)
                                  : textPrimaryColor,
                              fontSize: 14.5,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Text(
                              msg['time'] as String,
                              style: TextStyle(
                                color: isUser
                                    ? (isDark ? Colors.white.withValues(alpha: 0.7) : AppTheme.textSecondaryLight)
                                    : textSecondaryColor,
                                fontSize: 10.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // 3. Message Input Bar (Screenshot 3)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: BoxDecoration(
            color: inputBarBg,
            border: Border(
              top: BorderSide(
                color: borderCol,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  style: TextStyle(
                    color: textPrimaryColor,
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type your query...',
                    hintStyle: TextStyle(
                      color: textSecondaryColor,
                    ),
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
              GestureDetector(
                onTap: _handleSend,
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
  }
}
