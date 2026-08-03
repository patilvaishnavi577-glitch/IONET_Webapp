import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/channel_model.dart';
import '../providers/knowledge_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import 'channel_feed_view.dart';

class KnowledgeView extends StatefulWidget {
  const KnowledgeView({super.key});

  @override
  State<KnowledgeView> createState() => _KnowledgeViewState();
}

class _KnowledgeViewState extends State<KnowledgeView> {
  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final knowledgeProvider = context.watch<KnowledgeProvider>();

    final mediaQuery = MediaQuery.of(context);
    final isDesktop = mediaQuery.size.width > 768;

    final selectedChannel = knowledgeProvider.selectedChannel;

    // On mobile, if a channel is selected, show its full-screen feed view
    if (!isDesktop && selectedChannel != null) {
      return ChannelFeedView(
        channel: selectedChannel,
        onBack: () {
          knowledgeProvider.selectChannel(null);
        },
      );
    }

    final allChannels = knowledgeProvider.channels;

    final textPrimaryColor = isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight;
    final textSecondaryColor = isDark ? AppTheme.textSecondary : AppTheme.textSecondaryLight;
    final borderCol = isDark ? AppTheme.cardBorder : AppTheme.cardBorderLight;
    final sidebarBg = isDark ? const Color(0xFF111B21) : Colors.white;

    return Container(
      color: sidebarBg,
      child: Column(
        children: [
          // Header Bar
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111B21) : Colors.white,
              border: Border(
                bottom: BorderSide(color: borderCol, width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Support',
                  style: TextStyle(
                    color: textPrimaryColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Channel Lists Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Channels',
                    style: TextStyle(
                      color: textPrimaryColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Stay updated on topics that matter to you.',
                    style: TextStyle(
                      color: textSecondaryColor,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),

                  ...allChannels.map((channel) {
                    final isSelectedOnDesktop = isDesktop && selectedChannel?.id == channel.id;
                    return _buildChannelTile(
                      channel: channel,
                      isDark: isDark,
                      isSelected: isSelectedOnDesktop,
                      onTap: () {
                        knowledgeProvider.selectChannel(channel.id);
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelTile({
    required Channel channel,
    required bool isDark,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final textPrimaryColor = isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight;
    final textSecondaryColor = isDark ? AppTheme.textSecondary : AppTheme.textSecondaryLight;
    final accentGreen = isDark ? const Color(0xFF00A884) : const Color(0xFF008069);

    final tileBg = isSelected
        ? (isDark ? const Color(0xFF2A3942) : const Color(0xFFF0F2F5))
        : (isDark ? const Color(0xFF111B21) : Colors.white);

    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.cardBorder : AppTheme.cardBorderLight,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: accentGreen,
                child: const Icon(
                  Icons.memory_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name,
                      style: TextStyle(
                        color: textPrimaryColor,
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      channel.followers,
                      style: TextStyle(
                        color: textSecondaryColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
