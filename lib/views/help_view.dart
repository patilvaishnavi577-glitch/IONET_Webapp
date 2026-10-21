import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/knowledge_provider.dart';
import '../theme/app_theme.dart';

class HelpView extends StatefulWidget {
  final VoidCallback? onBack;

  const HelpView({
    super.key,
    this.onBack,
  });

  @override
  State<HelpView> createState() => _HelpViewState();
}

class _HelpViewState extends State<HelpView> {
  final List<bool> _expandedStates = [false, false, false, false];

  final List<Map<String, String>> _faqs = [
    {
      'question': 'How do I add a device?',
      'answer': 'Go to the Devices tab and click the + floating button to add a new device by ID or QR scan.',
    },
    {
      'question': 'What is a Quick Command?',
      'answer': 'Quick commands are pre-set messages you can send to your devices instantly. You can long-press to edit them.',
    },
    {
      'question': 'How do I scan a QR code?',
      'answer': 'Click the scanner icon inside the Add Device dialog to scan a device QR code using your camera.',
    },
    {
      'question': 'How do I share a device?',
      'answer': 'Open the device profile settings from the top-right menu to manage shared access with other users.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Container(
      color: isDark ? AppTheme.scaffoldBg : AppTheme.scaffoldBgLight,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header (Screenshot 1 - with back button support)
                Row(
                  children: [
                    if (widget.onBack != null)
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight,
                        ),
                        onPressed: widget.onBack,
                      ),
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.only(right: widget.onBack != null ? 48.0 : 0.0),
                          child: Text(
                            'Help',
                            style: TextStyle(
                              color: isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight,
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Frequently Asked Questions Section Header
                Text(
                  'Frequently Asked Questions',
                  style: TextStyle(
                    color: isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 18),

                // Collapsible FAQ Accordion Items (Screenshot 1 & 2)
                ...List.generate(_faqs.length, (index) {
                  final faq = _faqs[index];
                  final isExpanded = _expandedStates[index];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.cardBg : AppTheme.cardBgLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppTheme.cardBorder : AppTheme.cardBorderLight,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                _expandedStates[index] = !isExpanded;
                              });
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      faq['question']!,
                                      style: TextStyle(
                                        color: isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                    color: isDark ? AppTheme.textSecondary : AppTheme.textSecondaryLight,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                           if (isExpanded) ...[
                            Divider(
                              height: 1,
                              color: isDark ? AppTheme.cardBorder : AppTheme.cardBorderLight,
                            ),
                            Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Text(
                                faq['answer']!,
                                style: TextStyle(
                                  color: isDark ? AppTheme.textSecondary : AppTheme.textSecondaryLight,
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 28),

                // Still Need Help? Section (Screenshot 1)
                Text(
                  'Still need help?',
                  style: TextStyle(
                    color: isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Support Bot Tile Button (Screenshot 1)
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.cardBg : AppTheme.cardBgLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppTheme.cardBorder : AppTheme.cardBorderLight,
                      width: 1,
                    ),
                  ),
                  child: InkWell(
                    onTap: () {
                      context.read<KnowledgeProvider>().setShowSupportBot(true);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF00A884) : const Color(0xFF008069),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.support_agent_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Chat with Support Bot',
                                  style: TextStyle(
                                    color: isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight,
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Get instant answers to minor queries.',
                                  style: TextStyle(
                                    color: isDark ? AppTheme.textSecondary : AppTheme.textSecondaryLight,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: isDark ? AppTheme.textSecondary : AppTheme.textSecondaryLight,
                            size: 20,
                          ),
                        ],
                      ),
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
}
