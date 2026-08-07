import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/update_model.dart';
import '../providers/theme_provider.dart';
import '../providers/updates_provider.dart';
import '../theme/app_theme.dart';

class UpdatesView extends StatelessWidget {
  const UpdatesView({super.key});

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    }
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final textPrimaryColor = isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight;
    final textSecondaryColor = isDark ? AppTheme.textSecondary : AppTheme.textSecondaryLight;
    final bgCol = isDark ? const Color(0xFF111B21) : const Color(0xFFF8FAFC);
    final sectionTitleColor = isDark ? const Color(0xFF00A884) : const Color(0xFF008069);

    final updatesProvider = context.watch<UpdatesProvider>();
    final updates = updatesProvider.updates;
    final isLoading = updatesProvider.isLoading;

    // Separate into Recent (unseen) and Viewed (seen) updates
    final recentUpdates = updates.where((u) => !updatesProvider.isUpdateSeen(u.id)).toList();
    final viewedUpdates = updates.where((u) => updatesProvider.isUpdateSeen(u.id)).toList();

    return Container(
      color: bgCol,
      child: Column(
        children: [
          // Header / Refresh option row
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'System Updates',
                  style: TextStyle(
                    color: textPrimaryColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.refresh,
                    color: isDark ? AppTheme.textSecondary : AppTheme.textSecondaryLight,
                  ),
                  onPressed: () => context.read<UpdatesProvider>().fetchUpdates(),
                ),
              ],
            ),
          ),

          Expanded(
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: isDark ? AppTheme.focusedBorder : AppTheme.focusedBorderLight,
                    ),
                  )
                : updates.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF202C33) : const Color(0xFFF0F2F5),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.system_update_alt_rounded,
                                  size: 48,
                                  color: isDark ? AppTheme.focusedBorder : AppTheme.focusedBorderLight,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'No Updates Yet',
                                style: TextStyle(
                                  color: textPrimaryColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Your system and firmware are currently up to date.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: textSecondaryColor,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: [
                          if (recentUpdates.isNotEmpty) ...[
                            _buildSectionHeader('Recent updates', sectionTitleColor),
                            ...recentUpdates.map((item) => _buildStatusTile(
                                  context,
                                  item,
                                  isSeen: false,
                                  textPrimaryColor: textPrimaryColor,
                                  textSecondaryColor: textSecondaryColor,
                                )),
                            const SizedBox(height: 16),
                          ],
                          if (viewedUpdates.isNotEmpty) ...[
                            _buildSectionHeader('Viewed updates', textSecondaryColor),
                            ...viewedUpdates.map((item) => _buildStatusTile(
                                  context,
                                  item,
                                  isSeen: true,
                                  textPrimaryColor: textPrimaryColor.withOpacity(0.8),
                                  textSecondaryColor: textSecondaryColor,
                                )),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatusTile(
    BuildContext context,
    SystemUpdate item, {
    required bool isSeen,
    required Color textPrimaryColor,
    required Color textSecondaryColor,
  }) {
    final activeUpdate = context.watch<UpdatesProvider>().selectedUpdate;
    final isSelected = activeUpdate?.id == item.id;
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final hoverBg = isDark ? const Color(0xFF202C33) : const Color(0xFFF0F2F5);

    return Material(
      color: isSelected ? hoverBg : Colors.transparent,
      child: ListTile(
        onTap: () {
          context.read<UpdatesProvider>().selectUpdate(item);
        },
        leading: StatusRingAvatar(
          isSeen: isSeen,
          child: CircleAvatar(
            backgroundColor: const Color(0xFF00A884).withOpacity(0.15),
            radius: 20,
            child: const Icon(Icons.security_update_good, color: Color(0xFF00A884), size: 20),
          ),
        ),
        title: Text(
          item.title,
          style: TextStyle(
            color: textPrimaryColor,
            fontSize: 15.5,
            fontWeight: isSeen ? FontWeight.normal : FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            '${_formatTimeAgo(item.timestamp)} • ${item.description}',
            style: TextStyle(
              color: textSecondaryColor,
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: item.fileUrls.isNotEmpty
            ? Icon(Icons.image, size: 18, color: textSecondaryColor.withOpacity(0.6))
            : null,
      ),
    );
  }
}

class StatusRingAvatar extends StatelessWidget {
  final bool isSeen;
  final Widget child;

  const StatusRingAvatar({
    super.key,
    required this.isSeen,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2.0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSeen ? Colors.grey.withOpacity(0.4) : const Color(0xFF00A884),
          width: 2.2,
        ),
      ),
      child: child,
    );
  }
}
