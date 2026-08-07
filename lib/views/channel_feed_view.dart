import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/channel_model.dart';
import '../providers/knowledge_provider.dart';
import '../providers/user_session_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';

class ChannelFeedView extends StatelessWidget {
  final Channel channel;
  final VoidCallback onBack;

  const ChannelFeedView({
    super.key,
    required this.channel,
    required this.onBack,
  });

  IconData _getResourceIcon(String type) {
    switch (type) {
      case 'youtube':
        return Icons.play_circle_fill_rounded;
      case 'connection':
        return Icons.link_rounded;
      case 'pdf':
      default:
        return Icons.picture_as_pdf_rounded;
    }
  }

  Color _getResourceColor(String type) {
    switch (type) {
      case 'youtube':
        return const Color(0xFFEF4444); // Red
      case 'connection':
        return const Color(0xFF3B82F6); // Blue
      case 'pdf':
      default:
        return const Color(0xFFF97316); // Orange
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final knowledgeProvider = context.watch<KnowledgeProvider>();
    final isFollowing = knowledgeProvider.isFollowing(channel.id);

    final headerBg = isDark ? const Color(0xFF111B21) : const Color(0xFFF0F2F5);
    final borderCol = isDark ? AppTheme.cardBorder : AppTheme.cardBorderLight;
    final textPrimaryColor = isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight;
    final textSecondaryColor = isDark ? AppTheme.textSecondary : AppTheme.textSecondaryLight;
    final chatBg = isDark ? const Color(0xFF0B141A) : const Color(0xFFEFEAE2);
    final accentGreen = isDark ? const Color(0xFF00A884) : const Color(0xFF008069);
    final cardBg = isDark ? const Color(0xFF1E2630) : Colors.white;
    final bubbleColor = isDark ? const Color(0xFF202C33) : Colors.white;

    return Column(
      children: [
        // 1. Channel Header Bar (Screenshot 3 style)
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: headerBg,
            border: Border(
              bottom: BorderSide(color: borderCol, width: 1),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: textPrimaryColor),
                onPressed: onBack,
              ),
              CircleAvatar(
                radius: 18,
                backgroundColor: accentGreen,
                child: const Icon(Icons.memory_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name,
                      style: TextStyle(
                        color: textPrimaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: textSecondaryColor),
                color: isDark ? const Color(0xFF233138) : Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                offset: const Offset(0, 40),
                onSelected: (value) async {
                  if (value == 'unfollow') {
                    final token = context.read<UserSessionProvider>().session.token;
                    if (token == null) return;
                    final messenger = ScaffoldMessenger.of(context);
                    
                    final error = await knowledgeProvider.toggleFollow(channel.id, token);
                    if (error != null) {
                      messenger.showSnackBar(SnackBar(content: Text('Failed to unfollow: $error'), backgroundColor: Colors.redAccent));
                    }
                  }
                },
                itemBuilder: (context) => [
                  if (isFollowing)
                    PopupMenuItem(
                      value: 'unfollow',
                      height: 40,
                      child: Text(
                        'Unfollow Channel',
                        style: TextStyle(
                          color: isDark ? const Color(0xFFD1D7DB) : Colors.black87,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        // 2. Feed Body
        Expanded(
          child: Container(
            color: chatBg,
            width: double.infinity,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 550),
                  child: Column(
                    children: [
                      // Date Separator Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E2630) : const Color(0xFFE1E5EB),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Today',
                          style: TextStyle(
                            color: textSecondaryColor,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Channel Announcement Bubble (Screenshot 3)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: bubbleColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          channel.description,
                          style: TextStyle(
                            color: textPrimaryColor,
                            fontSize: 14.5,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Clickable Resource Links Cards (Screenshot 3)
                      ...channel.resources.map((resource) {
                        final iconData = _getResourceIcon(resource.type);
                        final iconCol = _getResourceColor(resource.type);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Material(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(14),
                            elevation: 1,
                            shadowColor: Colors.black.withValues(alpha: 0.3),
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: iconCol.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(iconData, color: iconCol, size: 24),
                              ),
                              title: Text(
                                resource.title,
                                style: TextStyle(
                                  color: textPrimaryColor,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  resource.url,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: accentGreen,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                              trailing: Icon(
                                Icons.open_in_new_rounded,
                                color: textSecondaryColor,
                                size: 18,
                              ),
                              onTap: () {
                                // Handles launching or copying the url
                              },
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
