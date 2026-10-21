enum MessageSender { user, device }

class ChatMessage {
  final String id;
  final String text;
  final String? title;
  final String? command;
  final MessageSender sender;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.text,
    this.title,
    this.command,
    required this.sender,
    required this.timestamp,
  });

  bool get isUser => sender == MessageSender.user;

  String get formattedTime {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  ChatMessage copyWith({
    String? id,
    String? text,
    String? title,
    String? command,
    MessageSender? sender,
    DateTime? timestamp,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      title: title ?? this.title,
      command: command ?? this.command,
      sender: sender ?? this.sender,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

class QuickCommand {
  final String label;
  final String message;
  final String? type;
  final bool isCustom;
  final bool isSlider;
  final double minValue;
  final double maxValue;
  final double step;
  final double? value;

  const QuickCommand({
    required this.label,
    required this.message,
    this.type,
    this.isCustom = false,
    this.isSlider = false,
    this.minValue = 0.0,
    this.maxValue = 100.0,
    this.step = 1.0,
    this.value,
  });

  bool get isTimeType {
    final t = (type ?? '').toLowerCase().trim();
    if (t == 'time') return true;
    if (t == 'cyclic' || t == 'cycle') return false;
    final lower = '$message $label'.toLowerCase();
    if (lower.contains('cyclic') || lower.contains('cycle')) return false;
    return lower.contains('time') || lower.contains('schedule') || lower.contains('timer') || lower.contains('timing');
  }

  bool get isCyclicType {
    final t = (type ?? '').toLowerCase().trim();
    if (t == 'cyclic' || t == 'cycle') return true;
    final lower = '$message $label'.toLowerCase();
    return lower.contains('cyclic') || lower.contains('cycle');
  }

  bool get isNumericType {
    final t = (type ?? '').toLowerCase().trim();
    return t == 'numeric';
  }

  QuickCommand copyWith({
    String? label,
    String? message,
    String? type,
    bool? isCustom,
    bool? isSlider,
    double? minValue,
    double? maxValue,
    double? step,
    double? value,
  }) {
    return QuickCommand(
      label: label ?? this.label,
      message: message ?? this.message,
      type: type ?? this.type,
      isCustom: isCustom ?? this.isCustom,
      isSlider: isSlider ?? this.isSlider,
      minValue: minValue ?? this.minValue,
      maxValue: maxValue ?? this.maxValue,
      step: step ?? this.step,
      value: value ?? this.value,
    );
  }

  Map<String, dynamic> toJson() => {
    'label': label,
    'message': message,
    if (type != null) 'type': type,
    'isCustom': isCustom,
    'isSlider': isSlider,
    'minValue': minValue,
    'maxValue': maxValue,
    'step': step,
    if (value != null) 'value': value,
  };

  static bool detectIsSlider(String message, String label) {
    final lower = '$message $label'.toLowerCase();
    return lower.contains('slider') ||
        lower.contains('level') ||
        lower.contains('threshold') ||
        lower.contains('pwm');
  }

  factory QuickCommand.fromJson(Map<String, dynamic> json) {
    final rawType = json['type']?.toString().toLowerCase().trim();
    return QuickCommand(
      label: json['label'] as String? ?? json['description'] as String? ?? json['title'] as String? ?? '',
      message: json['message'] as String? ?? json['command'] as String? ?? '',
      type: json['type'] as String?,
      isCustom: json['isCustom'] as bool? ?? false,
      isSlider: json['isSlider'] as bool? ??
          (rawType == 'slider' ||
              detectIsSlider(
                json['message']?.toString() ?? json['command']?.toString() ?? '',
                json['label']?.toString() ?? json['description']?.toString() ?? '',
              )),
      minValue: (json['minValue'] as num?)?.toDouble() ?? (json['min'] as num?)?.toDouble() ?? 0.0,
      maxValue: (json['maxValue'] as num?)?.toDouble() ?? (json['max'] as num?)?.toDouble() ?? 100.0,
      step: (json['step'] as num?)?.toDouble() ?? 1.0,
      value: (json['value'] as num?)?.toDouble(),
    );
  }
}

class SharedUser {
  final String id;
  final String name;
  final String email;

  const SharedUser({
    required this.id,
    required this.name,
    required this.email,
  });

  factory SharedUser.fromJson(Map<String, dynamic> json) {
    return SharedUser(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
    );
  }
}

class Device {
  final String id; // Database internal ID
  final String deviceId; // Hardware unique ID
  final String name;
  final String statusMessage;
  final String lastActiveTime;
  final bool isOnline;
  final int unreadCount;
  final List<QuickCommand> quickCommands;
  final List<ChatMessage> messages;
  final String? imageUrl;
  final bool isShared;
  final List<SharedUser> sharedUsers;
  final String? model; // Device model received from backend (e.g. SC, WT)
  final String? hardwareVersion;
  final String? softwareVersion;
  final String? ownerName;
  final String? ownerEmail;

  const Device({
    required this.id,
    required this.deviceId,
    required this.name,
    required this.statusMessage,
    required this.lastActiveTime,
    this.isOnline = true,
    this.unreadCount = 0,
    this.quickCommands = const [],
    this.messages = const [],
    this.imageUrl,
    this.isShared = false,
    this.sharedUsers = const [],
    this.model,
    this.hardwareVersion,
    this.softwareVersion,
    this.ownerName,
    this.ownerEmail,
  });

  Device copyWith({
    String? id,
    String? deviceId,
    String? name,
    String? statusMessage,
    String? lastActiveTime,
    bool? isOnline,
    int? unreadCount,
    List<QuickCommand>? quickCommands,
    List<ChatMessage>? messages,
    String? imageUrl,
    bool? isShared,
    List<SharedUser>? sharedUsers,
    String? model,
    String? hardwareVersion,
    String? softwareVersion,
    String? ownerName,
    String? ownerEmail,
    bool clearImage = false,
  }) {
    return Device(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      name: name ?? this.name,
      statusMessage: statusMessage ?? this.statusMessage,
      lastActiveTime: lastActiveTime ?? this.lastActiveTime,
      isOnline: isOnline ?? this.isOnline,
      unreadCount: unreadCount ?? this.unreadCount,
      quickCommands: quickCommands ?? this.quickCommands,
      messages: messages ?? this.messages,
      imageUrl: clearImage ? null : (imageUrl ?? this.imageUrl),
      isShared: isShared ?? this.isShared,
      sharedUsers: sharedUsers ?? this.sharedUsers,
      model: model ?? this.model,
      hardwareVersion: hardwareVersion ?? this.hardwareVersion,
      softwareVersion: softwareVersion ?? this.softwareVersion,
      ownerName: ownerName ?? this.ownerName,
      ownerEmail: ownerEmail ?? this.ownerEmail,
    );
  }
}

class NumericSetting {
  final String key;
  final String label;
  final dynamic value;
  final String range;
  final double minValue;
  final double maxValue;
  final String unit;

  const NumericSetting({
    required this.key,
    required this.label,
    required this.value,
    required this.range,
    required this.minValue,
    required this.maxValue,
    this.unit = '',
  });

  bool get isBinary => (minValue == 0.0 && maxValue == 1.0) || range.trim() == '0 - 1';

  static NumericSetting? fromMap(String key, dynamic data, {String? parentMessage}) {
    dynamic rawVal;
    String rawRange = '';
    if (data is Map) {
      rawVal = data['value'];
      rawRange = data['range']?.toString() ?? '';
    } else {
      rawVal = data;
    }

    double minVal = 0.0;
    double maxVal = 100.0;
    final rangeMatch = RegExp(r'([0-9.]+)\s*-\s*([0-9.]+)').firstMatch(rawRange);
    if (rangeMatch != null) {
      minVal = double.tryParse(rangeMatch.group(1)!) ?? 0.0;
      maxVal = double.tryParse(rangeMatch.group(2)!) ?? 100.0;
    } else {
      final kLow = key.toLowerCase();
      if (kLow.contains('time') || kLow.contains('timer') || kLow.contains('delay')) {
        maxVal = 999.0;
      }
    }

    String unit = '';
    if (rawVal is String && rawVal.isNotEmpty) {
      final unitMatch = RegExp(r'[0-9.]+\s*([a-zA-Z%]+)').firstMatch(rawVal);
      if (unitMatch != null) {
        unit = unitMatch.group(1)!.trim();
      }
    }
    if (unit.isEmpty) {
      final checkStr = '${key.toLowerCase()} ${parentMessage?.toLowerCase() ?? ''}';
      if (checkStr.contains('minute') || checkStr.contains('min')) {
        unit = 'min';
      } else if (checkStr.contains('second') || checkStr.contains('sec')) {
        unit = 'sec';
      } else if (checkStr.contains('hour') || checkStr.contains('hr')) {
        unit = 'hr';
      }
    }

    String label = key.replaceAll('_', ' ').trim();
    label = label.split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '').join(' ');

    return NumericSetting(
      key: key,
      label: label,
      value: rawVal,
      range: rawRange.isNotEmpty ? rawRange : '${minVal.toInt()} - ${maxVal.toInt()}',
      minValue: minVal,
      maxValue: maxVal,
      unit: unit,
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'label': label,
    'value': value,
    'range': range,
    'minValue': minValue,
    'maxValue': maxValue,
    'unit': unit,
  };
}

class TextSetting {
  final String key;
  final String value;
  final String range;
  final int minLength;
  final int maxLength;

  const TextSetting({
    required this.key,
    required this.value,
    required this.range,
    required this.minLength,
    required this.maxLength,
  });

  static TextSetting fromData(String key, dynamic val, [String? fallbackRange]) {
    String textVal = '';
    String rangeStr = fallbackRange ?? '';

    if (val is Map) {
      textVal = val['value']?.toString() ?? '';
      if (val['range'] != null) {
        rangeStr = val['range'].toString();
      }
    } else {
      textVal = val?.toString() ?? '';
    }

    int minL = 1;
    int maxL = 20;
    if (rangeStr.isNotEmpty) {
      final match = RegExp(r'([0-9]+)\s*-\s*([0-9]+)').firstMatch(rangeStr);
      if (match != null) {
        minL = int.tryParse(match.group(1)!) ?? minL;
        maxL = int.tryParse(match.group(2)!) ?? maxL;
      }
    }

    return TextSetting(
      key: key,
      value: textVal,
      range: rangeStr,
      minLength: minL,
      maxLength: maxL,
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'value': value,
    'range': range,
    'minLength': minLength,
    'maxLength': maxLength,
  };
}

/// Model for backend RADIO type response.
/// e.g. {"type": "RADIO", "data": {"PS": "0", "POP": "0"}}
/// Options are dynamically driven by backend; for Preserve Setting (PS), defaults to ["0", "1", "2"].
class RadioSetting {
  final String key;
  final String label;
  final String value; // current value from backend ("0", "1", "2", etc.)
  final List<String> options; // allowed options from backend

  const RadioSetting({
    required this.key,
    required this.label,
    required this.value,
    required this.options,
  });

  bool get isOn => value == '1' || value.toLowerCase() == 'on';

  /// Parse from a single RADIO data entry.
  /// [key] is the field name, [val] is the raw value,
  /// [allowedOptions] is the list of allowed options — comes from backend.
  static RadioSetting fromData(String key, dynamic val, [List<String>? allowedOptions]) {
    final rawVal = val?.toString().trim() ?? '0';
    final kLower = key.toLowerCase().replaceAll(' ', '_');
    final isPreserveSetting = kLower == 'ps' ||
        kLower == 'preserve_setting' ||
        kLower == 'preserve_state' ||
        kLower == 'preserve';
    final isPowerOnState = kLower == 'pop' ||
        kLower == 'power_on_state' ||
        kLower == 'power_on_preserve' ||
        kLower == 'power_preserve';

    List<String> opts = allowedOptions != null && allowedOptions.isNotEmpty
        ? List<String>.from(allowedOptions)
        : const ['0', '1'];

    String label;
    if (isPreserveSetting) {
      label = 'PS';
    } else if (isPowerOnState) {
      label = 'POP';
    } else {
      label = key.replaceAll('_', ' ').trim();
      label = label.split(' ')
          .map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '')
          .join(' ');
    }

    return RadioSetting(
      key: key,
      label: label,
      value: rawVal,
      options: opts,
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'label': label,
    'value': value,
    'options': options,
  };
}

