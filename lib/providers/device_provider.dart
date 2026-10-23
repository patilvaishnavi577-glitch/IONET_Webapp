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
      final dataKeyMatch = RegExp(r'"(?:data|telemetry|status|payload)"\s*:\s*\{', caseSensitive: false).firstMatch(rawJson);
      int openBraceIndex = -1;
      if (dataKeyMatch != null) {
        openBraceIndex = rawJson.indexOf('{', dataKeyMatch.start);
      } else {
        openBraceIndex = rawJson.indexOf('{');
      }
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
  String? _connectedHardwareId;
  bool _intentionalDisconnect = false;
  bool _isConnectingWebSocket = false;
  int _connectionEpoch = 0;
  final Map<String, DateTime> _recentlyReceivedSignatures = {};
  Timer? _watchdogTimer;
  bool _isReconnecting = false;
  Timer? _reconnectTimer;
  final Map<String, Map<String, dynamic>> _latestDeviceStatusData = {};
  final Map<String, List<QuickCommand>> _customQuickCommands = {};
  final Map<String, List<QuickCommand>> _deviceQuickCommands = {};
  final Map<String, List<QuickCommand>> _deviceRawQuickCommands = {};
  final Map<String, Map<String, dynamic>> _deviceSavedConfigurations = {};
  final Map<String, Map<String, double>> _deviceSliderValues = {};
  final Map<String, Map<String, NumericSetting>> _deviceNumericSettings = {};
  final Map<String, Map<String, TextSetting>> _deviceTextSettings = {};
  final Map<String, Map<String, RadioSetting>> _deviceRadioSettings = {};

  Device? _findDevice(String idOrDeviceId) {
    final idx = _devices.indexWhere((d) => d.id == idOrDeviceId || d.deviceId == idOrDeviceId);
    if (idx != -1) return _devices[idx];
    return null;
  }

  Map<String, dynamic> getDeviceSavedConfig(String deviceId) {
    final dev = _findDevice(deviceId);
    final hwId = dev?.deviceId.isNotEmpty == true ? dev!.deviceId : deviceId;
    final dbId = dev?.id.isNotEmpty == true ? dev!.id : deviceId;
    final Map<String, dynamic> merged = {};
    if (_deviceSavedConfigurations.containsKey(dbId)) {
      merged.addAll(_deviceSavedConfigurations[dbId]!);
    }
    if (_deviceSavedConfigurations.containsKey(hwId)) {
      merged.addAll(_deviceSavedConfigurations[hwId]!);
    }
    return merged;
  }

  double? getDeviceSliderValue(String deviceId, String commandOrKey) {
    final dev = _findDevice(deviceId);
    final hwId = dev?.deviceId.isNotEmpty == true ? dev!.deviceId : deviceId;
    final dbId = dev?.id.isNotEmpty == true ? dev!.id : deviceId;
    return _deviceSliderValues[hwId]?[commandOrKey] ??
        _deviceSliderValues[dbId]?[commandOrKey];
  }

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

  Map<String, dynamic>? getLatestDeviceStatusData(String deviceId) {
    if (_latestDeviceStatusData.containsKey(deviceId) &&
        _latestDeviceStatusData[deviceId]!.isNotEmpty) {
      return _latestDeviceStatusData[deviceId];
    }
    final dev = _findDevice(deviceId);
    if (dev != null) {
      if (_latestDeviceStatusData.containsKey(dev.deviceId) &&
          _latestDeviceStatusData[dev.deviceId]!.isNotEmpty) {
        return _latestDeviceStatusData[dev.deviceId];
      }
      if (_latestDeviceStatusData.containsKey(dev.id) &&
          _latestDeviceStatusData[dev.id]!.isNotEmpty) {
        return _latestDeviceStatusData[dev.id];
      }
    }
    return null;
  }

  List<QuickCommand> getDeviceCommands(String deviceId) =>
      _deviceQuickCommands[deviceId] ?? [];
  List<QuickCommand> getCustomCommands(String deviceId) =>
      _customQuickCommands[deviceId] ?? [];

  Map<String, NumericSetting> getDeviceNumericSettings(String deviceId) {
    if (_deviceNumericSettings.containsKey(deviceId) &&
        _deviceNumericSettings[deviceId]!.isNotEmpty) {
      return _deviceNumericSettings[deviceId]!;
    }
    final dev = _findDevice(deviceId);
    if (dev != null) {
      if (_deviceNumericSettings.containsKey(dev.deviceId) &&
          _deviceNumericSettings[dev.deviceId]!.isNotEmpty) {
        return _deviceNumericSettings[dev.deviceId]!;
      }
      if (_deviceNumericSettings.containsKey(dev.id) &&
          _deviceNumericSettings[dev.id]!.isNotEmpty) {
        return _deviceNumericSettings[dev.id]!;
      }
    }
    return const {};
  }

  Map<String, TextSetting> getDeviceTextSettings(String deviceId) {
    if (_deviceTextSettings.containsKey(deviceId) &&
        _deviceTextSettings[deviceId]!.isNotEmpty) {
      return _deviceTextSettings[deviceId]!;
    }
    final dev = _findDevice(deviceId);
    if (dev != null) {
      if (_deviceTextSettings.containsKey(dev.deviceId) &&
          _deviceTextSettings[dev.deviceId]!.isNotEmpty) {
        return _deviceTextSettings[dev.deviceId]!;
      }
      if (_deviceTextSettings.containsKey(dev.id) &&
          _deviceTextSettings[dev.id]!.isNotEmpty) {
        return _deviceTextSettings[dev.id]!;
      }
    }
    return const {};
  }

  Map<String, RadioSetting> getDeviceRadioSettings(String deviceId) {
    if (_deviceRadioSettings.containsKey(deviceId) &&
        _deviceRadioSettings[deviceId]!.isNotEmpty) {
      return _deviceRadioSettings[deviceId]!;
    }
    final dev = _findDevice(deviceId);
    if (dev != null) {
      if (_deviceRadioSettings.containsKey(dev.deviceId) &&
          _deviceRadioSettings[dev.deviceId]!.isNotEmpty) {
        return _deviceRadioSettings[dev.deviceId]!;
      }
      if (_deviceRadioSettings.containsKey(dev.id) &&
          _deviceRadioSettings[dev.id]!.isNotEmpty) {
        return _deviceRadioSettings[dev.id]!;
      }
    }
    return const {};
  }

  static String detectDeviceModel({
    String? explicitModel,
    String? deviceId,
    String? deviceName,
  }) {
    final exp = (explicitModel ?? '').trim();
    if (exp.isNotEmpty && exp.toUpperCase() != 'DEFAULT' && exp.toUpperCase() != 'NULL') {
      return exp.toUpperCase();
    }
    return 'DEFAULT';
  }

  /// Resolves the payload category whether backend sends "type" or "command"
  static String resolvePayloadType(Map payload) {
    final rawType = payload['type']?.toString().toUpperCase().trim();
    if (rawType != null && rawType.isNotEmpty) {
      if (rawType == 'CYCLE' || rawType == 'CYCLICS') return 'CYCLIC';
      return rawType;
    }
    final rawCmd = payload['command']?.toString().replaceAll('/', '').replaceAll(' ', '_').toUpperCase().trim();
    if (rawCmd == 'RADIO' || rawCmd == 'PRESERVE_STATE' || rawCmd == 'PRESERVE_SETTING' || rawCmd == 'PRESERVESTATE') return 'RADIO';
    if (rawCmd == 'HOLDING' || rawCmd == 'NUMERIC' || rawCmd == 'RANGE') return 'NUMERIC';
    if (rawCmd == 'TIME' || rawCmd == 'TIMING' || rawCmd == 'TIMINGS') return 'TIME';
    if (rawCmd == 'CYCLIC' || rawCmd == 'CYCLE' || rawCmd == 'CYCLICS') return 'CYCLIC';
    if (rawCmd == 'CONFIG' || rawCmd == 'TEXT' || rawCmd == 'DEVICE_SETTING' || rawCmd == 'DEVICE_SETTINGS' || rawCmd == 'RENAME_RELAY' || rawCmd == 'DEVICESETTING' || rawCmd == 'RENAMERELAY') return 'TEXT';
    if (rawCmd == 'SETTINGS' || rawCmd == 'SETTING' || rawCmd == 'CLICKABLE') return 'CLICKABLE';
    if (rawCmd == 'STATUS' || rawCmd == 'RESPONSE' || rawCmd == 'TELEMETRY') return 'RESPONSE';

    // Auto-detect based on data shape if type/command not explicitly set
    final data = payload['data'] ?? payload['telemetry'] ?? payload['payload'];
    if (data is List && data.isNotEmpty) {
      final first = data.first;
      if (first is Map && (first.containsKey('command') || first.containsKey('action') || first.containsKey('label') || first.containsKey('key'))) {
        return 'CLICKABLE';
      }
    } else if (data is Map && data.isNotEmpty) {
      final keys = data.keys.map((k) => k.toString().toLowerCase().trim()).toSet();
      if (keys.contains('ps') || keys.contains('pop') || keys.contains('preserve_state')) {
        return 'RADIO';
      }
      if (keys.contains('cyclic')) {
        return 'CYCLIC';
      }
      if (keys.any((k) => k.startsWith('set_timing_'))) {
        return 'TIME';
      }
      final hasRange = data.values.any((v) => v is Map && v.containsKey('range'));
      if (hasRange) {
        return 'NUMERIC';
      }
      final isTextSlots = keys.every((k) => RegExp(r'^\d+$').hasMatch(k));
      if (isTextSlots) {
        return 'TEXT';
      }
    }

    return '';
  }

  /// Dynamically parses any backend TIME response payload into QuickCommands (100% backend-driven, Zero hardcoding)
  List<QuickCommand> parseTimePayloadData(Map<String, dynamic> payload) {
    final List<QuickCommand> result = [];
    final type = resolvePayloadType(payload);
    if (type == 'TIME' && payload['data'] is Map) {
      final Map timeMap = payload['data'] as Map;
      timeMap.forEach((key, val) {
        final kStr = key.toString().trim();
        final vStr = val.toString().trim();
        String label = kStr.replaceAll('_', ' ');
        label = label.split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '').join(' ');
        result.add(
          QuickCommand(
            label: '$label ($vStr)',
            message: kStr,
            type: 'time',
          ),
        );
      });
    }
    return result;
  }

  /// Dynamically parses any backend CYCLIC response payload into QuickCommands (100% backend-driven, Zero hardcoding)
  List<QuickCommand> parseCyclicPayloadData(Map<String, dynamic> payload) {
    final List<QuickCommand> result = [];
    final type = resolvePayloadType(payload);
    if ((type == 'CYCLIC' || type == 'CYCLE') && payload['data'] is Map) {
      final Map cyclicMap = payload['data'] as Map;
      cyclicMap.forEach((key, val) {
        final kStr = key.toString().trim();
        final vStr = val.toString().trim();
        String label = kStr.replaceAll('_', ' ');
        label = label.split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '').join(' ');
        result.add(
          QuickCommand(
            label: '$label ($vStr)',
            message: kStr,
            type: 'cyclic',
          ),
        );
      });
    }
    return result;
  }

  /// Dynamically parses any backend NUMERIC response payload into NumericSettings (100% backend-driven, Zero hardcoding)
  List<NumericSetting> parseNumericPayloadData(Map<String, dynamic> payload, String hwId, String dbId) {
    final List<NumericSetting> result = [];
    final type = resolvePayloadType(payload);
    if (type == 'NUMERIC' && payload['data'] is Map) {
      final Map dataMap = payload['data'] as Map;
      final Map<String, NumericSetting> settingsMap = {};
      final msgStr = payload['message']?.toString();
      dataMap.forEach((key, val) {
        final setting = NumericSetting.fromMap(key.toString(), val, parentMessage: msgStr);
        if (setting != null) {
          result.add(setting);
          settingsMap[setting.key] = setting;
        }
      });
      if (settingsMap.isNotEmpty) {
        if (hwId.isNotEmpty) _deviceNumericSettings[hwId] = settingsMap;
        if (dbId.isNotEmpty) _deviceNumericSettings[dbId] = settingsMap;
        notifyListeners();
      }
    }
    return result;
  }

  /// Dynamically parses any backend RADIO response payload into RadioSettings (100% backend-driven, Zero hardcoding)
  /// e.g. {"type": "RADIO", "data": {"PS": "0", "POP": "0"}}
  /// Options always come from backend; only 0 or 1 allowed.
  Map<String, RadioSetting> parseRadioPayloadData(Map<String, dynamic> payload, String hwId, String dbId) {
    final Map<String, RadioSetting> result = {};
    final type = resolvePayloadType(payload);
    if (type == 'RADIO' && payload['data'] is Map) {
      final Map dataMap = payload['data'] as Map;
      // If backend sends an 'options' or 'allowedValues' key at root or in data, use those
      final rootOptions = payload['options'];
      List<String>? parsedOptions;
      if (rootOptions is List) {
        parsedOptions = rootOptions.map((o) => o.toString()).toList();
      }
      dataMap.forEach((key, val) {
        final kStr = key.toString().trim();
        List<String>? fieldOptions = parsedOptions;
        // per-field options if backend sends e.g. {"PS": {"value":"0","options":["0","1"]}}
        if (val is Map) {
          final optsRaw = val['options'];
          if (optsRaw is List) {
            fieldOptions = optsRaw.map((o) => o.toString()).toList();
          }
          final setting = RadioSetting.fromData(kStr, val['value'], fieldOptions);
          result[kStr] = setting;
        } else {
          final setting = RadioSetting.fromData(kStr, val, fieldOptions);
          result[kStr] = setting;
        }
      });
      if (result.isNotEmpty) {
        if (hwId.isNotEmpty) _deviceRadioSettings[hwId] = result;
        if (dbId.isNotEmpty) _deviceRadioSettings[dbId] = result;
        notifyListeners();
      }
    }
    return result;
  }

  /// Optimistically updates PS or POP radio setting so user immediately sees ON / OFF feedback
  void updateRadioSettingOptimistic(String deviceId, String key, String newValue) {
    final clean = _cleanKey(key);
    final valStr = (newValue == '1' || newValue.toLowerCase() == 'on') ? '1' : '0';

    void updateMap(String id) {
      if (_deviceRadioSettings.containsKey(id)) {
        final existing = _deviceRadioSettings[id]!;
        for (final k in [key, clean, clean.toLowerCase(), clean.toUpperCase()]) {
          if (existing.containsKey(k)) {
            final old = existing[k]!;
            existing[k] = RadioSetting(
              key: old.key,
              label: old.label,
              value: valStr,
              options: old.options,
            );
          }
        }
      }
      if (_latestDeviceStatusData.containsKey(id)) {
        _latestDeviceStatusData[id]![clean] = valStr;
        _latestDeviceStatusData[id]![key] = valStr;
      }
    }

    updateMap(deviceId);
    final dev = _devices.firstWhere(
      (d) => d.id == deviceId || d.deviceId == deviceId,
      orElse: () => _devices.first,
    );
    if (dev.deviceId.isNotEmpty) updateMap(dev.deviceId);
    if (dev.id.isNotEmpty) updateMap(dev.id);

    // Also update any existing RADIO chat message in the chat history
    final devIdx = _devices.indexWhere((d) => d.id == deviceId || d.deviceId == deviceId);
    if (devIdx != -1) {
      final targetDev = _devices[devIdx];
      final msgs = List<ChatMessage>.from(targetDev.messages);
      bool modified = false;
      for (int i = msgs.length - 1; i >= 0; i--) {
        final m = msgs[i];
        if (m.command == 'RADIO' || m.text.contains('$clean:') || m.text.contains('$key:')) {
          final lines = m.text.split('\n');
          final newLines = lines.map((l) {
            final colonIdx = l.indexOf(':');
            if (colonIdx != -1) {
              final kPart = l.substring(0, colonIdx).trim();
              if (kPart.toLowerCase() == clean.toLowerCase() || kPart.toLowerCase() == key.toLowerCase()) {
                return '$kPart: $valStr';
              }
            }
            return l;
          }).toList();
          msgs[i] = m.copyWith(text: newLines.join('\n'));
          modified = true;
          break;
        }
      }
      if (modified) {
        _devices[devIdx] = targetDev.copyWith(messages: msgs);
      }
    }
    notifyListeners();
  }

  /// Dynamically parses any backend TEXT response payload into custom slot configurations (Zero hardcoding)
  /// e.g. {"type": "TEXT", "data": {"1": "Relay 1", "2": "Relay2"}, ...}
  Map<String, TextSetting> parseTextPayloadData(Map<String, dynamic> payload, String hwId, String dbId) {
    final Map<String, TextSetting> result = {};
    final type = resolvePayloadType(payload);
    if (type == 'TEXT' && payload['data'] is Map) {
      final Map dataMap = payload['data'] as Map;
      final rootRange = payload['range']?.toString();
      final Map<String, dynamic> configUpdates = {};
      dataMap.forEach((key, val) {
        final kStr = key.toString().trim();
        final textSetting = TextSetting.fromData(kStr, val, rootRange);
        result[kStr] = textSetting;
        configUpdates['Channel $kStr'] = textSetting.value;
        configUpdates['Slot $kStr'] = textSetting.value;
        configUpdates[kStr] = textSetting.value;
      });
      if (result.isNotEmpty) {
        if (hwId.isNotEmpty) _deviceTextSettings[hwId] = result;
        if (dbId.isNotEmpty) _deviceTextSettings[dbId] = result;
      }
      if (configUpdates.isNotEmpty) {
        if (hwId.isNotEmpty) saveDeviceConfiguration(hwId, configUpdates);
        if (dbId.isNotEmpty) saveDeviceConfiguration(dbId, configUpdates);
        notifyListeners();
      }
    }
    return result;
  }

  /// Channels and telemetry configuration must strictly come from backend status/telemetry
  static Map<String, dynamic> getDefaultChannelsForModel(String? model, {String? deviceName}) {
    return const <String, dynamic>{};
  }

  bool _isWaterTank(Device? dev, [String? model, String? deviceName]) {
    final name = (dev?.name ?? deviceName ?? '').toLowerCase();
    final m = (dev?.model ?? model ?? '').toLowerCase();
    final dId = (dev?.deviceId ?? '').toLowerCase();
    return name.contains('tank') ||
        name.contains('water') ||
        m.contains('tank') ||
        m.contains('water') ||
        m == 'wt' ||
        dId.contains('wt');
  }

  QuickCommand _resolveDynamicCommand(
    QuickCommand cmd,
    Map<String, dynamic> savedConfig,
    String devId,
  ) {
    final String baseLabel = (cmd.rawLabel != null && cmd.rawLabel!.trim().isNotEmpty)
        ? cmd.rawLabel!.trim()
        : cmd.label.trim();
    final cleanBase = baseLabel.isNotEmpty
        ? baseLabel
        : (cmd.message.startsWith('/') ? cmd.message.substring(1) : cmd.message);

    if (savedConfig.isEmpty) {
      final savedSliderVal = getDeviceSliderValue(devId, cmd.message);
      return cmd.copyWith(
        rawLabel: cleanBase,
        value: savedSliderVal ?? cmd.value,
      );
    }

    String newLabel = cleanBase;

    // 1. Direct match on command message or base label (e.g. '/relay1_on', '/status', 'Relay 1')
    final directMatch = savedConfig[cmd.message] ??
        savedConfig[cmd.message.toLowerCase()] ??
        savedConfig[cleanBase] ??
        savedConfig[cleanBase.toLowerCase()];

    if (directMatch != null && directMatch.toString().trim().isNotEmpty) {
      newLabel = directMatch.toString().trim();
    } else {
      // 2. Extract slot/channel/relay number dynamically from command message or label
      // Zero hardcoding: matches any integer without hardcoded limits
      final slotMatch = RegExp(r'(?:relay|channel|slot|ch|r|s)?[\s_-]*(\d+)', caseSensitive: false).firstMatch(cmd.message) ??
          RegExp(r'(?:relay|channel|slot|ch|r|s)?[\s_-]*(\d+)', caseSensitive: false).firstMatch(cleanBase);
      final slotNum = slotMatch?.group(1);

      if (slotNum != null && slotNum.isNotEmpty) {
        final customName = savedConfig['Relay $slotNum'] ??
            savedConfig['relay $slotNum'] ??
            savedConfig['Channel $slotNum'] ??
            savedConfig['channel $slotNum'] ??
            savedConfig['Slot $slotNum'] ??
            savedConfig['slot $slotNum'] ??
            savedConfig['relay_$slotNum'] ??
            savedConfig['channel_$slotNum'] ??
            savedConfig[slotNum];

        if (customName != null && customName.toString().trim().isNotEmpty) {
          final cStr = customName.toString().trim();
          final replaced = newLabel.replaceAll(
            RegExp('(?:Relay|Channel|Slot|Ch|R)\\s*$slotNum\\b', caseSensitive: false),
            cStr,
          );

          if (replaced != newLabel) {
            newLabel = replaced;
          } else {
            // Check if label contains an action word like On, Off, Toggle, Open, Close, etc.
            final actionMatch = RegExp(
              r'\b(on|off|toggle|open|close|start|stop|up|down|high|low)\b',
              caseSensitive: false,
            ).firstMatch(cleanBase);
            if (actionMatch != null) {
              newLabel = '$cStr ${actionMatch.group(0)!.toUpperCase()}';
            } else if (RegExp(r'^\d+$').hasMatch(cleanBase)) {
              newLabel = cStr;
            }
          }
        }
      }

      // 3. Dynamic replacement for any custom names specified in savedConfig
      savedConfig.forEach((key, val) {
        if (val != null && val.toString().trim().isNotEmpty) {
          final valStr = val.toString().trim();
          final keyClean = key.toString().trim();
          if (keyClean.toLowerCase().startsWith('relay ') ||
              keyClean.toLowerCase().startsWith('channel ') ||
              keyClean.toLowerCase().startsWith('slot ')) {
            newLabel = newLabel.replaceAll(
              RegExp(RegExp.escape(keyClean) + r'\b', caseSensitive: false),
              valStr,
            );
          }
        }
      });
    }

    final savedSliderVal = getDeviceSliderValue(devId, cmd.message);
    return cmd.copyWith(
      label: newLabel,
      rawLabel: cleanBase,
      value: savedSliderVal ?? cmd.value,
    );
  }

  List<QuickCommand> getQuickCommands(String deviceId, {String? model, String? deviceName}) {
    final dev = _findDevice(deviceId);
    final hwId = dev?.deviceId.isNotEmpty == true ? dev!.deviceId : deviceId;
    final dbId = dev?.id.isNotEmpty == true ? dev!.id : deviceId;

    // 1. Direct match in _deviceRawQuickCommands or _deviceQuickCommands
    List<QuickCommand>? rawCmds = _deviceRawQuickCommands[hwId] ??
        _deviceRawQuickCommands[dbId] ??
        _deviceRawQuickCommands[deviceId] ??
        (dev != null ? _deviceRawQuickCommands[dev.deviceId] ?? _deviceRawQuickCommands[dev.id] : null);

    if (rawCmds == null || rawCmds.isEmpty) {
      rawCmds = _deviceQuickCommands[hwId] ??
          _deviceQuickCommands[dbId] ??
          _deviceQuickCommands[deviceId] ??
          (dev != null ? _deviceQuickCommands[dev.deviceId] ?? _deviceQuickCommands[dev.id] : null);
    }

    List<QuickCommand> baseList = const [];
    if (rawCmds != null && rawCmds.isNotEmpty) {
      baseList = rawCmds;
    } else if (dev != null && dev.quickCommands.isNotEmpty) {
      baseList = dev.quickCommands;
    } else {
      final customCmds = _customQuickCommands[hwId] ??
          _customQuickCommands[dbId] ??
          _customQuickCommands[deviceId] ??
          (dev != null ? _customQuickCommands[dev.deviceId] ?? _customQuickCommands[dev.id] : null);
      if (customCmds != null && customCmds.isNotEmpty) {
        baseList = customCmds;
      }
    }

    if (baseList.isEmpty) return const [];

    final savedConfig = getDeviceSavedConfig(hwId);
    return baseList.map((cmd) => _resolveDynamicCommand(cmd, savedConfig, hwId)).toList();
  }


  void _saveLatestDeviceStatus(String hwId, String dbId, Map<String, dynamic> statusData) {
    try {
      SharedPreferences.getInstance().then((prefs) {
        final jsonStr = jsonEncode(statusData);
        prefs.setString('latest_device_status_$hwId', jsonStr);
        if (hwId != dbId) {
          prefs.setString('latest_device_status_$dbId', jsonStr);
        }
      }).catchError((_) {});
    } catch (_) {}
  }

  void cacheTelemetryStatus(String hwId, String dbId, Map<String, dynamic> statusData) {
    if (hwId.isNotEmpty) {
      _latestDeviceStatusData[hwId] = Map<String, dynamic>.from(statusData);
    }
    if (dbId.isNotEmpty) {
      _latestDeviceStatusData[dbId] = Map<String, dynamic>.from(statusData);
    }
    _saveLatestDeviceStatus(hwId, dbId, statusData);
    notifyListeners();
  }

  void _syncDeviceQuickCommands(String deviceId) {
    final idx = _devices.indexWhere((d) => d.id == deviceId || d.deviceId == deviceId);
    if (idx != -1) {
      final dev = _devices[idx];
      final targetId = dev.deviceId.isNotEmpty ? dev.deviceId : dev.id;
      _devices[idx] = dev.copyWith(quickCommands: getQuickCommands(targetId));
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

  Future<void> loadDeviceConfiguration(String deviceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dev = _findDevice(deviceId);
      final hwId = dev?.deviceId.isNotEmpty == true ? dev!.deviceId : deviceId;
      final dbId = dev?.id.isNotEmpty == true ? dev!.id : deviceId;

      // 0. Load saved latest status telemetry
      final savedStatusRaw = prefs.getString('latest_device_status_$hwId') ??
          prefs.getString('latest_device_status_$dbId');
      if (savedStatusRaw != null && savedStatusRaw.isNotEmpty) {
        final decoded = jsonDecode(savedStatusRaw);
        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);
          map.updateAll((k, v) => (v is String) ? v.replaceAll(RegExp(r'\s*\[Range:[^\]]+\]', caseSensitive: false), '').trim() : v);
          _latestDeviceStatusData[hwId] = map;
          _latestDeviceStatusData[dbId] = map;
        }
      }

      // 1. Load saved custom configurations (custom names/labels)
      final savedConfigRaw = prefs.getString('device_config_$hwId') ?? prefs.getString('device_config_$dbId');
      if (savedConfigRaw != null && savedConfigRaw.isNotEmpty) {
        final decoded = jsonDecode(savedConfigRaw);
        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);
          _deviceSavedConfigurations[hwId] = map;
          _deviceSavedConfigurations[dbId] = map;
        }
      }

      // 2. Load saved slider values
      final savedSlidersRaw = prefs.getString('device_slider_values_$hwId') ?? prefs.getString('device_slider_values_$dbId');
      if (savedSlidersRaw != null && savedSlidersRaw.isNotEmpty) {
        final decoded = jsonDecode(savedSlidersRaw);
        if (decoded is Map) {
          final map = <String, double>{};
          decoded.forEach((k, v) {
            if (v is num) map[k.toString()] = v.toDouble();
          });
          _deviceSliderValues[hwId] = map;
          _deviceSliderValues[dbId] = map;
        }
      }

      // 3. Load cached commands if live commands are currently empty
      if ((_deviceQuickCommands[hwId]?.isEmpty ?? true) && (_deviceQuickCommands[dbId]?.isEmpty ?? true)) {
        final cachedCmdsRaw = prefs.getStringList('cached_device_commands_$hwId') ?? prefs.getStringList('cached_device_commands_$dbId');
        if (cachedCmdsRaw != null && cachedCmdsRaw.isNotEmpty) {
          final List<QuickCommand> cachedList = cachedCmdsRaw.map((s) {
            final decoded = jsonDecode(s);
            return QuickCommand.fromJson(Map<String, dynamic>.from(decoded as Map));
          }).toList();

          if (cachedList.isNotEmpty) {
            final dev = _findDevice(hwId) ?? _findDevice(dbId);
            final isWT = _isWaterTank(dev, dev?.model, dev?.name);
            final sanitizedList = isWT
                ? cachedList.where((c) {
                    final m = c.message.toLowerCase();
                    final l = c.label.toLowerCase();
                    return !m.contains('remote_start') &&
                        !m.contains('remote_stop') &&
                        !m.contains('remote_reset') &&
                        !l.contains('start motor') &&
                        !l.contains('stop motor') &&
                        !l.contains('reset fault');
                  }).toList()
                : cachedList;
            if (sanitizedList.isNotEmpty) {
              _deviceRawQuickCommands[hwId] = List<QuickCommand>.from(sanitizedList);
              _deviceRawQuickCommands[dbId] = List<QuickCommand>.from(sanitizedList);
              _deviceQuickCommands[hwId] = sanitizedList;
              _deviceQuickCommands[dbId] = sanitizedList;
            }
          }
        }
      }

      // 4. Apply saved configurations and slider values to commands
      _applySavedConfigToCommands(hwId);
      _applySavedConfigToCommands(dbId);

      _syncDeviceQuickCommands(hwId);
      _syncDeviceQuickCommands(dbId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading device configuration: $e');
    }
  }

  void _applySavedConfigToCommands(String devId) {
    var rawCmds = _deviceRawQuickCommands[devId];
    if (rawCmds == null || rawCmds.isEmpty) {
      rawCmds = _deviceQuickCommands[devId];
    }
    if (rawCmds == null || rawCmds.isEmpty) {
      final dev = _findDevice(devId);
      if (dev != null && dev.quickCommands.isNotEmpty) {
        rawCmds = dev.quickCommands;
      }
    }
    if (rawCmds == null || rawCmds.isEmpty) {
      return;
    }
    final savedConfig = getDeviceSavedConfig(devId);
    final updated = rawCmds.map((cmd) => _resolveDynamicCommand(cmd, savedConfig, devId)).toList();
    _deviceQuickCommands[devId] = updated;
  }

  List<QuickCommand> _parseIncomingCommands(dynamic rawCmds, String hwId, String dbId) {
    final List<QuickCommand> parsedCommands = [];
    final List<QuickCommand> rawParsedCommands = [];
    final savedConfig = getDeviceSavedConfig(hwId);

    void processCmd(String cmdKey, String cmdDesc, [Map? rawItem]) {
      final cleanCmd = cmdKey.trim();
      if (cleanCmd.isEmpty) return;

      String rawLabel = cmdDesc.trim();
      if (rawLabel.isEmpty) {
        rawLabel = cleanCmd.startsWith('/') ? cleanCmd.substring(1) : cleanCmd;
        rawLabel = rawLabel.replaceAll('_', ' ');
        rawLabel = rawLabel.replaceAllMapped(RegExp(r'([a-zA-Z])(\d)'), (m) => '${m[1]} ${m[2]}');
        rawLabel = rawLabel.isNotEmpty
            ? rawLabel[0].toUpperCase() + rawLabel.substring(1)
            : rawLabel;
      }

      final isSlider = (rawItem != null &&
              (rawItem['type'] == 'slider' ||
                  rawItem['type'] == 'range' ||
                  rawItem['slider'] == true ||
                  rawItem['isSlider'] == true)) ||
          QuickCommand.detectIsSlider(cleanCmd, rawLabel);

      final double minVal = (rawItem?['min'] as num?)?.toDouble() ??
          (rawItem?['minValue'] as num?)?.toDouble() ??
          0.0;
      final double maxVal = (rawItem?['max'] as num?)?.toDouble() ??
          (rawItem?['maxValue'] as num?)?.toDouble() ??
          100.0;
      final double step = (rawItem?['step'] as num?)?.toDouble() ?? 1.0;

      final savedSliderVal =
          getDeviceSliderValue(hwId, cleanCmd) ?? getDeviceSliderValue(dbId, cleanCmd);
      final double? currentVal = savedSliderVal ??
          (rawItem?['value'] as num?)?.toDouble() ??
          (isSlider ? minVal : null);

      final String? cmdType = (rawItem != null && rawItem['type'] != null)
          ? rawItem['type'].toString()
          : null;

      final baseCmd = QuickCommand(
        label: rawLabel,
        rawLabel: rawLabel,
        message: cleanCmd,
        type: cmdType,
        isSlider: isSlider,
        minValue: minVal,
        maxValue: maxVal,
        step: step,
        value: currentVal,
      );

      rawParsedCommands.add(baseCmd);
      parsedCommands.add(_resolveDynamicCommand(baseCmd, savedConfig, hwId));
    }

    if (rawCmds is List) {
      for (final item in rawCmds) {
        if (item is Map) {
          final cKey = (item['command'] ?? item['message'] ?? item['cmd'] ?? item['key'] ?? '').toString();
          final cDesc = (item['description'] ?? item['label'] ?? item['title'] ?? item['name'] ?? '').toString();
          processCmd(cKey, cDesc, item);
        } else if (item != null) {
          processCmd(item.toString(), '');
        }
      }
    } else if (rawCmds is Map) {
      rawCmds.forEach((key, val) {
        if (val is Map) {
          final cDesc = (val['description'] ?? val['label'] ?? val['title'] ?? val['name'] ?? '').toString();
          final cKey = (val['command'] ?? val['message'] ?? val['cmd'] ?? key).toString();
          processCmd(cKey, cDesc, val);
        } else {
          processCmd(key.toString(), val?.toString() ?? '');
        }
      });
    } else if (rawCmds is String) {
      if (rawCmds.contains(',')) {
        for (final p in rawCmds.split(',')) {
          processCmd(p.trim(), '');
        }
      } else {
        processCmd(rawCmds.trim(), '');
      }
    }

    if (parsedCommands.isNotEmpty) {
      _deviceRawQuickCommands[hwId] = rawParsedCommands;
      _deviceRawQuickCommands[dbId] = rawParsedCommands;
      _deviceQuickCommands[hwId] = parsedCommands;
      _deviceQuickCommands[dbId] = parsedCommands;
      _syncDeviceQuickCommands(hwId);
      _syncDeviceQuickCommands(dbId);

      // Cache commands to SharedPreferences
      SharedPreferences.getInstance().then((prefs) {
        final listJson = parsedCommands.map((c) => jsonEncode(c.toJson())).toList();
        prefs.setStringList('cached_device_commands_$hwId', listJson);
        if (hwId != dbId) {
          prefs.setStringList('cached_device_commands_$dbId', listJson);
        }
      }).catchError((_) {});
    }

    return parsedCommands;
  }

  Future<void> saveDeviceConfiguration(String deviceId, Map<String, dynamic> configData) async {
    try {
      final dev = _findDevice(deviceId);
      final hwId = dev?.deviceId.isNotEmpty == true ? dev!.deviceId : deviceId;
      final dbId = dev?.id.isNotEmpty == true ? dev!.id : deviceId;

      if (!_deviceSavedConfigurations.containsKey(hwId)) {
        _deviceSavedConfigurations[hwId] = {};
      }
      if (!_deviceSavedConfigurations.containsKey(dbId)) {
        _deviceSavedConfigurations[dbId] = {};
      }

      _deviceSavedConfigurations[hwId]!.addAll(configData);
      _deviceSavedConfigurations[dbId]!.addAll(configData);

      void updateTextMap(String id) {
        if (_deviceTextSettings.containsKey(id)) {
          final tMap = _deviceTextSettings[id]!;
          configData.forEach((k, v) {
            final kStr = k.toString().trim();
            final vStr = v.toString().trim();
            if (tMap.containsKey(kStr)) {
              final old = tMap[kStr]!;
              tMap[kStr] = TextSetting(key: old.key, value: vStr, range: old.range, minLength: old.minLength, maxLength: old.maxLength);
            }
          });
        }
      }
      updateTextMap(hwId);
      if (hwId != dbId) updateTextMap(dbId);

      // Check if any slider values in configData
      configData.forEach((key, val) {
        if (key.endsWith('_value') && val is num) {
          final cmdKey = key.substring(0, key.length - 6);
          _saveSliderValueInMemory(hwId, cmdKey, val.toDouble());
          _saveSliderValueInMemory(dbId, cmdKey, val.toDouble());
        }
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('device_config_$hwId', jsonEncode(_deviceSavedConfigurations[hwId]));
      if (hwId != dbId) {
        await prefs.setString('device_config_$dbId', jsonEncode(_deviceSavedConfigurations[dbId]));
      }

      if (_deviceSliderValues.containsKey(hwId)) {
        await prefs.setString('device_slider_values_$hwId', jsonEncode(_deviceSliderValues[hwId]));
      }
      if (hwId != dbId && _deviceSliderValues.containsKey(dbId)) {
        await prefs.setString('device_slider_values_$dbId', jsonEncode(_deviceSliderValues[dbId]));
      }

      // Update existing message bubbles in device.messages so renamed channel names appear immediately
      final dIdx = _devices.indexWhere((d) => d.id == dbId || d.deviceId == hwId);
      if (dIdx != -1) {
        final currentDev = _devices[dIdx];
        final updatedMsgs = currentDev.messages.map((m) {
          // Never mutate settings cards or settings messages (NUMERIC, RADIO, HOLDING, CLICKABLE, /settings, /device_setting, etc.)
          final cmdLower = (m.command ?? '').toLowerCase().trim();
          final isSettingsMsg = cmdLower == '/holding' ||
              cmdLower == '/radio' ||
              cmdLower == '/settings' ||
              cmdLower == '/setting' ||
              cmdLower == 'settings' ||
              cmdLower == 'setting' ||
              cmdLower == '/device_setting' ||
              cmdLower == 'device_setting' ||
              cmdLower == 'device setting' ||
              cmdLower == '/preserve_state' ||
              cmdLower == 'preserve_state' ||
              cmdLower == '/rename_relay' ||
              cmdLower == 'rename_relay' ||
              cmdLower == 'numeric' ||
              cmdLower == 'radio' ||
              cmdLower == 'holding' ||
              m.text.contains('"type": "RADIO"') ||
              m.text.contains('"type": "NUMERIC"') ||
              m.text.contains('"type": "HOLDING"') ||
              m.text.contains('"type": "CLICKABLE"') ||
              m.text.startsWith('__CLICKABLE__:');
          if (isSettingsMsg) {
            return m;
          }

          if (!m.isUser && m.text.contains(':')) {
            final lines = m.text.split('\n');
            int chIdx = 1;
            final newLines = lines.map((l) {
              if (l.contains(':')) {
                final colon = l.indexOf(':');
                final k = l.substring(0, colon).trim();
                final v = l.substring(colon + 1).trim();
                final kLower = k.toLowerCase();

                // Only rename if key actually represents a channel, relay, or slot
                final isChannelKey = kLower.startsWith('channel') ||
                    kLower.startsWith('relay') ||
                    kLower.startsWith('slot') ||
                    RegExp(r'^\d+$').hasMatch(k);

                String? renamed;
                if (isChannelKey) {
                  final slotNumMatch = RegExp(r'\d+').firstMatch(k);
                  final slotNum = slotNumMatch?.group(0);
                  final savedMap = _deviceSavedConfigurations[hwId];
                  renamed = (slotNum != null ? configData['Relay $slotNum'] : null) ??
                      (slotNum != null ? configData['relay $slotNum'] : null) ??
                      (slotNum != null ? configData['Slot $slotNum'] : null) ??
                      (slotNum != null ? configData['slot $slotNum'] : null) ??
                      (slotNum != null ? configData['Channel $slotNum'] : null) ??
                      (slotNum != null ? configData['channel $slotNum'] : null) ??
                      (slotNum != null ? configData[slotNum] : null) ??
                      (slotNum != null && savedMap != null ? savedMap['Relay $slotNum'] : null) ??
                      (slotNum != null && savedMap != null ? savedMap['Slot $slotNum'] : null) ??
                      (slotNum != null && savedMap != null ? savedMap['Channel $slotNum'] : null) ??
                      (slotNum != null && savedMap != null ? savedMap[slotNum] : null) ??
                      configData[k] ??
                      configData['Channel $chIdx'] ??
                      configData['Relay $chIdx'] ??
                      configData['Slot $chIdx'] ??
                      configData[kLower] ??
                      savedMap?[k] ??
                      savedMap?[kLower];
                  chIdx++;
                }

                if (renamed != null && renamed.toString().trim().isNotEmpty) {
                  return '${renamed.toString().trim()}: $v';
                }
              }
              return l;
            }).toList();
            return ChatMessage(
              id: m.id,
              text: newLines.join('\n'),
              title: m.title,
              command: m.command,
              sender: m.sender,
              timestamp: m.timestamp,
            );
          }
          return m;
        }).toList();
        _devices[dIdx] = currentDev.copyWith(messages: updatedMsgs);
      }

      _applySavedConfigToCommands(hwId);
      _applySavedConfigToCommands(dbId);
      _syncDeviceQuickCommands(hwId);
      _syncDeviceQuickCommands(dbId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving device configuration: $e');
    }
  }

  Future<void> clearDeviceConfiguration(String deviceId) async {
    try {
      final dev = _findDevice(deviceId);
      final hwId = dev?.deviceId.isNotEmpty == true ? dev!.deviceId : deviceId;
      final dbId = dev?.id.isNotEmpty == true ? dev!.id : deviceId;

      _deviceSavedConfigurations.remove(hwId);
      _deviceSavedConfigurations.remove(dbId);

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('device_config_$hwId');
      if (hwId != dbId) {
        await prefs.remove('device_config_$dbId');
      }

      _applySavedConfigToCommands(hwId);
      _applySavedConfigToCommands(dbId);
      _syncDeviceQuickCommands(hwId);
      _syncDeviceQuickCommands(dbId);
      notifyListeners();
    } catch (_) {}
  }

  void _saveSliderValueInMemory(String devId, String key, double value) {
    if (!_deviceSliderValues.containsKey(devId)) {
      _deviceSliderValues[devId] = {};
    }
    _deviceSliderValues[devId]![key] = value;
  }

  Future<void> updateSliderValue(
    String deviceId,
    String commandOrKey,
    double value, {
    bool sendCommand = false,
  }) async {
    final dev = _findDevice(deviceId);
    final hwId = dev?.deviceId.isNotEmpty == true ? dev!.deviceId : deviceId;
    final dbId = dev?.id.isNotEmpty == true ? dev!.id : deviceId;

    _saveSliderValueInMemory(hwId, commandOrKey, value);
    _saveSliderValueInMemory(dbId, commandOrKey, value);

    if (!_deviceSavedConfigurations.containsKey(hwId)) {
      _deviceSavedConfigurations[hwId] = {};
    }
    if (!_deviceSavedConfigurations.containsKey(dbId)) {
      _deviceSavedConfigurations[dbId] = {};
    }
    _deviceSavedConfigurations[hwId]!['${commandOrKey}_value'] = value;
    _deviceSavedConfigurations[dbId]!['${commandOrKey}_value'] = value;

    // Update command in memory
    for (final targetId in [hwId, dbId]) {
      if (_deviceQuickCommands.containsKey(targetId)) {
        final list = _deviceQuickCommands[targetId]!;
        final idx = list.indexWhere((c) => c.message == commandOrKey || c.label == commandOrKey);
        if (idx != -1) {
          list[idx] = list[idx].copyWith(value: value, isSlider: true);
        }
      }
    }

    _syncDeviceQuickCommands(hwId);
    _syncDeviceQuickCommands(dbId);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('device_slider_values_$hwId', jsonEncode(_deviceSliderValues[hwId]));
      if (hwId != dbId) {
        await prefs.setString('device_slider_values_$dbId', jsonEncode(_deviceSliderValues[dbId]));
      }
      await prefs.setString('device_config_$hwId', jsonEncode(_deviceSavedConfigurations[hwId]));
      if (hwId != dbId) {
        await prefs.setString('device_config_$dbId', jsonEncode(_deviceSavedConfigurations[dbId]));
      }
    } catch (e) {
      debugPrint('Error persisting slider value: $e');
    }

    if (sendCommand) {
      final intVal = value.toInt();
      final msgToSend = '$commandOrKey $intVal';

      String label = commandOrKey;
      final cmds = getQuickCommands(hwId);
      final match = cmds.firstWhere(
        (c) => c.message == commandOrKey,
        orElse: () => QuickCommand(label: commandOrKey, message: commandOrKey),
      );
      label = match.label;

      sendMessage(msgToSend, displayText: '$label: $intVal');
    }
  }

  void sendSliderCommand(String deviceId, QuickCommand cmd, double value) {
    updateSliderValue(deviceId, cmd.message, value, sendCommand: true);
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
    if (_selectedDeviceId == id && (_webSocketChannel != null || _isConnectingWebSocket)) return;

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
          quickCommands: getQuickCommands(device.deviceId, model: device.model, deviceName: device.name),
        );
      }
      notifyListeners();

      // 2. Load saved configurations, custom commands, and slider values for persistence upon reopening
      loadCustomCommands(device.deviceId);
      loadCustomCommands(device.id);
      loadDeviceConfiguration(device.deviceId);
      loadDeviceConfiguration(device.id);

      // Connect single WebSocket immediately to the selected device
      _connectWebSocket(device.id, device.deviceId);
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

        final rawModel = raw['model']?.toString() ??
            raw['deviceModel']?.toString() ??
            raw['modelName']?.toString() ??
            raw['modelType']?.toString() ??
            raw['type']?.toString();
        final detectedModel = detectDeviceModel(
          explicitModel: rawModel,
          deviceId: hwId,
          deviceName: deviceName,
        );

        // Dynamically extract backend commands if provided in device list
        dynamic rawCmds = raw['availableCommands'] ??
            raw['available_commands'] ??
            raw['additionalCommands'] ??
            raw['commands'] ??
            raw['quickCommands'] ??
            raw['quick_commands'] ??
            raw['commandList'] ??
            raw['command_list'] ??
            raw['actions'] ??
            raw['supportedCommands'] ??
            raw['supported_commands'];
        if (rawCmds != null) {
          _parseIncomingCommands(rawCmds, hwId, dbId);
        }



        Map<String, dynamic>? rawTelemetry;
        if (raw['telemetry'] is Map) {
          rawTelemetry = Map<String, dynamic>.from(raw['telemetry']);
        } else if (raw['data'] is Map) {
          rawTelemetry = Map<String, dynamic>.from(raw['data']);
        } else if (raw['status'] is Map) {
          rawTelemetry = Map<String, dynamic>.from(raw['status']);
        } else if (raw['payload'] is Map) {
          rawTelemetry = Map<String, dynamic>.from(raw['payload']);
        } else if (raw['tanks'] is List) {
          rawTelemetry = {};
          for (final t in raw['tanks']) {
            if (t is Map) {
              final n = t['name'] ?? t['tank'] ?? t['label'] ?? '';
              final v = t['level'] ?? t['value'] ?? t['status'] ?? '';
              if (n.toString().isNotEmpty) rawTelemetry[n.toString()] = v;
            }
          }
        }
        if (rawTelemetry != null) {
          final controlKeys = {
            'deviceid', 'firmwareversion', 'availablecommands', 'additionalcommands',
            'type', 'success', 'message', 'command', 'timestamp', 'id', 'version', 'lastseen',
            'hardwareversion', 'softwareversion', 'status', 'model', 'name', 'action',
            'connected', 'ip', 'rssi', 'mac', 'raw'
          };
          rawTelemetry.removeWhere((k, v) => controlKeys.contains(k.toLowerCase().trim()));
        }
        if (rawTelemetry != null && rawTelemetry.isNotEmpty) {
          _latestDeviceStatusData[hwId] = rawTelemetry;
          _latestDeviceStatusData[dbId] = rawTelemetry;
        }

        final lastSeenVal = raw['lastSeen'];
        bool isOnlineDevice = false;
        if (lastSeenVal != null && lastSeenVal.toString() != 'null') {
          final parsed = _parseDateTime(lastSeenVal.toString());
          if (parsed != null) {
            final difference = DateTime.now().toUtc().difference(parsed.toUtc()).inMinutes;
            isOnlineDevice = difference.abs() <= 5;
          }
        }

        final rawHwVersion = raw['hardwareVersion']?.toString() ??
            raw['hardware_version']?.toString() ??
            raw['hwVersion']?.toString() ??
            raw['hw_version']?.toString() ??
            raw['hardware']?.toString();
        final rawSwVersion = raw['softwareVersion']?.toString() ??
            raw['software_version']?.toString() ??
            raw['firmwareVersion']?.toString() ??
            raw['firmware_version']?.toString() ??
            raw['fwVersion']?.toString() ??
            raw['version']?.toString() ??
            raw['swVersion']?.toString();

        final lastSeenStr = raw['lastSeen']?.toString();
        final lastActive = _formatToIst(lastSeenStr);

        final ownerObj = raw['owner'] ?? raw['admin'] ?? raw['createdBy'] ?? raw['ownerUser'];
        String? parsedOwnerName;
        String? parsedOwnerEmail;
        if (ownerObj is Map) {
          parsedOwnerName = ownerObj['name']?.toString() ?? ownerObj['userName']?.toString();
          parsedOwnerEmail = ownerObj['email']?.toString() ?? ownerObj['phoneNumber']?.toString();
        } else if (raw['ownerName'] != null || raw['ownerEmail'] != null) {
          parsedOwnerName = raw['ownerName']?.toString();
          parsedOwnerEmail = raw['ownerEmail']?.toString();
        } else if (ownerObj is String && ownerObj.isNotEmpty) {
          parsedOwnerName = ownerObj;
        }

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
            model: detectedModel,
            hardwareVersion: rawHwVersion,
            softwareVersion: rawSwVersion,
            ownerName: parsedOwnerName,
            ownerEmail: parsedOwnerEmail,
            quickCommands: getQuickCommands(hwId, model: detectedModel, deviceName: deviceName),
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

      final rawModel = rawDevice['model']?.toString() ??
          rawDevice['deviceModel']?.toString() ??
          rawDevice['modelName']?.toString() ??
          rawDevice['modelType']?.toString() ??
          rawDevice['type']?.toString();
      final detectedModel = detectDeviceModel(
        explicitModel: rawModel,
        deviceId: hwId,
        deviceName: deviceName,
      );

      dynamic rawCmds = rawDevice['availableCommands'] ??
          rawDevice['available_commands'] ??
          rawDevice['additionalCommands'] ??
          rawDevice['commands'] ??
          rawDevice['quickCommands'] ??
          rawDevice['quick_commands'] ??
          rawDevice['commandList'] ??
          rawDevice['command_list'] ??
          rawDevice['actions'] ??
          rawDevice['supportedCommands'] ??
          rawDevice['supported_commands'];
      if (rawCmds != null) {
        _parseIncomingCommands(rawCmds, hwId, dbId);
      }



      Map<String, dynamic>? rawTelemetry;
      if (rawDevice['telemetry'] is Map) {
        rawTelemetry = Map<String, dynamic>.from(rawDevice['telemetry']);
      } else if (rawDevice['data'] is Map) {
        rawTelemetry = Map<String, dynamic>.from(rawDevice['data']);
      } else if (rawDevice['status'] is Map) {
        rawTelemetry = Map<String, dynamic>.from(rawDevice['status']);
      } else if (rawDevice['payload'] is Map) {
        rawTelemetry = Map<String, dynamic>.from(rawDevice['payload']);
      } else if (rawDevice['tanks'] is List) {
        rawTelemetry = {};
        for (final t in rawDevice['tanks']) {
          if (t is Map) {
            final n = t['name'] ?? t['tank'] ?? t['label'] ?? '';
            final v = t['level'] ?? t['value'] ?? t['status'] ?? '';
            if (n.toString().isNotEmpty) rawTelemetry[n.toString()] = v;
          }
        }
      }
      if (rawTelemetry != null) {
        final controlKeys = {
          'deviceid', 'firmwareversion', 'availablecommands', 'additionalcommands',
          'type', 'success', 'message', 'command', 'timestamp', 'id', 'version', 'lastseen',
          'hardwareversion', 'softwareversion', 'status', 'model', 'name', 'action',
          'connected', 'ip', 'rssi', 'mac', 'raw'
        };
        rawTelemetry.removeWhere((k, v) => controlKeys.contains(k.toLowerCase().trim()));
      }
      if (rawTelemetry != null && rawTelemetry.isNotEmpty) {
        _latestDeviceStatusData[hwId] = rawTelemetry;
        _latestDeviceStatusData[dbId] = rawTelemetry;
      }
      
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

      final rawHwVersion = rawDevice['hardwareVersion']?.toString() ??
          rawDevice['hardware_version']?.toString() ??
          rawDevice['hwVersion']?.toString() ??
          rawDevice['hw_version']?.toString() ??
          rawDevice['hardware']?.toString();
      final rawSwVersion = rawDevice['softwareVersion']?.toString() ??
          rawDevice['software_version']?.toString() ??
          rawDevice['firmwareVersion']?.toString() ??
          rawDevice['firmware_version']?.toString() ??
          rawDevice['fwVersion']?.toString() ??
          rawDevice['version']?.toString() ??
          rawDevice['swVersion']?.toString();

      final ownerObj = rawDevice['owner'] ?? rawDevice['admin'] ?? rawDevice['createdBy'] ?? rawDevice['ownerUser'];
      String? parsedOwnerName;
      String? parsedOwnerEmail;
      if (ownerObj is Map) {
        parsedOwnerName = ownerObj['name']?.toString() ?? ownerObj['userName']?.toString();
        parsedOwnerEmail = ownerObj['email']?.toString() ?? ownerObj['phoneNumber']?.toString();
      } else if (rawDevice['ownerName'] != null || rawDevice['ownerEmail'] != null) {
        parsedOwnerName = rawDevice['ownerName']?.toString();
        parsedOwnerEmail = rawDevice['ownerEmail']?.toString();
      } else if (ownerObj is String && ownerObj.isNotEmpty) {
        parsedOwnerName = ownerObj;
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
          model: detectedModel,
          hardwareVersion: rawHwVersion ?? _devices[index].hardwareVersion,
          softwareVersion: rawSwVersion ?? _devices[index].softwareVersion,
          ownerName: parsedOwnerName ?? _devices[index].ownerName,
          ownerEmail: parsedOwnerEmail ?? _devices[index].ownerEmail,
          quickCommands: getQuickCommands(hwId, model: detectedModel, deviceName: deviceName),
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
    saveDeviceConfiguration(deviceId, configData);

    final index = _devices.indexWhere((d) => d.id == deviceId || d.deviceId == deviceId);
    if (index != -1) {
      final device = _devices[index];
      _setDeviceOnline(device.id, true);
      _resetWatchdog(device.id);

      final Map<String, dynamic> slotData = {};
      int slotIdx = 1;
      configData.forEach((k, v) {
        if (!k.toLowerCase().startsWith('channel ') && !k.endsWith('_value')) {
          slotData['$slotIdx'] = v.toString();
          slotIdx++;
        }
      });

      final payload = jsonEncode({
        'command': '/config',
        'data': slotData.isNotEmpty ? slotData : configData,
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

  Future<void> sendMessage(String text, {String? displayText, String? targetDeviceId}) async {
    final devId = targetDeviceId ?? _selectedDeviceId;
    if (devId == null) return;

    final index = _devices.indexWhere((d) => d.id == devId || d.deviceId == devId);
    if (index == -1) return;

    final device = _devices[index];
    final cmdToSend = text.trim();
    final userDisplayText = displayText ?? text;

    final userMsg = ChatMessage(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      text: userDisplayText,
      command: cmdToSend,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    );

    final updatedMessages = List<ChatMessage>.from(device.messages)..add(userMsg);
    _devices[index] = device.copyWith(
      messages: updatedMessages,
    );
    notifyListeners();

    Map<String, dynamic> msgMap;
    if (cmdToSend.startsWith('{') && cmdToSend.endsWith('}')) {
      try {
        final decoded = jsonDecode(cmdToSend);
        if (decoded is Map<String, dynamic>) {
          msgMap = decoded;
        } else {
          msgMap = {'command': cmdToSend};
        }
      } catch (_) {
        msgMap = {'command': cmdToSend};
      }
    } else {
      msgMap = {'command': cmdToSend};
    }

    // Global contract test payloads & dynamic command dispatch
    final lowerCmd = cmdToSend.toLowerCase().trim();
    String? testJson;

    final contractAvailableCommands = [
      {"command": "/remote_start", "description": "Start Motor"},
      {"command": "/remote_stop", "description": "Stop Motor"},
      {"command": "/remote_reset", "description": "Reset Fault"},
      {"command": "/status", "description": "Get Device Status"},
      {"command": "/holding", "description": "Get Device Settings"},
      {"command": "/radio", "description": "Get Radio Settings"},
      {"command": "/time", "description": "Get Device Schedule"},
      {"command": "/cyclic", "description": "Get Cyclic Timer"},
      {"command": "/config", "description": "Configure channel names"},
      {"command": "/about", "description": "About Device"}
    ];

    final dev = _findDevice(targetDeviceId ?? _selectedDeviceId ?? '');
    final isRelayDevice = dev?.name.toLowerCase().contains('relay') == true ||
        dev?.deviceId.toLowerCase().contains('rm') == true ||
        dev?.model?.toLowerCase().contains('rm') == true ||
        dev?.model?.toLowerCase().contains('relay') == true;

    final bool isTestPrefix = lowerCmd.startsWith('/test ') || lowerCmd.startsWith('test ');

    // Only synthesize demo mock replies for explicit "/test <type>" triggers when testing offline
    final isTestNumeric = lowerCmd == '/test numeric' || lowerCmd == 'test numeric' || lowerCmd == '/test range' || lowerCmd == 'test range';
    final isTestText = lowerCmd == '/test text' || lowerCmd == 'test text';
    final isTestTime = lowerCmd == '/test time' || lowerCmd == 'test time';
    final isTestCyclic = lowerCmd == '/test cyclic' || lowerCmd == 'test cyclic';
    final isTestRadio = lowerCmd == '/test radio' || lowerCmd == 'test radio';
    final isTestClickable = lowerCmd == '/test clickable' || lowerCmd == 'test clickable';
    final isTestResponse = lowerCmd == '/test response' || lowerCmd == 'test response';

    final bool isExplicitTestTrigger = isTestPrefix && (isTestNumeric || isTestText || isTestTime || isTestRadio || isTestClickable || isTestResponse || isTestCyclic);

    if (isTestNumeric) {
      testJson = jsonEncode({
        "type": "NUMERIC",
        "data": {
          "overload_current": {
            "value": "20.0 A",
            "range": "2 - 30"
          },
          "dry_run": {
            "value": 1,
            "range": "0 - 1"
          },
          "dry_run_current": {
            "value": "5.0 A",
            "range": "2 - 20"
          },
          "drs_recovery_delay": {
            "value": "15 min",
            "range": "0 - 999"
          }
        },
        "availableCommands": contractAvailableCommands
      });
    } else if (isTestText) {
      testJson = jsonEncode({
        "type": "TEXT",
        "data": {
          "1": "Relay 1",
          "2": "Relay 2"
        },
        "availableCommands": contractAvailableCommands
      });
    } else if (isTestTime) {
      testJson = jsonEncode({
        "type": "TIME",
        "data": {
          "set_timing_1": "17:15 18:20",
          "set_timing_2": "18:30 18:40"
        }
      });
    } else if (isTestCyclic) {
      testJson = jsonEncode({
        "type": "CYCLIC",
        "data": {
          "cyclic": "10-20"
        },
        "availableCommands": contractAvailableCommands
      });
    } else if (isTestRadio) {
      testJson = jsonEncode({
        "type": "RADIO",
        "data": {
          "PS": "0",
          "POP": "0"
        }
      });
    } else if (isTestResponse) {
      testJson = jsonEncode({
        "type": "RESPONSE",
        "data": {
          "ac_voltage": "230.5 V",
          "ac_current": "12.3 A",
          "motor_status": "Running"
        },
        "availableCommands": contractAvailableCommands
      });
    } else if (isTestClickable) {
      testJson = jsonEncode({
        "type": "CLICKABLE",
        "data": [
          {"command": "/device_setting", "label": "Device Setting"},
          {"command": "/preserve_state", "label": "Preserve State"},
          {"command": "/rename_relay", "label": "Rename Relay"}
        ]
      });
    }

    final payload = jsonEncode(msgMap);

    // 1. Transmit to live hardware over WebSocket if connected
    if (_webSocketChannel != null) {
      try {
        _webSocketChannel!.sink.add(payload);
        debugPrint('Transmitted command to live hardware: $payload');
      } catch (e) {
        debugPrint('WebSocket write failed: $e');
        _disconnectWebSocket();
        _connectWebSocket(device.id, device.deviceId);
      }

      // Let the live hardware response be received exclusively via the WebSocket stream.
      // Do NOT inject simulated/mock reply to prevent duplicate output!
      if (!isTestPrefix) {
        return;
      }
    }

    // 2. Always provide simulated/contract reply for explicit /test triggers or offline fallback
    if (isExplicitTestTrigger && testJson != null) {
      Future.delayed(const Duration(milliseconds: 300), () {
        _addDeviceReplyMessage(device.id, testJson!);
      });
      return;
    }

    // 3. If WebSocket is disconnected, try establishing connection
    if (_webSocketChannel == null && !_isConnectingWebSocket) {
      _connectWebSocket(device.id, device.deviceId);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_webSocketChannel != null) {
          try {
            _webSocketChannel!.sink.add(payload);
          } catch (_) {}
        }
      });
      final isDeviceSettingCmd = lowerCmd == '/device_setting' ||
          lowerCmd == 'device_setting' ||
          lowerCmd == 'device setting' ||
          lowerCmd == '/device_settings' ||
          lowerCmd == 'device_settings' ||
          lowerCmd == 'device settings';

      final isSettingsMenuCmd = lowerCmd == '/settings' ||
          lowerCmd == 'settings' ||
          lowerCmd == '/setting' ||
          lowerCmd == 'setting';

      if (isDeviceSettingCmd) {
        Future.delayed(const Duration(milliseconds: 150), () {
          final devId = device.deviceId.isNotEmpty ? device.deviceId : device.id;
          final savedCfg = getDeviceSavedConfig(devId);
          final r1 = savedCfg['Relay 1'] ?? savedCfg['1'] ?? 'Relay 1';
          final r2 = savedCfg['Relay 2'] ?? savedCfg['2'] ?? 'Relay 2';
          _addDeviceReplyMessage(device.id, jsonEncode({
            "type": "CLICKABLE",
            "data": [
              {"command": r1.toString(), "label": r1.toString()},
              {"command": r2.toString(), "label": r2.toString()}
            ],
            "availableCommands": contractAvailableCommands
          }));
        });
        return;
      }

      if (isSettingsMenuCmd) {
        Future.delayed(const Duration(milliseconds: 150), () {
          _addDeviceReplyMessage(device.id, jsonEncode({
            "type": "CLICKABLE",
            "data": [
              {"command": "/device_setting", "label": "Device Setting"},
              {"command": "/preserve_state", "label": "Preserve State"},
              {"command": "/rename_relay", "label": "Rename Relay"}
            ],
            "availableCommands": contractAvailableCommands
          }));
        });
        return;
      }

      if (!isTestPrefix) {
        return;
      }
    }

    // 4. Handle write commands fallback for local config updating
    final writeCmd = msgMap['command']?.toString().toLowerCase().trim();
    final isWriteCommand = writeCmd == '/holding' ||
        writeCmd == '/time' ||
        writeCmd == '/config' ||
        writeCmd == '/radio' ||
        writeCmd == '/settings' ||
        writeCmd == '/setting' ||
        writeCmd == '/write_register' ||
        writeCmd == '/write register';
    if (isWriteCommand && msgMap['data'] is Map) {
      final Map writeData = msgMap['data'] as Map;
      final devId = device.deviceId.isNotEmpty ? device.deviceId : device.id;
      final currentSaved = Map<String, dynamic>.from(getDeviceSavedConfig(devId));
      writeData.forEach((k, v) {
        currentSaved[k.toString()] = v;
      });
      saveDeviceConfiguration(devId, currentSaved);
      if (!device.isOnline || _webSocketChannel == null) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _addDeviceReplyMessage(device.id, jsonEncode({
            "status": "success",
            "message": "Updated successfully"
          }));
        });
      }
      return;
    }

    // If user pastes raw JSON starting with {"type": ...}, also simulate device reply:
    final cleanPasteInput = cmdToSend.trim().replaceAll('“', '"').replaceAll('”', '"').replaceAll('‘', "'").replaceAll('’', "'");
    if (cleanPasteInput.startsWith('{') && cleanPasteInput.toLowerCase().contains('"type"')) {
      Future.delayed(const Duration(milliseconds: 300), () {
        _addDeviceReplyMessage(device.id, cleanPasteInput);
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
    if (hwId.isEmpty && dbId.isEmpty) return;
    final targetHwId = hwId.isNotEmpty ? hwId : dbId;

    if (_connectedHardwareId == targetHwId && (_webSocketChannel != null || _isConnectingWebSocket)) {
      // Already actively connected or connecting to this device's websocket stream, keep ONLY ONE websocket
      return;
    }
    _disconnectWebSocket();
    _intentionalDisconnect = false;
    _connectedHardwareId = targetHwId;
    _isConnectingWebSocket = true;
    final int currentEpoch = ++_connectionEpoch;

    // Connect watchdog timer: if no message arrives in 10 seconds, it remains offline
    _resetWatchdog(dbId);

    if (_token == null || _token!.isEmpty) {
      SharedPreferences.getInstance().then((prefs) {
        if (_connectionEpoch != currentEpoch) return;
        final savedToken = prefs.getString('auth_token');
        if (savedToken != null && savedToken.isNotEmpty) {
          _token = savedToken;
          _isConnectingWebSocket = false;
          _connectWebSocket(dbId, targetHwId);
        } else {
          _isConnectingWebSocket = false;
        }
      }).catchError((_) {
        if (_connectionEpoch == currentEpoch) {
          _isConnectingWebSocket = false;
        }
      });
      return;
    }

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
      final wsUrlStr = '$wsBase/ws?deviceId=$targetHwId&type=mobile&token=$_token';
      final wsUri = Uri.parse(wsUrlStr);
      
      final channel = WebSocketChannel.connect(
        wsUri,
        protocols: kIsWeb ? null : ['Bearer', _token!],
      );

      if (_connectionEpoch != currentEpoch) {
        try {
          channel.sink.close();
        } catch (_) {}
        return;
      }

      _webSocketChannel = channel;
      _isConnectingWebSocket = false;

      _webSocketSubscription = channel.stream.listen(
        (message) {

 print('🔥 [WEBSOCKET MESSAGE] ===> $message');
          
          if (_connectionEpoch != currentEpoch || _webSocketChannel != channel) {
            return;
          }
          
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
              Map<String, dynamic>? telemetryMap;
              if (parsed.containsKey('data') && parsed['data'] is Map) {
                final d = parsed['data'] as Map;
                telemetryMap = {};
                d.forEach((k, v) {
                  if (v is Map && v.containsKey('value')) {
                    final val = v['value'];
                    telemetryMap![k.toString()] = val;
                  } else {
                    telemetryMap![k.toString()] = v;
                  }
                });
              } else if (parsed.containsKey('telemetry') && parsed['telemetry'] is Map) {
                telemetryMap = Map<String, dynamic>.from(parsed['telemetry'] as Map);
              } else if (parsed.containsKey('status') && parsed['status'] is Map) {
                telemetryMap = Map<String, dynamic>.from(parsed['status'] as Map);
              } else if (parsed.containsKey('payload') && parsed['payload'] is Map) {
                telemetryMap = Map<String, dynamic>.from(parsed['payload'] as Map);
              } else if (parsed.containsKey('tanks') && parsed['tanks'] is List) {
                telemetryMap = {};
                for (final t in parsed['tanks']) {
                  if (t is Map) {
                    final n = t['name'] ?? t['tank'] ?? t['label'] ?? t['tank_name'] ?? t['key'] ?? '';
                    final v = t['level'] ?? t['value'] ?? t['status'] ?? t['val'] ?? '';
                    if (n.toString().isNotEmpty) {
                      telemetryMap![_cleanKey(n.toString())] = v;
                    }
                  }
                }
              } else if (parsed.containsKey('data') && parsed['data'] is List) {
                telemetryMap = {};
                for (final t in parsed['data']) {
                  if (t is Map) {
                    final n = t['name'] ?? t['tank'] ?? t['label'] ?? t['tank_name'] ?? t['key'] ?? '';
                    final v = t['level'] ?? t['value'] ?? t['status'] ?? t['val'] ?? '';
                    if (n.toString().isNotEmpty) {
                      telemetryMap![_cleanKey(n.toString())] = v;
                    }
                  }
                }
              } else {
                final controlKeys = {
                  'deviceid', 'firmwareversion', 'availablecommands', 'additionalcommands',
                  'type', 'success', 'message', 'command', 'timestamp', 'id', 'version', 'lastseen'
                };
                final filtered = <String, dynamic>{};
                parsed.forEach((k, v) {
                  if (!controlKeys.contains(k.toString().toLowerCase())) {
                    filtered[k.toString()] = v;
                  }
                });
                if (filtered.isNotEmpty) {
                  telemetryMap = filtered;
                }
              }

              final cmdStr = parsed['command']?.toString().toLowerCase();
              final isConfigMsg = cmdStr == '/config' || cmdStr == 'config' || type == 'config';

              if (!isConfigMsg) {
                final parsedData = _extractDataPreservingDuplicates(
                  rawMsg,
                  telemetryMap,
                );
                final finalTelemetry = parsedData.isNotEmpty ? parsedData : (telemetryMap ?? {});
                if (finalTelemetry.isNotEmpty) {
                  _latestDeviceStatusData[hwId] = finalTelemetry;
                  _latestDeviceStatusData[dbId] = finalTelemetry;
                  _saveLatestDeviceStatus(hwId, dbId, finalTelemetry);
                }
              }

              // Update device model and version if received via websocket
              // Also extract from RESPONSE data map dynamically (hw_version, sw_version, etc.)
              Map? responseDataMap;
              if (type?.toUpperCase() == 'RESPONSE' && parsed['data'] is Map) {
                responseDataMap = parsed['data'] as Map;
              }

              final wsModel = parsed['model']?.toString() ??
                  parsed['deviceModel']?.toString() ??
                  parsed['modelName']?.toString();
              final wsHwVersion = parsed['hardwareVersion']?.toString() ??
                  parsed['hardware_version']?.toString() ??
                  parsed['hwVersion']?.toString() ??
                  parsed['hardware']?.toString() ??
                  // Also check inside RESPONSE data map dynamically
                  responseDataMap?['hw_version']?.toString() ??
                  responseDataMap?['hardwareVersion']?.toString() ??
                  responseDataMap?['hardware_version']?.toString() ??
                  responseDataMap?['hwVersion']?.toString();
              final wsSwVersion = parsed['softwareVersion']?.toString() ??
                  parsed['software_version']?.toString() ??
                  parsed['firmwareVersion']?.toString() ??
                  parsed['firmware_version']?.toString() ??
                  parsed['version']?.toString() ??
                  // Also check inside RESPONSE data map dynamically
                  responseDataMap?['sw_version']?.toString() ??
                  responseDataMap?['softwareVersion']?.toString() ??
                  responseDataMap?['software_version']?.toString() ??
                  responseDataMap?['firmwareVersion']?.toString() ??
                  responseDataMap?['firmware_version']?.toString() ??
                  responseDataMap?['fwVersion']?.toString();

              final dIdx = _devices.indexWhere((d) => d.id == dbId || d.deviceId == hwId);
              if (dIdx != -1) {
                final detected = (wsModel != null && wsModel.isNotEmpty)
                    ? detectDeviceModel(
                        explicitModel: wsModel,
                        deviceId: hwId,
                        deviceName: _devices[dIdx].name,
                      )
                    : _devices[dIdx].model;
                _devices[dIdx] = _devices[dIdx].copyWith(
                  model: detected,
                  hardwareVersion: wsHwVersion ?? _devices[dIdx].hardwareVersion,
                  softwareVersion: wsSwVersion ?? _devices[dIdx].softwareVersion,
                );
              }

              dynamic incomingCmds = parsed['availableCommands'] ??
                  parsed['available_commands'] ??
                  parsed['additionalCommands'] ??
                  parsed['commands'] ??
                  parsed['commandList'] ??
                  parsed['command_list'] ??
                  parsed['actions'] ??
                  parsed['supportedCommands'] ??
                  parsed['supported_commands'];
              if (incomingCmds == null && parsed['data'] is Map) {
                final d = parsed['data'] as Map;
                incomingCmds = d['availableCommands'] ??
                    d['available_commands'] ??
                    d['additionalCommands'] ??
                    d['commands'] ??
                    d['commandList'] ??
                    d['command_list'] ??
                    d['actions'] ??
                    d['supportedCommands'] ??
                    d['supported_commands'];
              }
              if (incomingCmds == null && parsed['payload'] is Map) {
                final p = parsed['payload'] as Map;
                incomingCmds = p['availableCommands'] ??
                    p['available_commands'] ??
                    p['additionalCommands'] ??
                    p['commands'] ??
                    p['commandList'] ??
                    p['actions'] ??
                    p['supportedCommands'];
              }
              if (incomingCmds != null) {
                _parseIncomingCommands(incomingCmds, hwId, dbId);
              }

              final effectiveType = resolvePayloadType(parsed);
              if (effectiveType == 'NUMERIC' && parsed['data'] is Map) {
                parseNumericPayloadData(Map<String, dynamic>.from(parsed), hwId, dbId);
              }

              if (effectiveType == 'TEXT' && parsed['data'] is Map) {
                parseTextPayloadData(Map<String, dynamic>.from(parsed), hwId, dbId);
              }

              if (effectiveType == 'RADIO' && parsed['data'] is Map) {
                parseRadioPayloadData(Map<String, dynamic>.from(parsed), hwId, dbId);
              }

              if (effectiveType == 'TIME' && parsed['data'] is Map) {
                parseTimePayloadData(Map<String, dynamic>.from(parsed));
              }

              if (effectiveType == 'CYCLIC' && parsed['data'] is Map) {
                parseCyclicPayloadData(Map<String, dynamic>.from(parsed));
              }

              // Filter out pure command echo or transient sent/delivery acks from server
              final bool isPureCommandEcho = parsed.containsKey('command') &&
                  !parsed.containsKey('data') &&
                  !parsed.containsKey('telemetry') &&
                  !parsed.containsKey('payload') &&
                  !parsed.containsKey('tanks') &&
                  (parsed['message'] == null || parsed['message'].toString().trim().isEmpty) &&
                  (parsed['status'] == null ||
                      (parsed['status'] is! Map &&
                          (parsed['status'] == 'sent' ||
                              parsed['status'] == 'ok' ||
                              parsed['status'] == 'delivered' ||
                              parsed['status'] == 'success')));

              if (type == 'heartbeat' || isConfigMsg || isPureCommandEcho) {
                // Heartbeat, config, and pure command echoes should NOT add a chat reply message bubble
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
          if (_connectionEpoch != currentEpoch || _webSocketChannel != channel) {
            return;
          }
          _cleanupSocket();
          if (!_intentionalDisconnect) {
            _scheduleReconnect(dbId, targetHwId);
          }
        },
        onDone: () {
          if (_connectionEpoch != currentEpoch || _webSocketChannel != channel) {
            return;
          }
          _cleanupSocket();
          if (!_intentionalDisconnect) {
            _scheduleReconnect(dbId, targetHwId);
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (_connectionEpoch == currentEpoch) {
        _isConnectingWebSocket = false;
        if (!_intentionalDisconnect) {
          _scheduleReconnect(dbId, targetHwId);
        }
      }
    }
  }

  void _scheduleReconnect(String dbId, String hwId) {
    if (_intentionalDisconnect) return;
    if (_selectedDeviceId != dbId) return; // Don't reconnect if the user switched devices
    if (_isReconnecting || _isConnectingWebSocket) return;
    if (_webSocketChannel != null) return; // Already has active websocket
    
    _isReconnecting = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      _isReconnecting = false;
      if (!_intentionalDisconnect && _selectedDeviceId == dbId && _webSocketChannel == null && !_isConnectingWebSocket) {
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
    final lowerKey = key.toLowerCase();
    if (lowerKey.startsWith('relay') || lowerKey.startsWith('channel') || lowerKey.startsWith('slot')) {
      final statusRegex = RegExp(r'[_]status$', caseSensitive: false);
      key = key.replaceAll(statusRegex, '');
    }
    key = key.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
    key = key.replaceAllMapped(RegExp(r'([a-zA-Z]+)(\d+)'), (m) => '${m[1]} ${m[2]}');
    key = key.replaceAll('_', ' ').trim();
    final cleanLower = rawKey.toLowerCase().replaceAll(' ', '_');
    if (cleanLower == 'ps' ||
        cleanLower == 'preserve_setting' ||
        cleanLower == 'preserve_state' ||
        cleanLower == 'preserve') {
      return 'PS';
    }
    if (cleanLower == 'pop' ||
        cleanLower == 'power_on_state' ||
        cleanLower == 'power_on_preserve' ||
        cleanLower == 'power_preserve') {
      return 'POP';
    }

    return key.split(' ').map((word) {
      if (word.isEmpty) return '';
      final wLower = word.toLowerCase();
      if (wLower == 'na') return 'NA';
      if (wLower == 'ac') return 'AC';
      if (wLower == 'dc') return 'DC';
      if (wLower == 'hw') return 'HW';
      if (wLower == 'sw') return 'SW';
      if (wLower == 'drs') return 'DRS';
      if (wLower == 'ps') return 'PS';
      if (wLower == 'pop') return 'POP';
      if (wLower.startsWith('na') && RegExp(r'^na\d+$', caseSensitive: false).hasMatch(word)) {
        return 'NA ${word.substring(2)}';
      }
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  @visibleForTesting
  void addDeviceReplyForTest(String dbId, String rawText) => _addDeviceReplyMessage(dbId, rawText);

  void _addDeviceReplyMessage(String dbId, String rawText) {
    final idx = _devices.indexWhere((d) => d.id == dbId || d.deviceId == dbId);
    if (idx == -1) return;
    
    final device = _devices[idx];
    final now = DateTime.now();
    _recentlyReceivedSignatures.removeWhere((_, time) => now.difference(time).inSeconds > 15);

    // Compute unique packet signature for rapid deduplication
    String sig = rawText.trim();
    try {
      final sanitized = rawText
          .replaceAll('“', '"')
          .replaceAll('”', '"')
          .replaceAll('‘', "'")
          .replaceAll('’', "'");
      final p = jsonDecode(sanitized);
      if (p is Map) {
        final pType = (p['type'] ?? p['command'] ?? '').toString().toUpperCase();
        if (pType == 'CLICKABLE' || p['command']?.toString().toLowerCase().contains('setting') == true) {
          sig = 'CLICKABLE_${jsonEncode(p['data'])}';
        } else if (pType == 'NUMERIC' || pType == 'HOLDING') {
          sig = 'NUMERIC_${jsonEncode(p['data'])}';
        } else if (pType == 'RADIO') {
          sig = 'RADIO_${jsonEncode(p['data'])}';
        } else if (p['data'] != null) {
          sig = '${pType}_${jsonEncode(p['data'])}';
        }
      }
    } catch (_) {}

    final sigKey = '${device.id}_$sig';
    if (_recentlyReceivedSignatures.containsKey(sigKey)) {
      final lastSeen = _recentlyReceivedSignatures[sigKey]!;
      if (now.difference(lastSeen).inMilliseconds.abs() < 400) {
        return; // Suppress only immediate loopback echo (< 400ms)
      }
    }
    _recentlyReceivedSignatures[sigKey] = now;

    String? textToShow;
    String? detectedType;
    String? socketMessageTitle;
    List<QuickCommand>? updatedCommands;
    
    bool shouldAddMessage = true;

    try {
      final sanitized = rawText
          .replaceAll('“', '"')
          .replaceAll('”', '"')
          .replaceAll('‘', "'")
          .replaceAll('’', "'");
      final parsed = jsonDecode(sanitized);
      if (parsed is Map) {
        final parsedCmd = parsed['command']?.toString().toLowerCase() ?? '';
        final parsedType = parsed['type']?.toString().toLowerCase() ?? '';
        if (parsedCmd == '/config' || parsedCmd == 'config' || parsedType == 'config') {
          return; // Never display configuration acks/echoes as chat replies
        }

        // 1. Locate the status payload map (use 'data', 'telemetry', 'status', 'payload' if nested, fallback to root)
        Map? dataMap;
        if (parsed.containsKey('data') && parsed['data'] is Map) {
          dataMap = parsed['data'];
        } else if (parsed.containsKey('telemetry') && parsed['telemetry'] is Map) {
          dataMap = parsed['telemetry'];
        } else if (parsed.containsKey('status') && parsed['status'] is Map) {
          dataMap = parsed['status'];
        } else if (parsed.containsKey('payload') && parsed['payload'] is Map) {
          dataMap = parsed['payload'];
        } else {
          dataMap = parsed;
        }

        List? dataList;
        if (parsed.containsKey('data') && parsed['data'] is List) {
          dataList = parsed['data'];
        } else if (parsed.containsKey('telemetry') && parsed['telemetry'] is List) {
          dataList = parsed['telemetry'];
        } else if (parsed.containsKey('tanks') && parsed['tanks'] is List) {
          dataList = parsed['tanks'];
        } else if (dataMap != null) {
          if (dataMap.containsKey('tanks') && dataMap['tanks'] is List) {
            dataList = dataMap['tanks'];
          } else if (dataMap.containsKey('telemetry') && dataMap['telemetry'] is List) {
            dataList = dataMap['telemetry'];
          } else if (dataMap.containsKey('data') && dataMap['data'] is List) {
            dataList = dataMap['data'];
          }
        }

        final List<String> lines = [];
        final configKeys = {
          'deviceid', 'firmwareversion', 'availablecommands', 'additionalcommands',
          'type', 'success', 'message', 'command', 'timestamp', 'id', 'version', 'lastseen'
        };

        final devId = device.deviceId.isNotEmpty ? device.deviceId : device.id;
        final savedConfig = getDeviceSavedConfig(devId);
        final Map<String, dynamic> telemetryDataToSave = {};
        final isWTDevice = _isWaterTank(device, device.model, device.name);

        if (dataList != null && dataList.isNotEmpty) {
          int chIdx = 1;
          for (final item in dataList) {
            if (item is Map) {
              final rawName = item['name'] ?? item['tank'] ?? item['label'] ?? item['tank_name'] ?? item['key'] ?? '';
              final rawVal = item['level'] ?? item['status'] ?? item['value'] ?? item['val'] ?? item['reading'] ?? item['percentage'] ?? '';
              if (rawName.toString().isNotEmpty) {
                final originalKey = _cleanKey(rawName.toString());
                final slotNumMatch = RegExp(r'\d+').firstMatch(rawName.toString());
                final slotNum = slotNumMatch?.group(0);
                final saved = (slotNum != null ? savedConfig['Relay $slotNum'] : null) ??
                    (slotNum != null ? savedConfig['relay $slotNum'] : null) ??
                    (slotNum != null ? savedConfig['Slot $slotNum'] : null) ??
                    (slotNum != null ? savedConfig['slot $slotNum'] : null) ??
                    (slotNum != null ? savedConfig['Channel $slotNum'] : null) ??
                    (slotNum != null ? savedConfig['channel $slotNum'] : null) ??
                    (slotNum != null ? savedConfig[slotNum] : null) ??
                    savedConfig[originalKey] ??
                    savedConfig['Relay $chIdx'] ??
                    savedConfig['Channel $chIdx'] ??
                    savedConfig[originalKey.toLowerCase()];
                final label = (saved != null && saved.toString().trim().isNotEmpty)
                    ? saved.toString().trim()
                    : (slotNum != null && RegExp(r'^\d+$').hasMatch(originalKey) ? 'Relay $slotNum' : originalKey);
                var displayVal = rawVal.toString().trim();
                if (RegExp(r'^\d+(\.\d+)?$').hasMatch(displayVal) &&
                    (item['unit'] == '%' || item['unit'] == 'percent' || item.containsKey('percentage') || originalKey.toLowerCase().contains('percentage') || originalKey.toLowerCase().contains('percent'))) {
                  displayVal = '$displayVal%';
                }
                lines.add('$label: $displayVal');
                telemetryDataToSave[originalKey] = displayVal;
              }
              chIdx++;
            }
          }
          if (lines.isNotEmpty) {
            textToShow = lines.join('\n');
          }
        } else if (dataMap != null) {
          final Map<String, dynamic> rawPreserved = _extractDataPreservingDuplicates(rawText, Map<String, dynamic>.from(dataMap));
          final effectiveMap = rawPreserved.isNotEmpty ? rawPreserved : dataMap;
          final keys = effectiveMap.keys.map((k) => k.toString()).toList();
          final filteredKeys = keys.where((k) => !configKeys.contains(k.toLowerCase())).toList();

          if (filteredKeys.isNotEmpty) {
            int chIdx = 1;
            for (final key in filteredKeys) {
              final itemVal = effectiveMap[key];
              String rawVal = '';
              if (itemVal is Map && itemVal.containsKey('value')) {
                final v = itemVal['value'];
                rawVal = v != null ? v.toString() : '';
              } else {
                rawVal = itemVal?.toString() ?? '';
              }
              final originalKey = _cleanKey(key);
              final slotNumMatch = RegExp(r'\d+').firstMatch(key);
              final slotNum = slotNumMatch?.group(0);
              final saved = (slotNum != null ? savedConfig['Relay $slotNum'] : null) ??
                  (slotNum != null ? savedConfig['relay $slotNum'] : null) ??
                  (slotNum != null ? savedConfig['Slot $slotNum'] : null) ??
                  (slotNum != null ? savedConfig['slot $slotNum'] : null) ??
                  (slotNum != null ? savedConfig['Channel $slotNum'] : null) ??
                  (slotNum != null ? savedConfig['channel $slotNum'] : null) ??
                  (slotNum != null ? savedConfig[slotNum] : null) ??
                  savedConfig[originalKey] ??
                  savedConfig['Relay $chIdx'] ??
                  savedConfig['Channel $chIdx'] ??
                  savedConfig[key] ??
                  savedConfig[key.toLowerCase()];
              final label = (saved != null && saved.toString().trim().isNotEmpty)
                  ? saved.toString().trim()
                  : (slotNum != null && RegExp(r'^\d+$').hasMatch(originalKey) ? 'Relay $slotNum' : originalKey);
              var displayVal = rawVal.trim();
              if (RegExp(r'^\d+(\.\d+)?$').hasMatch(displayVal) &&
                  (originalKey.toLowerCase().contains('percentage') || originalKey.toLowerCase().contains('percent'))) {
                displayVal = '$displayVal%';
              }
              lines.add('$label: $displayVal');
              telemetryDataToSave[originalKey] = displayVal;
              chIdx++;
            }

            textToShow = lines.join('\n');
          }
        }

        if (telemetryDataToSave.isNotEmpty) {
          final hwId = device.deviceId;
          final dbId = device.id;
          if (hwId.isNotEmpty) _latestDeviceStatusData[hwId] = telemetryDataToSave;
          if (dbId.isNotEmpty) _latestDeviceStatusData[dbId] = telemetryDataToSave;
          _saveLatestDeviceStatus(hwId, dbId, telemetryDataToSave);
        }

        final rawHw = parsed['hardwareVersion']?.toString() ??
            parsed['hardware_version']?.toString() ??
            parsed['hwVersion']?.toString() ??
            parsed['hardware']?.toString() ??
            (dataMap != null ? (dataMap['hardwareVersion']?.toString() ?? dataMap['hardware_version']?.toString()) : null);
        final rawSw = parsed['softwareVersion']?.toString() ??
            parsed['software_version']?.toString() ??
            parsed['firmwareVersion']?.toString() ??
            parsed['firmware_version']?.toString() ??
            parsed['version']?.toString() ??
            (dataMap != null ? (dataMap['softwareVersion']?.toString() ?? dataMap['software_version']?.toString() ?? dataMap['firmwareVersion']?.toString()) : null);
        final rawDevId = parsed['deviceId']?.toString() ??
            parsed['device_id']?.toString() ??
            (dataMap != null ? (dataMap['deviceId']?.toString() ?? dataMap['device_id']?.toString()) : null) ??
            (device.deviceId.isNotEmpty ? device.deviceId : device.id);

        final cmd = parsed['command']?.toString().toLowerCase() ?? '';
        detectedType = resolvePayloadType(parsed);
        final type = detectedType?.toLowerCase() ?? '';
        socketMessageTitle = (parsed['message'] != null && parsed['message'].toString().trim().isNotEmpty)
            ? parsed['message'].toString().trim()
            : (parsed['title'] != null && parsed['title'].toString().trim().isNotEmpty)
                ? parsed['title'].toString().trim()
                : null;
        final bool isAboutOrInfo = cmd == '/about' || cmd == '/info' || cmd == 'about' || cmd == 'info' || type == 'about' || type == 'info';

        if (isAboutOrInfo) {
          final effectiveHw = rawHw ?? device.hardwareVersion ?? '';
          final effectiveSw = rawSw ?? device.softwareVersion ?? '';
          textToShow = 'Device Id: $rawDevId\nHardware Version: $effectiveHw\nSoftware Version: $effectiveSw';
        } else if (type == 'time' && parsed['data'] is Map) {
          final Map timeMap = parsed['data'] as Map;
          final lines = <String>[];
          timeMap.forEach((k, v) {
            String label = k.toString().replaceAll('_', ' ').trim();
            label = label.split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '').join(' ');
            lines.add('$label: $v');
          });
          textToShow = lines.join('\n');
          shouldAddMessage = true;
        } else if ((type == 'cyclic' || type == 'cycle') && parsed['data'] is Map) {
          final Map cyclicMap = parsed['data'] as Map;
          final lines = <String>[];
          cyclicMap.forEach((k, v) {
            String label = k.toString().replaceAll('_', ' ').trim();
            label = label.split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '').join(' ');
            lines.add('$label: $v');
          });
          textToShow = lines.join('\n');
          shouldAddMessage = true;
        } else if (type == 'numeric' && parsed['data'] is Map) {
          parseNumericPayloadData(Map<String, dynamic>.from(parsed), device.deviceId, device.id);
          final Map numMap = parsed['data'] as Map;
          final lines = <String>[];
          numMap.forEach((k, v) {
            String label = _cleanKey(k.toString());
            if (v is Map) {
              final val = v['value']?.toString() ?? '';
              final range = v['range']?.toString();
              if (range != null && range.isNotEmpty) {
                lines.add('$label: $val [Range: $range]');
              } else {
                lines.add('$label: $val');
              }
            } else {
              lines.add('$label: $v');
            }
          });
          textToShow = lines.join('\n');
          shouldAddMessage = true;
        } else if (type == 'text' && parsed['data'] is Map) {
          parseTextPayloadData(Map<String, dynamic>.from(parsed), device.deviceId, device.id);
          final Map textMap = parsed['data'] as Map;
          final lines = <String>[];
          textMap.forEach((k, v) {
            final kStr = k.toString().trim();
            final vStr = v.toString().trim();
            lines.add('Slot $kStr: $vStr');
          });
          textToShow = lines.join('\n');
          shouldAddMessage = true;
        } else if (type == 'radio' && parsed['data'] is Map) {
          parseRadioPayloadData(Map<String, dynamic>.from(parsed), device.deviceId, device.id);
          // Dynamic RADIO response: render all fields from backend data, no hardcoding
          final Map radioMap = parsed['data'] as Map;
          final lines = <String>[];
          radioMap.forEach((k, v) {
            String label = _cleanKey(k.toString());
            final rawVal = (v is Map) ? (v['value']?.toString() ?? '0') : v?.toString() ?? '0';
            final dispVal = (rawVal == '1' || rawVal.toString().toLowerCase() == 'on') ? '1' : '0';
            lines.add('$label: $dispVal');
          });
          textToShow = lines.join('\n');
          shouldAddMessage = true;
        } else if (type == 'response' && parsed['data'] is Map && (textToShow == null || textToShow.isEmpty)) {
          // Dynamic RESPONSE type: flat key-value telemetry from backend (Zero hardcoding)
          // e.g. {"type":"RESPONSE","data":{"ac_voltage":"230.5 V","motor_status":"Running",...}}
          final Map responseMap = parsed['data'] as Map;
          final lines = <String>[];
          responseMap.forEach((k, v) {
            final kStr = k.toString().trim();
            // Skip any control/command keys
            if (configKeys.contains(kStr.toLowerCase())) return;
            String label = _cleanKey(kStr);
            String valStr = '';
            if (v is Map) {
              valStr = v['value']?.toString() ?? '';
            } else {
              valStr = v?.toString() ?? '';
            }
            lines.add('$label: $valStr');
          });
          if (lines.isNotEmpty) {
            textToShow = lines.join('\n');
            shouldAddMessage = true;
          }
        } else if (type == 'clickable') {
          // Dynamic CLICKABLE type: each item in data array becomes a tappable hyperlink
          // e.g. {"type": "CLICKABLE", "data": ["set_timing_1", "set_timing_2", ...]}
          // Encode as special prefix so UI can detect and render clickable chips.
          final dynamic rawData = parsed['data'];
          if (rawData is List) {
            final items = rawData.map((e) {
              if (e is Map) return e;
              return e.toString().trim();
            }).toList();
            textToShow = '__CLICKABLE__:${jsonEncode(items)}';
            shouldAddMessage = true;
          } else if (rawData is Map) {
            textToShow = '__CLICKABLE__:${jsonEncode(rawData)}';
            shouldAddMessage = true;
          }
        } else if (textToShow == null || textToShow.isEmpty) {
          if (type == 'connected' || type == 'device_online' || parsed.containsKey('availableCommands')) {
            shouldAddMessage = false;
          } else if (parsed.containsKey('message') && parsed['message'] != null && parsed['message'].toString().trim().isNotEmpty) {
            textToShow = parsed['message'].toString().trim();
          } else if (parsed.containsKey('status') && parsed['status'] is String && parsed['status'].toString().trim().isNotEmpty) {
            textToShow = parsed['status'].toString().trim();
          } else if (type == 'status') {
            textToShow = 'Status: Online • Ready';
          }
        }
        
        // 2. Dynamically extract quick action commands to refill Quick Commands section (NOT in chat bubble)
        dynamic rawCmds = parsed['availableCommands'] ??
            parsed['available_commands'] ??
            parsed['additionalCommands'] ??
            parsed['commands'] ??
            parsed['commandList'] ??
            parsed['command_list'] ??
            parsed['actions'] ??
            parsed['supportedCommands'] ??
            parsed['supported_commands'];
        if (rawCmds == null && dataMap != null) {
          rawCmds = dataMap['availableCommands'] ??
              dataMap['available_commands'] ??
              dataMap['additionalCommands'] ??
              dataMap['commands'] ??
              dataMap['commandList'] ??
              dataMap['command_list'] ??
              dataMap['actions'] ??
              dataMap['supportedCommands'] ??
              dataMap['supported_commands'];
        }
        if (rawCmds != null) {
          final parsedCommands = _parseIncomingCommands(rawCmds, device.deviceId, device.id);
          if (parsedCommands.isNotEmpty) {
            updatedCommands = parsedCommands;
            _deviceQuickCommands[device.deviceId] = parsedCommands;
            _deviceQuickCommands[device.id] = parsedCommands;
          }
        }
      }
    } catch (_) {}

    // Fallback if not matching relay status but is standard text/JSON
    if (textToShow == null || textToShow.isEmpty) {
      final trimmed = rawText.trim();
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        try {
          final p = jsonDecode(trimmed);
          if (p is Map) {
            if (p['message'] != null && p['message'].toString().trim().isNotEmpty) {
              textToShow = p['message'].toString().trim();
            } else if (p['status'] != null && p['status'] is String) {
              textToShow = p['status'].toString().trim();
            } else {
              textToShow = 'Status: Online • Ready';
            }
          }
        } catch (_) {
          textToShow = 'Status: Online • Ready';
        }
      } else {
        textToShow = rawText;
      }
    }

    final String finalText = (textToShow != null && textToShow.isNotEmpty) ? textToShow : rawText;

    var updatedDevice = device;
    if (updatedCommands != null) {
      updatedDevice = updatedDevice.copyWith(
        quickCommands: updatedCommands,
      );
    }

    if (shouldAddMessage) {
      final now = DateTime.now();
      // Only suppress immediate loopback echo (< 400ms) with exact text match
      final recentDeviceMessages = updatedDevice.messages
          .where((m) => !m.isUser && now.difference(m.timestamp).inMilliseconds.abs() < 2000)
          .toList();

      for (final prevMsg in recentDeviceMessages.reversed) {
        if (prevMsg.text.trim() == finalText.trim() &&
            now.difference(prevMsg.timestamp).inMilliseconds.abs() < 400) {
          return; // Duplicate identical payload loopback within 400ms
        }
      }

      final replyMsg = ChatMessage(
        id: 'ws_reply_${DateTime.now().millisecondsSinceEpoch}',
        text: finalText,
        title: socketMessageTitle,
        command: detectedType?.toUpperCase(),
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
    _connectedHardwareId = null;
    _isConnectingWebSocket = false;
    _webSocketSubscription?.cancel();
    _webSocketSubscription = null;
    try {
      _webSocketChannel?.sink.close();
    } catch (_) {}
    _webSocketChannel = null;
  }

  
  void reconnectCurrentDevice() {
    if (_selectedDeviceId == null) return;
    final index = _devices.indexWhere((d) => d.id == _selectedDeviceId);
    if (index != -1) {
      final dev = _devices[index];
      _disconnectWebSocket();
      _connectWebSocket(dev.id, dev.deviceId);
    }
  }

  void _disconnectWebSocket() {
    _connectionEpoch++;
    _intentionalDisconnect = true;
    _connectedHardwareId = null;
    _isConnectingWebSocket = false;
    _isReconnecting = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    _webSocketSubscription?.cancel();
    _webSocketSubscription = null;
    try {
      _webSocketChannel?.sink.close();
    } catch (_) {}
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

