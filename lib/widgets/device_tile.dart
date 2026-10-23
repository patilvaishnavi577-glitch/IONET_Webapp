import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/device_model.dart';
import '../providers/device_provider.dart';
import '../theme/app_theme.dart';

class DeviceTile extends StatelessWidget {
  final Device device;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onConfigTap;
  final VoidCallback? onWifiSetupTap;
  final VoidCallback? onDeleteTap;

  const DeviceTile({
    super.key,
    required this.device,
    required this.isSelected,
    required this.onTap,
    this.onDoubleTap,
    this.onConfigTap,
    this.onWifiSetupTap,
    this.onDeleteTap,
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
                      device.messages.isNotEmpty
                          ? _formatPreviewText(context, device.messages.last.text)
                          : 'No messages yet',
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

              // Unread Badge (if any)
              if (device.unreadCount > 0) ...[
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
                const SizedBox(width: 4),
              ],

              // 3-Dot Options Menu
              Material(
                color: Colors.transparent,
                child: PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: isDark ? AppTheme.textSecondary : AppTheme.textSecondaryLight,
                    size: 20,
                  ),
                  tooltip: 'Device Options',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 18,
                  onSelected: (val) {
                    if (val == 'config') {
                      onConfigTap?.call();
                    } else if (val == 'wifi_setup') {
                      onWifiSetupTap?.call();
                    } else if (val == 'delete') {
                      onDeleteTap?.call();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      value: 'config',
                      child: Row(
                        children: const [
                          Icon(Icons.tune_rounded, size: 18, color: Color(0xFF00A884)),
                          SizedBox(width: 10),
                          Text('Configuration', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'wifi_setup',
                      child: Row(
                        children: const [
                          Icon(Icons.wifi_rounded, size: 18, color: Color(0xFF00A884)),
                          SizedBox(width: 10),
                          Text('Wi-Fi Setup', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    if (onDeleteTap != null)
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: const [
                            Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                            SizedBox(width: 10),
                            Text('Delete Device', style: TextStyle(fontSize: 13, color: Colors.redAccent, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  String _formatPreviewText(BuildContext context, String text) {
    final trimmed = text.trim();
    if (trimmed.startsWith('__CLICKABLE__:')) {
      return 'Device Status';
    }
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final parsed = jsonDecode(trimmed);
        if (parsed is Map) {
          if (parsed['type']?.toString().toUpperCase() == 'CLICKABLE') {
            return 'Device Status';
          }
          if (parsed['message'] != null && parsed['message'].toString().trim().isNotEmpty) {
            return parsed['message'].toString().trim();
          }
          if (parsed['status'] != null && parsed['status'].toString().trim().isNotEmpty) {
            return parsed['status'].toString().trim();
          }
          return 'Status: Online • Ready';
        }
      } catch (_) {}
    }
    var firstLine = trimmed.split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => trimmed);
    try {
      final devId = device.deviceId.isNotEmpty ? device.deviceId : device.id;
      final savedConfig = Provider.of<DeviceProvider>(context, listen: false).getDeviceSavedConfig(devId);
      savedConfig.forEach((key, val) {
        if (val != null && val.toString().trim().isNotEmpty) {
          final cStr = val.toString().trim();
          final keyClean = key.toString().trim();
          if (keyClean.toLowerCase().startsWith('relay ') ||
              keyClean.toLowerCase().startsWith('channel ') ||
              keyClean.toLowerCase().startsWith('slot ') ||
              RegExp(r'^\d+$').hasMatch(keyClean)) {
            firstLine = firstLine.replaceAll(RegExp(RegExp.escape(keyClean) + r'\b', caseSensitive: false), cStr);
          }
        }
      });
    } catch (_) {}
    return firstLine;
  }
}
