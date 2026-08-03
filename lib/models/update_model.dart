import '../config/api_config.dart';

class SystemUpdate {
  final String id;
  final String title;
  final String description;
  final List<String> fileUrls;
  final DateTime timestamp;

  SystemUpdate({
    required this.id,
    required this.title,
    required this.description,
    required this.fileUrls,
    required this.timestamp,
  });

  factory SystemUpdate.fromJson(Map<String, dynamic> json) {
    final mediaList = json['mediaUrls'] ?? json['files'] ?? [];
    final urls = <String>[];
    if (mediaList is List) {
      for (final f in mediaList) {
        if (f != null) {
          String url = f.toString();
          if (url.startsWith('/')) {
            url = '${ApiConfig.baseUrl}$url';
          }
          urls.add(url);
        }
      }
    }

    return SystemUpdate(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      fileUrls: urls,
      timestamp: DateTime.tryParse(json['createdAt']?.toString() ?? json['timestamp']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
