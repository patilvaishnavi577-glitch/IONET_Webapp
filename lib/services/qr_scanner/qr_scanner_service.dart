import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'qr_scanner_stub.dart'
    if (dart.library.js_interop) 'qr_scanner_web.dart';

class QrParsedData {
  final String deviceId;
  final String? deviceName;

  const QrParsedData({
    required this.deviceId,
    this.deviceName,
  });
}

class QrScannerService {
  /// Launches the QR scanner. Returns the raw decoded string, or null if canceled.
  static Future<String?> scan(BuildContext context) async {
    if (kIsWeb) {
      return await QrScannerPlatform.scan();
    }
    // In non-web platforms or when platform scanner isn't attached
    return null;
  }

  /// Parses any scanned QR code payload cleanly without any hardcoded values.
  /// Handles JSON, URLs, key=value, or plain text device IDs.
  static QrParsedData parseDeviceQr(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const QrParsedData(deviceId: '');
    }

    // Case 1: JSON payload (e.g. {"deviceId": "IONET001", "deviceName": "Living Room Tank"})
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          String? id;
          for (final key in ['deviceId', 'device_id', 'id', 'hwId', 'hardwareId']) {
            if (decoded.containsKey(key) && decoded[key] != null) {
              id = decoded[key].toString().trim();
              if (id.isNotEmpty) break;
            }
          }

          String? name;
          for (final key in ['deviceName', 'device_name', 'name', 'label', 'title']) {
            if (decoded.containsKey(key) && decoded[key] != null) {
              name = decoded[key].toString().trim();
              if (name.isNotEmpty) break;
            }
          }

          if (id != null && id.isNotEmpty) {
            return QrParsedData(deviceId: id, deviceName: name);
          }
        }
      } catch (_) {}
    }

    // Case 2: URL (e.g. https://.../device/IONET001 or ...?deviceId=IONET001)
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      try {
        final uri = Uri.parse(trimmed);
        final queryId = uri.queryParameters['deviceId'] ??
            uri.queryParameters['device_id'] ??
            uri.queryParameters['id'];
        if (queryId != null && queryId.trim().isNotEmpty) {
          final queryName = uri.queryParameters['deviceName'] ??
              uri.queryParameters['device_name'] ??
              uri.queryParameters['name'];
          return QrParsedData(deviceId: queryId.trim(), deviceName: queryName?.trim());
        }

        // Check path segments (e.g. /device/IONET001)
        if (uri.pathSegments.isNotEmpty) {
          final lastSegment = uri.pathSegments.last.trim();
          if (lastSegment.isNotEmpty) {
            return QrParsedData(deviceId: lastSegment);
          }
        }
      } catch (_) {}
    }

    // Case 3: Key-Value pairs (e.g. deviceId=IONET001 or ID: IONET001)
    if (trimmed.contains('=') || trimmed.contains(':')) {
      final parts = trimmed.split(RegExp(r'[;&,\n]'));
      String? foundId;
      String? foundName;
      for (final p in parts) {
        final kv = p.split(RegExp(r'[:=]'));
        if (kv.length == 2) {
          final k = kv[0].trim().toLowerCase();
          final v = kv[1].trim();
          if (k == 'deviceid' || k == 'device_id' || k == 'id' || k == 'hwid') {
            foundId = v;
          } else if (k == 'devicename' || k == 'device_name' || k == 'name') {
            foundName = v;
          }
        }
      }
      if (foundId != null && foundId.isNotEmpty) {
        return QrParsedData(deviceId: foundId, deviceName: foundName);
      }
    }

    // Case 4: Plain Device ID (e.g. IONET001, SC-1002, ESP32_WATER)
    return QrParsedData(deviceId: trimmed);
  }
}
