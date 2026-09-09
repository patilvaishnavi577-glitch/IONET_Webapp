import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/device_model.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';

class DeviceProvider extends ChangeNotifier {

  static Map<String, dynamic> _extractDataPreservingDuplicates(dynamic rawData, Map<String, dynamic>? fallbackData) {
    if (rawData == null) return fallbackData ?? {};
    final String rawJson = rawData is String
        ? rawData
        : (rawData is List<int> ? utf8.decode(rawData) : rawData.toString());

    try {
      final dataKeyMatch = RegExp(r'"data"\s*:\s*\{').firstMatch(rawJson);
      if (dataKeyMatch == null) {
        return fallbackData ?? {};
      }

      final openBraceIndex = rawJson.indexOf('{', dataKeyMatch.start);
      if (openBraceIndex == -1) {
        return fallbackData ?? {};
      }

      int depth = 0;
      int closeBraceIndex = -1;
      bool inString = false;
      bool isEscaped = false;

      for (int i = openBraceIndex; i < rawJson.length; i++) {
        final char = rawJson[i];
        if (isEscaped) {
          isEscaped = false;
          continue;
        }
        if (char == '\\') {
          isEscaped = true;
          continue;
        }
        if (char == '"') {
          inString = !inString;
          continue;
        }
        if (!inString) {
          if (char == '{') {
            depth++;
          } else if (char == '}') {
            depth--;
            if (depth == 0) {
              closeBraceIndex = i;
              break;
            }
          }
        }
      }

      if (closeBraceIndex == -1) {
        return fallbackData ?? {};
      }

      final dataContent = rawJson.substring(openBraceIndex + 1, closeBraceIndex);

      final RegExp pairRegex = RegExp(r'"([^"\\]*(?:\\.[^"\\]*)*)"\s*:\s*("([^"\\]*(?:\\.[^"\\]*)*)"|[0-9.]+|true|false|null)');
      final matches = pairRegex.allMatches(dataContent).toList();

      if (matches.isEmpty) {
        return fallbackData ?? {};
      }

      final Map<String, int> totalOccurrences = {};
      for (final match in matches) {
        String key = match.group(1) ?? '';
        key = key.replaceAll(r'\"', '"');
        totalOccurrences[key] = (totalOccurrences[key] ?? 0) + 1;
      }

      final Map<String, dynamic> result = {};
      final Map<String, int> currentCounts = {};

      for (final match in matches) {
        String key = match.group(1) ?? '';
        key = key.replaceAll(r'\"', '"');

        final rawVal = match.group(2) ?? '';
        dynamic val;
        if (rawVal.startsWith('"') && rawVal.endsWith('"')) {
          val = rawVal.substring(1, rawVal.length - 1).replaceAll(r'\"', '"');
        } else if (rawVal == 'true') {
          val = true;
        } else if (rawVal == 'false') {
          val = false;
        } else if (rawVal == 'null') {
          val = null;
        } else {
          val = num.tryParse(rawVal) ?? rawVal;
        }

        currentCounts[key] = (currentCounts[key] ?? 0) + 1;
        final currentIdx = currentCounts[key]!;

        String finalKey = key;
        if ((totalOccurrences[key] ?? 0) > 1) {
          finalKey = '$key $currentIdx';
        }

        result[finalKey] = val;
      }

      return result;
    } catch (e) {
      debugPrint('Error extracting duplicate keys from raw JSON: $e');
      return fallbackData ?? {};
    }
  }

  final ApiService _apiService = ApiService();
  final List<Device> _devices = [];
  String? _selectedDeviceId;
  String _searchQuery = '';
  bool _isLoading = false;
  String? _currentUserId;
  String? _token;

  WebSocketChannel? _webSocketChannel;
  StreamSubscription? _webSocketSubscription;
  Timer? _watchdogTimer;
  bool _isReconnecting = false;
  Timer? _reconnectTimer;
  final Map<String, Map<String, dynamic>> _latestDeviceStatusData = {};
  final Map<String, List<QuickCommand>> _customQuickCommands = {};
  final Map<String, List<QuickCommand>> _deviceQuickCommands = {};

  List<Device> get devices {
    if (_searchQuery.isEmpty) {
      return _devices;
    }
    return _devices
        .where((d) => d.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  Device? get selectedDevice {
    if (_selectedDeviceId == null) return null;
    try {
      return _devices.firstWhere((d) => d.id == _selectedDeviceId);
    } catch (_) {
      return null;
    }
  }

  String? get selectedDeviceId => _selectedDeviceId;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;

  Map<String, dynamic>? getLatestDeviceStatusData(String deviceId) =>
      _latestDeviceStatusData[deviceId];
  List<QuickCommand> getDeviceCommands(String deviceId) =>
      _deviceQuickCommands[deviceId] ?? [];
  List<QuickCommand> getCustomCommands(String deviceId) =>
      _customQuickCommands[deviceId] ?? [];

  List<QuickCommand> getQuickCommands(String deviceId) {
    // Only return live commands received dynamically from device
    final deviceCmds = _deviceQuickCommands[deviceId] ?? [];
    if (deviceCmds.isNotEmpty) return deviceCmds;
    // Fallback if indexed under id or deviceId
    for (final entry in _deviceQuickCommands.entries) {
      if (entry.key == deviceId && entry.value.isNotEmpty) {
        return entry.value;
      }
    }
    return [];
  }

  void _syncDeviceQuickCommands(String deviceId) {
    final idx = _devices.indexWhere((d) => d.id == deviceId || d.deviceId == deviceId);
    if (idx != -1) {
      final dev = _devices[idx];
      _devices[idx] = dev.copyWith(quickCommands: getQuickCommands(dev.deviceId));
      notifyListeners();
    }
  }

  Future<void> loadCustomCommands(String deviceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? saved = prefs.getStringList('custom_commands_$deviceId');
      if (saved != null) {
        final List<QuickCommand> loaded = saved.map((s) {
          final decoded = jsonDecode(s);
          return QuickCommand.fromJson(Map<String, dynamic>.from(decoded as Map));
        }).toList();
        _customQuickCommands[deviceId] = loaded;
        _syncDeviceQuickCommands(deviceId);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading custom commands: $e');
    }
  }

  Future<void> addDeviceQuickCommand(String deviceId, QuickCommand command) async {
    if (!_customQuickCommands.containsKey(deviceId)) {
      _customQuickCommands[deviceId] = [];
    }
    if (_customQuickCommands[deviceId]!.any((c) => c.message == command.message)) return;
    _customQuickCommands[deviceId]!.add(command);
    _syncDeviceQuickCommands(deviceId);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = _customQuickCommands[deviceId]!.map((c) => jsonEncode(c.toJson())).toList();
      await prefs.setStringList('custom_commands_$deviceId', listJson);
    } catch (e) {
      debugPrint('Error saving custom command: $e');
    }
  }

  Future<void> editDeviceQuickCommand(String deviceId, QuickCommand oldCmd, QuickCommand newCmd) async {
    if (_customQuickCommands.containsKey(deviceId)) {
      final list = _customQuickCommands[deviceId]!;
      final index = list.indexWhere((c) => c.message == oldCmd.message && c.label == oldCmd.label);
      if (index != -1) {
        list[index] = newCmd;
        _syncDeviceQuickCommands(deviceId);
        notifyListeners();

        try {
          final prefs = await SharedPreferences.getInstance();
          final listJson = list.map((c) => jsonEncode(c.toJson())).toList();
          await prefs.setStringList('custom_commands_$deviceId', listJson);
        } catch (e) {
          debugPrint('Error editing custom command: $e');
        }
      }
    }
  }

  Future<void> deleteDeviceQuickCommand(String deviceId, QuickCommand command) async {
    if (_customQuickCommands.containsKey(deviceId)) {
      _customQuickCommands[deviceId]!.removeWhere((c) => c.message == command.message);
      _syncDeviceQuickCommands(deviceId);
      notifyListeners();

      try {
        final prefs = await SharedPreferences.getInstance();
        final listJson = _customQuickCommands[deviceId]!.map((c) => jsonEncode(c.toJson())).toList();
        await prefs.setStringList('custom_commands_$deviceId', listJson);
      } catch (e) {
        debugPrint('Error deleting custom command: $e');
      }
    }
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  void selectDevice(String? id) {
    if (_selectedDeviceId == id) return;

    _selectedDeviceId = id;
    
    final device = _devices.firstWhere((d) => d.id == id, orElse: () => Device(id: '', deviceId: '', name: '', statusMessage: '', lastActiveTime: ''));
    if (device.id.isNotEmpty) {
      // 1. Immediately set status to Connecting...
      final idx = _devices.indexWhere((d) => d.id == device.id);
      if (idx != -1) {
        _devices[idx] = _devices[idx].copyWith(
          isOnline: false,
          statusMessage: 'Connecting...',
          messages: [], // Clear chat history on new connection
          quickCommands: const [], // Live commands only
        );
      }
      notifyListeners();

      // 2. Add a brief artificial delay so the user clearly sees the 'Connecting...' state
      loadCustomCommands(device.deviceId);
      loadCustomCommands(device.id);
      Future.delayed(const Duration(milliseconds: 800), () {
        if (_selectedDeviceId == id) { // Ensure user hasn't switched devices again
          _connectWebSocket(device.id, device.deviceId);
        }
      });
    } else {
      _disconnectWebSocket();
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Fetch devices list from backend (optionally filtered by type e.g. OWNER, SHARED)
  Future<bool> fetchDevices(String token, {String? type, String? currentUserId}) async {
    _token = token;
    if (currentUserId != null) {
      _currentUserId = currentUserId;
    }
    _setLoading(true);
    final rawDevices = await _apiService.getDevices(token, type: type);
    _setLoading(false);

    if (rawDevices != null) {
      _devices.clear();
      for (final raw in rawDevices) {
        final dbId = raw['id']?.toString() ?? raw['_id']?.toString() ?? '';
        final hwId = raw['deviceId']?.toString() ?? dbId;
        final deviceName = raw['deviceName']?.toString() ?? raw['name']?.toString() ?? 'Device';
        final baseImageUrl = raw['deviceImage']?.toString() ?? raw['image']?.toString() ?? raw['imageUrl']?.toString();
        final imageUrl = _cacheBustUrl(baseImageUrl);
        final isSharedDevice = type == 'SHARED' ||
            raw['accessType']?.toString().toUpperCase() == 'SHARED' ||
            (currentUserId != null && raw['ownerId'] != null && raw['ownerId'].toString() != currentUserId) ||
            (currentUserId != null && raw['owner'] != null && raw['owner'].toString() != currentUserId);

        final lastSeenVal = raw['lastSeen'];
        bool isOnlineDevice = false;
        if (lastSeenVal != null && lastSeenVal.toString() != 'null') {
          final parsed = _parseDateTime(lastSeenVal.toString());
          if (parsed != null) {
            final difference = DateTime.now().toUtc().difference(parsed.toUtc()).inMinutes;
            isOnlineDevice = difference.abs() <= 5;
          }
        }

        final lastSeenStr = raw['lastSeen']?.toString();
        final lastActive = _formatToIst(lastSeenStr);

        _devices.add(
          Device(
            id: dbId,
            deviceId: hwId,
            name: deviceName,
            statusMessage: isOnlineDevice ? 'Online' : 'Offline',
            lastActiveTime: lastActive,
            isOnline: isOnlineDevice,
            imageUrl: imageUrl,
            isShared: isSharedDevice,
            quickCommands: const [],
            messages: [],
          ),
        );
      }
      if (_devices.isEmpty) {
        _selectedDeviceId = null;
      }
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Fetch details of a single device by database internal ID and update it in local state
  Future<bool> fetchDeviceDetails({required String token, required String dbId, required String hwId}) async {
    final rawDevice = await _apiService.getDeviceById(token: token, deviceId: hwId);
    if (rawDevice != null) {
      final index = _devices.indexWhere((d) => d.id == dbId);
      final deviceName = rawDevice['deviceName']?.toString() ?? rawDevice['name']?.toString() ?? 'Device';
      final baseImageUrl = rawDevice['deviceImage']?.toString() ?? rawDevice['image']?.toString() ?? rawDevice['imageUrl']?.toString();
      final imageUrl = _cacheBustUrl(baseImageUrl);
      
      final lastSeenVal = rawDevice['lastSeen'];
      bool isOnlineDevice = false;
      if (lastSeenVal != null && lastSeenVal.toString() != 'null') {
        final parsed = _parseDateTime(lastSeenVal.toString());
        if (parsed != null) {
          final difference = DateTime.now().toUtc().difference(parsed.toUtc()).inMinutes;
          isOnlineDevice = difference.abs() <= 5;
        }
      }

      final lastSeenStr = rawDevice['lastSeen']?.toString();
      final lastActive = _formatToIst(lastSeenStr);

      final sharedUsersRaw = rawDevice['sharedUsers'] ?? rawDevice['sharedWith'] ?? [];
      final sharedUsers = <SharedUser>[];
      if (sharedUsersRaw is List) {
        for (final u in sharedUsersRaw) {
          if (u is Map) {
            sharedUsers.add(SharedUser.fromJson(Map<String, dynamic>.from(u)));
          } else if (u is String) {
            // Fallback for unpopulated object IDs
            sharedUsers.add(SharedUser(id: u, name: 'Unknown User', email: u));
          }
        }
      }

      if (index != -1) {
        _devices[index] = _devices[index].copyWith(
          name: deviceName,
          imageUrl: imageUrl,
          sharedUsers: sharedUsers,
          clearImage: imageUrl == null,
          isOnline: isOnlineDevice,
          statusMessage: isOnlineDevice ? 'Online' : 'Offline',
          lastActiveTime: lastActive,
        );
        notifyListeners();
      }
      return true;
    }
    return false;
  }

  /// Add a new device via backend API. Returns null on success, or error message on failure.
  Future<String?> addDevice({
    required String token,
    required String deviceId,
    required String deviceName,
  }) async {
    _setLoading(true);
    final errorMsg = await _apiService.createDevice(
      token: token,
      deviceId: deviceId,
      deviceName: deviceName,
    );
    _setLoading(false);

    if (errorMsg == null) {
      await fetchDevices(token, currentUserId: _currentUserId);
      _selectedDeviceId = deviceId;
      notifyListeners();
      return null;
    }
    return errorMsg;
  }



  /// Delete a device via backend API
  Future<bool> deleteDevice({
    required String token,
    required String deviceId,
  }) async {
    _setLoading(true);
    final index = _devices.indexWhere((d) => d.id == deviceId);
    if (index == -1) {
      _setLoading(false);
      return false;
    }

    final device = _devices[index];
    final isShared = device.isShared;

    final success = isShared
        ? await _apiService.unshareDeviceBySharedUser(token: token, deviceId: device.id)
        : await _apiService.deleteDevice(token: token, deviceId: device.deviceId);
    _setLoading(false);

    if (success) {
      _devices.removeWhere((d) => d.id == deviceId);
      if (_selectedDeviceId == deviceId) {
        _selectedDeviceId = null;
      }
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Update device name in backend and local state
  Future<bool> updateDeviceName({
    required String token,
    required String deviceId,
    required String deviceName,
  }) async {
    _setLoading(true);
    final index = _devices.indexWhere((d) => d.id == deviceId);
    if (index == -1) {
      _setLoading(false);
      return false;
    }

    final device = _devices[index];
    final success = await _apiService.updateDeviceName(
      token: token,
      deviceId: device.deviceId,
      deviceName: deviceName,
    );
    _setLoading(false);

    if (success) {
      _devices[index] = _devices[index].copyWith(name: deviceName);
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Share a device via backend API
  Future<String?> shareDevice({
    required String token,
    required String dbId,
    required String hwId,
    required String targetUserId,
  }) async {
    _setLoading(true);
    final error = await _apiService.shareDevice(
      token: token,
      deviceId: hwId,
      targetUserId: targetUserId,
    );
    _setLoading(false);
    return error;
  }

  /// Unshare a device via backend API
  Future<bool> unshareDevice({
    required String token,
    required String dbId,
    required String hwId,
    required String targetUserId,
  }) async {
    _setLoading(true);
    final success = await _apiService.unshareDevice(
      token: token,
      deviceId: hwId,
      targetUserId: targetUserId,
    );
    _setLoading(false);
    return success;
  }

  /// Upload device picture avatar
  Future<bool> uploadDeviceImage({
    required String token,
    required String dbId,
    required String hwId,
    required List<int> bytes,
    required String filename,
  }) async {
    _setLoading(true);
    final success = await _apiService.uploadDeviceImage(
      token: token,
      deviceId: hwId,
      fileBytes: bytes,
      filename: filename,
    );
    if (success) {
      await fetchDeviceDetails(token: token, dbId: dbId, hwId: hwId);
    }
    _setLoading(false);
    return success;
  }

  /// Delete device picture avatar
  Future<bool> deleteDeviceImage({
    required String token,
    required String dbId,
    required String hwId,
  }) async {
    _setLoading(true);
    final success = await _apiService.deleteDeviceImage(
      token: token,
      deviceId: hwId,
    );
    if (success) {
      await fetchDeviceDetails(token: token, dbId: dbId, hwId: hwId);
    }
    _setLoading(false);
    return success;
  }

  /// Add a custom quick command chip to a specific device
  void addQuickCommand(String deviceId, String label, String message) {
    final lbl = label.trim();
    final msg = message.trim();
    if (lbl.isEmpty || msg.isEmpty) return;

    final index = _devices.indexWhere((d) => d.id == deviceId);
    if (index != -1) {
      final device = _devices[index];
      final labelExists = device.quickCommands.any((cmd) => cmd.label.toLowerCase() == lbl.toLowerCase());
      if (!labelExists) {
        final newCmd = QuickCommand(label: lbl, message: msg);
        final updatedCommands = List<QuickCommand>.from(device.quickCommands)..add(newCmd);
        _devices[index] = device.copyWith(quickCommands: updatedCommands);
        notifyListeners();
      }
    }
  }

  /// Edit a quick command chip on a specific device
  void editQuickCommand(String deviceId, int indexToEdit, String label, String message) {
    final lbl = label.trim();
    final msg = message.trim();
    if (lbl.isEmpty || msg.isEmpty) return;

    final index = _devices.indexWhere((d) => d.id == deviceId);
    if (index != -1) {
      final device = _devices[index];
      if (indexToEdit >= 0 && indexToEdit < device.quickCommands.length) {
        final updatedCommands = List<QuickCommand>.from(device.quickCommands);
        updatedCommands[indexToEdit] = QuickCommand(label: lbl, message: msg);
        _devices[index] = device.copyWith(quickCommands: updatedCommands);
        notifyListeners();
      }
    }
  }

  /// Delete a quick command chip on a specific device
  void deleteQuickCommand(String deviceId, int indexToDelete) {
    final index = _devices.indexWhere((d) => d.id == deviceId);
    if (index != -1) {
      final device = _devices[index];
      if (indexToDelete >= 0 && indexToDelete < device.quickCommands.length) {
        final updatedCommands = List<QuickCommand>.from(device.quickCommands)..removeAt(indexToDelete);
        _devices[index] = device.copyWith(quickCommands: updatedCommands);
        notifyListeners();
      }
    }
  }

  /// Send message in active chat thread
  
  void sendConfig(String deviceId, Map<String, dynamic> configData) {
    final lines = configData.entries.map((e) => '${e.key}: ${e.value}').join('\n');
    final displayText = 'Sent Configuration:\n$lines';

    final userMsg = ChatMessage(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      text: displayText,
      command: '/config',
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    );

    final index = _devices.indexWhere((d) => d.id == deviceId || d.deviceId == deviceId);
    if (index != -1) {
      final device = _devices[index];
      final updatedMessages = List<ChatMessage>.from(device.messages)..add(userMsg);
      _devices[index] = device.copyWith(messages: updatedMessages);
      notifyListeners();

      _setDeviceOnline(device.id, true);
      _resetWatchdog(device.id);

      final payload = jsonEncode({
        'command': '/config',
        'data': configData,
      });

      if (_webSocketChannel != null) {
        try {
          _webSocketChannel!.sink.add(payload);
        } catch (_) {}
      }
    }
  }

  void sendWifiSetup(String deviceId, String ssid, String password) {
    final maskedPass = password.isEmpty ? '(none)' : '•' * password.length;
    final displayText = 'Sent Wi-Fi Setup:\nSSID: $ssid\nPASS: $maskedPass';

    final userMsg = ChatMessage(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      text: displayText,
      command: '/set-up_wifi',
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    );

    final index = _devices.indexWhere((d) => d.id == deviceId || d.deviceId == deviceId);
    if (index != -1) {
      final device = _devices[index];
      final updatedMessages = List<ChatMessage>.from(device.messages)..add(userMsg);
      _devices[index] = device.copyWith(messages: updatedMessages);
      notifyListeners();

      _setDeviceOnline(device.id, true);
      _resetWatchdog(device.id);

      final payload = jsonEncode({
        'command': '/set-up_wifi',
        'data': {
          'SSID': ssid,
          'PASS': password,
        },
      });

      if (_webSocketChannel != null) {
        try {
          _webSocketChannel!.sink.add(payload);
        } catch (_) {}
      }
    }
  }

  void sendMessage(String text, {String? displayText}) {
    if (_selectedDeviceId == null) return;
    final index = _devices.indexWhere((d) => d.id == _selectedDeviceId);
    if (index == -1) return;

    final device = _devices[index];
    final userMsg = ChatMessage(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      text: displayText ?? text,
      command: text,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    );

    final updatedMessages = List<ChatMessage>.from(device.messages)..add(userMsg);
    _devices[index] = device.copyWith(messages: updatedMessages);
    notifyListeners();

    // Touch device: Keep device online for 10s grace period
    _setDeviceOnline(_selectedDeviceId!, true);
    _resetWatchdog(_selectedDeviceId!);

    final payload = jsonEncode({'command': text});

    if (_webSocketChannel != null) {
      try {
        _webSocketChannel!.sink.add(payload);
      } catch (_) {
        // Reconnect and send if write failed
        _connectWebSocket(_selectedDeviceId!, device.deviceId);
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_webSocketChannel != null) {
            try {
              _webSocketChannel!.sink.add(payload);
            } catch (_) {}
          }
        });
      }
    } else {
      // Reconnect and send if socket was null
      _connectWebSocket(_selectedDeviceId!, device.deviceId);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_webSocketChannel != null) {
          try {
            _webSocketChannel!.sink.add(payload);
          } catch (_) {}
        }
      });
    }
  }

  String? _cacheBustUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    String fullUrl = url;
    if (url.startsWith('/')) {
      fullUrl = '${ApiConfig.baseUrl}$url';
    }
    final separator = fullUrl.contains('?') ? '&' : '?';
    return '$fullUrl${separator}v=${DateTime.now().millisecondsSinceEpoch}';
  }

  String _formatToIst(String? utcTimestamp) {
    final parsed = _parseDateTime(utcTimestamp);
    if (parsed == null) return 'Never';
    try {
      final utcDateTime = parsed.toUtc();
      final istDateTime = utcDateTime.add(const Duration(hours: 5, minutes: 30));
      
      final nowUtc = DateTime.now().toUtc();
      final nowIst = nowUtc.add(const Duration(hours: 5, minutes: 30));
      
      final hour = istDateTime.hour.toString().padLeft(2, '0');
      final minute = istDateTime.minute.toString().padLeft(2, '0');
      
      if (istDateTime.year == nowIst.year &&
          istDateTime.month == nowIst.month &&
          istDateTime.day == nowIst.day) {
        return '$hour:$minute';
      }
      
      final yesterdayIst = nowIst.subtract(const Duration(days: 1));
      if (istDateTime.year == yesterdayIst.year &&
          istDateTime.month == yesterdayIst.month &&
          istDateTime.day == yesterdayIst.day) {
        return 'Yesterday, $hour:$minute';
      }
      
      final day = istDateTime.day.toString().padLeft(2, '0');
      final month = istDateTime.month.toString().padLeft(2, '0');
      final year = istDateTime.year;
      return '$day/$month/$year, $hour:$minute';
    } catch (_) {
      return '12:00';
    }
  }

  DateTime? _parseDateTime(String? str) {
    if (str == null || str.isEmpty || str == 'null') return null;
    try {
      String cleaned = str.trim();
      final parsed = DateTime.tryParse(cleaned);
      if (parsed != null) return parsed;

      if (!cleaned.endsWith('Z') && !cleaned.contains('+') && !cleaned.contains('-')) {
        final withZ = DateTime.tryParse('${cleaned}Z');
        if (withZ != null) return withZ;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  void _connectWebSocket(String dbId, String hwId) {
    _disconnectWebSocket();

    // Connect watchdog timer: if no message arrives in 10 seconds, it remains offline
    _resetWatchdog(dbId);

    if (_token == null) return;

    // 2. Establish WebSocket connection
    try {
      String wsBase = ApiConfig.baseUrl;
      if (wsBase.startsWith('https://')) {
        wsBase = wsBase.replaceFirst('https://', 'wss://');
      } else if (wsBase.startsWith('http://')) {
        wsBase = wsBase.replaceFirst('http://', 'ws://');
      }
      if (kIsWeb && Uri.base.scheme == 'https' && wsBase.startsWith('ws://')) {
        wsBase = wsBase.replaceFirst('ws://', 'wss://');
      }
      final wsUrlStr = '$wsBase/ws?deviceId=$hwId&type=mobile&token=$_token';
      final wsUri = Uri.parse(wsUrlStr);
      
      _webSocketChannel = WebSocketChannel.connect(
        wsUri,
        protocols: kIsWeb ? null : ['Bearer', _token!],
      );

      _webSocketSubscription = _webSocketChannel!.stream.listen(
        (message) {
          
          try {
            final parsed = jsonDecode(message.toString());
            if (parsed is Map) {
              if (parsed.containsKey('success') && parsed['success'] == false) {
                _setDeviceOnline(dbId, false);
                _watchdogTimer?.cancel();
                return;
              }

              final type = parsed['type']?.toString();
              if (type == 'connected') {
                // Server handshake confirmed. The websocket is open.
                // Do NOT set device online yet. Wait for 'device_online', heartbeat, or actual data.
                _resetWatchdog(dbId);
                return;
              }
              
              if (type == 'device_offline' && parsed['deviceId']?.toString() == hwId) {
                _setDeviceOnline(dbId, false);
                _watchdogTimer?.cancel();
                return;
              }

              _resetWatchdog(dbId);
              _setDeviceOnline(dbId, true);

              final rawMsg = message.toString();
              final parsedData = _extractDataPreservingDuplicates(
                rawMsg,
                parsed['data'] is Map ? Map<String, dynamic>.from(parsed['data'] as Map) : null,
              );
              if (parsedData.isNotEmpty) {
                _latestDeviceStatusData[hwId] = parsedData;
                _latestDeviceStatusData[dbId] = parsedData;
              } else if (parsed.containsKey('data') && parsed['data'] is Map) {
                final dMap = Map<String, dynamic>.from(parsed['data'] as Map);
                _latestDeviceStatusData[hwId] = dMap;
                _latestDeviceStatusData[dbId] = dMap;
              }

              final incomingCmds = parsed['availableCommands'] ?? parsed['additionalCommands'];
              if (incomingCmds != null) {
                final List<QuickCommand> dynCmds = [];
                void extractCmd(String cKey, String cDesc) {
                  final k = cKey.trim();
                  if (k.isNotEmpty) {
                    String lbl = cDesc.trim();
                    if (lbl.isEmpty) {
                      lbl = k.startsWith('/') ? k.substring(1) : k;
                      lbl = lbl.replaceAll('_', ' ');
                    }
                    dynCmds.add(QuickCommand(label: lbl, message: k));
                  }
                }
                if (incomingCmds is List) {
                  for (final item in incomingCmds) {
                    if (item is Map) {
                      extractCmd((item['command'] ?? item['message'] ?? '').toString(), (item['description'] ?? item['label'] ?? '').toString());
                    }
                  }
                } else if (incomingCmds is Map) {
                  incomingCmds.forEach((k, v) => extractCmd(k.toString(), v?.toString() ?? ''));
                }
                if (dynCmds.isNotEmpty) {
                  _deviceQuickCommands[hwId] = dynCmds;
                  _deviceQuickCommands[dbId] = dynCmds;
                  _syncDeviceQuickCommands(hwId);
                }
              }

              if (parsed['command'] == '/config' && parsed['success'] == true) {
                sendMessage('/status', displayText: 'Get device status');
              }

              if (type == 'heartbeat') {
                // Heartbeat message resets watchdog and keeps device online
              } else {
                _addDeviceReplyMessage(dbId, rawMsg);
              }
            } else {
              _resetWatchdog(dbId);
              _setDeviceOnline(dbId, true);
              _addDeviceReplyMessage(dbId, message.toString());
            }
          } catch (_) {
            _resetWatchdog(dbId);
            _setDeviceOnline(dbId, true);
            _addDeviceReplyMessage(dbId, message.toString());
          }
        },
        onError: (err) {
          _cleanupSocket();
          _scheduleReconnect(dbId, hwId);
        },
        onDone: () {
          _cleanupSocket();
          _scheduleReconnect(dbId, hwId);
        },
      );
    } catch (e) {
      // Do not make offline immediately; let the 10-second watchdog expire
      _scheduleReconnect(dbId, hwId);
    }
  }

  void _scheduleReconnect(String dbId, String hwId) {
    if (_selectedDeviceId != dbId) return; // Don't reconnect if the user switched devices
    if (_isReconnecting) return;
    
    _isReconnecting = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      _isReconnecting = false;
      if (_selectedDeviceId == dbId) {
        _connectWebSocket(dbId, hwId);
      }
    });
  }

  void _resetWatchdog(String dbId) {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer(const Duration(seconds: 10), () {
      _setDeviceOnline(dbId, false);
    });
  }

  void _sendInitialStatus(String dbId) {
    sendMessage('/status');
  }

  void _setDeviceOnline(String dbId, bool online) {
    final idx = _devices.indexWhere((d) => d.id == dbId);
    if (idx != -1) {
      final device = _devices[idx];
      final expectedStatus = online ? 'Online' : 'Offline';
      if (device.isOnline != online || device.statusMessage != expectedStatus) {
        String newLastActive = device.lastActiveTime;
        if (!online && device.isOnline) {
          // Only update the offline time when transitioning from online -> offline
          newLastActive = _getCurrentFormattedTimeIst();
        }
        
        _devices[idx] = device.copyWith(
          isOnline: online,
          statusMessage: expectedStatus,
          lastActiveTime: newLastActive,
        );
        notifyListeners();
        // User requested not to send /status automatically when device goes online
      }
    }
  }

  String _cleanKey(String rawKey) {
    String key = rawKey;
    final statusRegex = RegExp(r'[_]status$', caseSensitive: false);
    key = key.replaceAll(statusRegex, '');
    key = key.replaceAll('_', ' ').trim();
    return key.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  void _addDeviceReplyMessage(String dbId, String rawText) {
    final idx = _devices.indexWhere((d) => d.id == dbId);
    if (idx == -1) return;
    
    final device = _devices[idx];
    
    String? textToShow;
    List<QuickCommand>? updatedCommands;
    
    bool shouldAddMessage = true;

    try {
      final parsed = jsonDecode(rawText);
      if (parsed is Map) {
        // 1. Locate the status payload map (use 'data' map if nested, fallback to root)
        Map? dataMap;
        bool isNested = false;
        if (parsed.containsKey('data') && parsed['data'] is Map) {
          dataMap = parsed['data'];
          isNested = true;
        } else {
          dataMap = parsed;
        }

        final List<String> lines = [];
        final configKeys = {
          'deviceid', 'firmwareversion', 'availablecommands', 'additionalcommands',
          'type', 'success', 'message', 'command', 'timestamp', 'id', 'version', 'lastseen'
        };

        // Strictly extract only telemetry values from dataMap
        if (dataMap != null) {
          final keys = dataMap.keys.map((k) => k.toString()).toList();
          final filteredKeys = keys.where((k) => !configKeys.contains(k.toLowerCase())).toList();

          if (filteredKeys.isNotEmpty) {
            // Sort keys numerically if numbers are present, otherwise alphabetically
            filteredKeys.sort((a, b) {
              final numA = int.tryParse(RegExp(r'\d+').firstMatch(a)?.group(0) ?? '') ?? -1;
              final numB = int.tryParse(RegExp(r'\d+').firstMatch(b)?.group(0) ?? '') ?? -1;
              if (numA != -1 && numB != -1) {
                return numA.compareTo(numB);
              }
              return a.toLowerCase().compareTo(b.toLowerCase());
            });

            for (final key in filteredKeys) {
              final val = dataMap[key]?.toString() ?? 'Off';
              final label = _cleanKey(key);
              lines.add('$label: $val');
            }
            textToShow = lines.join('\n');
          }
        }

        // If there is no relay status/data payload block, check if it's connected or offline handshake message
        if (textToShow == null || textToShow.isEmpty) {
          final type = parsed['type']?.toString();
          if (type == 'connected' || type == 'device_online' || parsed.containsKey('availableCommands')) {
            shouldAddMessage = false;
          }
        }
        
        // 2. Dynamically extract quick action commands to refill Quick Commands section (NOT in chat bubble)
        final rawCmds = parsed['availableCommands'] ?? parsed['additionalCommands'];
        if (rawCmds != null) {
          final parsedCommands = <QuickCommand>[];

          void processCmd(String cmdKey, String cmdDesc) {
            final cleanCmd = cmdKey.trim();
            if (cleanCmd.isNotEmpty) {
              String rawLabel = cmdDesc.trim();
              if (rawLabel.isEmpty) {
                rawLabel = cleanCmd.startsWith('/') ? cleanCmd.substring(1) : cleanCmd;
                rawLabel = rawLabel.replaceAll('_', ' ');
                rawLabel = rawLabel.replaceAllMapped(RegExp(r'([a-zA-Z])(\d)'), (m) => '${m[1]} ${m[2]}');
                rawLabel = rawLabel.isNotEmpty
                    ? rawLabel[0].toUpperCase() + rawLabel.substring(1)
                    : rawLabel;
              }
              parsedCommands.add(QuickCommand(label: rawLabel, message: cleanCmd));
            }
          }

          if (rawCmds is List) {
            for (final item in rawCmds) {
              if (item is Map) {
                final cKey = (item['command'] ?? item['message'] ?? '').toString();
                final cDesc = (item['description'] ?? item['label'] ?? item['title'] ?? '').toString();
                processCmd(cKey, cDesc);
              }
            }
          } else if (rawCmds is Map) {
            rawCmds.forEach((key, val) {
              processCmd(key.toString(), val?.toString() ?? '');
            });
          }

          if (parsedCommands.isNotEmpty) {
            updatedCommands = parsedCommands;
            _deviceQuickCommands[device.deviceId] = parsedCommands;
            _deviceQuickCommands[device.id] = parsedCommands;
          }
        }
      }
    } catch (_) {}

    // Fallback if not matching relay status but is standard text/JSON
    textToShow ??= rawText;

    var updatedDevice = device;
    if (updatedCommands != null) {
      updatedDevice = updatedDevice.copyWith(
        quickCommands: updatedCommands,
      );
    }

    if (shouldAddMessage) {
      if (updatedDevice.messages.isNotEmpty) {
        final lastMsg = updatedDevice.messages.last;
        if (!lastMsg.isUser &&
            lastMsg.text == textToShow &&
            DateTime.now().difference(lastMsg.timestamp).inMilliseconds.abs() < 2000) {
          return; // Deduplicate rapid message
        }
      }

      final replyMsg = ChatMessage(
        id: 'ws_reply_${DateTime.now().millisecondsSinceEpoch}',
        text: textToShow,
        sender: MessageSender.device,
        timestamp: DateTime.now(),
      );

      final withReply = List<ChatMessage>.from(updatedDevice.messages)..add(replyMsg);
      _devices[idx] = updatedDevice.copyWith(messages: withReply);
      notifyListeners();
    } else if (updatedCommands != null) {
      // Just update device commands without adding a blank message bubble
      _devices[idx] = updatedDevice;
      notifyListeners();
    }
  }

  void _cleanupSocket() {
    _webSocketSubscription?.cancel();
    _webSocketSubscription = null;
    _webSocketChannel = null;
  }

  
  void reconnectCurrentDevice() {
    if (_selectedDeviceId == null) return;
    final index = _devices.indexWhere((d) => d.id == _selectedDeviceId);
    if (index != -1) {
      final dev = _devices[index];
      _connectWebSocket(dev.id, dev.deviceId);
    }
  }

  void _disconnectWebSocket() {
    _isReconnecting = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    _webSocketSubscription?.cancel();
    _webSocketSubscription = null;
    _webSocketChannel?.sink.close();
    _webSocketChannel = null;
  }

  String _getCurrentFormattedTimeIst() {
    final nowIst = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    final day = nowIst.day.toString().padLeft(2, '0');
    final month = nowIst.month.toString().padLeft(2, '0');
    final year = nowIst.year;
    
    int hourInt = nowIst.hour;
    final amPm = hourInt >= 12 ? 'PM' : 'AM';
    hourInt = hourInt % 12;
    if (hourInt == 0) hourInt = 12;
    final hour = hourInt.toString().padLeft(2, '0');
    
    final minute = nowIst.minute.toString().padLeft(2, '0');
    final second = nowIst.second.toString().padLeft(2, '0');
    
    return '$day-$month-$year $hour:$minute:$second $amPm';
  }

  @override
  void dispose() {
    _disconnectWebSocket();
    super.dispose();
  }
}
