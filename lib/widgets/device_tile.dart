import 'package:flutter/material.dart';
import '../models/device_model.dart';
import '../theme/app_theme.dart';

class DeviceTile extends StatelessWidget {
  final Device device;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;

  const DeviceTile({
    super.key,
    required this.device,
    required this.isSelected,
    required this.onTap,
    this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg = isDark ? AppTheme.inputBg : const Color(0xFFF0F2F5);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.cardBorder : AppTheme.cardBorderLight,
          width: 1,
        ),
      ),
      child: Material(
        color: isSelected ? activeBg : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onDoubleTap: onDoubleTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              // Default/Custom Device Avatar with proper fit & contrast
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: device.imageUrl != null
                      ? Colors.transparent
                      : (isDark ? const Color(0xFF202C33) : const Color(0xFFF0F2F5)),
                  shape: BoxShape.circle,
                ),
                padding: device.imageUrl != null ? EdgeInsets.zero : const EdgeInsets.all(6),
                child: ClipOval(
                  child: device.imageUrl != null
                      ? Image.network(
                          device.imageUrl!,
                          width: 46,
                          height: 46,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Padding(
                            padding: const EdgeInsets.all(6),
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        )
                      : Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                        ),
                ),
              ),
              const SizedBox(width: 14),

              // Device Name & Status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: TextStyle(
                        color: isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      device.messages.isNotEmpty ? device.messages.last.text : 'No messages yet',
                      style: TextStyle(
                        color: isDark ? AppTheme.textSecondary : AppTheme.textSecondaryLight,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Timestamp and Unread Badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '07:29', // Mock timestamp to match design
                    style: TextStyle(
                      color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 6),

              // Unread Badge (if any)
              if (device.unreadCount > 0)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2563EB),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${device.unreadCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
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
    );
  }
}
