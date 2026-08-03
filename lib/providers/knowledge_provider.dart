import 'package:flutter/foundation.dart';
import '../models/channel_model.dart';
import '../services/api_service.dart';

class KnowledgeProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final List<Channel> _channels = [];
  final Set<String> _followedChannelIds = {};
  String? _selectedChannelId;
  bool _isLoading = false;

  List<Channel> get channels => _channels;
  Set<String> get followedChannelIds => _followedChannelIds;
  String? get selectedChannelId => _selectedChannelId;
  bool get isLoading => _isLoading;

  Channel? get selectedChannel {
    if (_selectedChannelId == null) return null;
    try {
      return _channels.firstWhere((c) => c.id == _selectedChannelId);
    } catch (_) {
      return null;
    }
  }

  bool isFollowing(String id) => _followedChannelIds.contains(id);

  void toggleFollow(String id) {
    if (_followedChannelIds.contains(id)) {
      _followedChannelIds.remove(id);
    } else {
      _followedChannelIds.add(id);
    }
    notifyListeners();
  }

  void selectChannel(String? id) {
    _selectedChannelId = id;
    notifyListeners();
  }

  /// Fetch public resources/announcements channels from backend API
  Future<bool> fetchChannels(String token) async {
    _isLoading = true;
    notifyListeners();

    final rawChannels = await _apiService.getChannels(token);
    _isLoading = false;

    if (rawChannels != null) {
      _channels.clear();
      for (final raw in rawChannels) {
        final channelId = raw['id']?.toString() ?? raw['_id']?.toString() ?? '';
        final channelName = raw['channelName']?.toString() ?? 'Support Channel';
        final topicsList = raw['topics'] as List? ?? [];

        final resources = topicsList.map((t) {
          final topicName = t['topicName']?.toString() ?? 'Topic Details';
          final link = t['link']?.toString() ?? '';
          
          String type = 'connection';
          if (link.toLowerCase().contains('youtube.com') || link.toLowerCase().contains('youtu.be')) {
            type = 'youtube';
          } else if (link.toLowerCase().contains('.pdf')) {
            type = 'pdf';
          }
          
          return ChannelResource(
            title: topicName,
            type: type,
            url: link,
          );
        }).toList();

        _channels.add(
          Channel(
            id: channelId,
            name: channelName,
            followers: 'Public Channel',
            description: 'Guides and community resources for $channelName setups.',
            resources: resources,
          ),
        );
      }
      

      notifyListeners();
      return true;
    }
    notifyListeners();
    return false;
  }
}
