enum MessageSender { user, device }

class ChatMessage {
  final String id;
  final String text;
  final MessageSender sender;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
  });

  bool get isUser => sender == MessageSender.user;

  String get formattedTime {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class QuickCommand {
  final String label;
  final String message;

  const QuickCommand({
    required this.label,
    required this.message,
  });
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
  final String deviceId; // Hardware public ID (e.g. IONET001)
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

  const Device({
    required this.id,
    required this.deviceId,
    required this.name,
    required this.statusMessage,
    required this.lastActiveTime,
    this.isOnline = true,
    this.unreadCount = 0,
    this.quickCommands = const [
      QuickCommand(label: 'Info', message: 'Info'),
    ],
    this.messages = const [],
    this.imageUrl,
    this.isShared = false,
    this.sharedUsers = const [],
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
    );
  }
}
