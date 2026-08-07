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

  Future<String?> toggleFollow(String id, String token) async {
    final isCurrentlyFollowing = _followedChannelIds.contains(id);
    
    // Optimistic UI update
    if (isCurrentlyFollowing) {
      _followedChannelIds.remove(id);
    } else {
      _followedChannelIds.add(id);
    }
    notifyListeners();

    String? error;
    if (isCurrentlyFollowing) {
      error = await _apiService.unfollowChannel(token: token, channelId: id);
    } else {
      error = await _apiService.followChannel(token: token, channelId: id);
    }

    // Revert on failure
    if (error != null) {
      if (isCurrentlyFollowing) {
        _followedChannelIds.add(id);
      } else {
        _followedChannelIds.remove(id);
      }
      notifyListeners();
    }
    return error;
  }

  void selectChannel(String? id) {
    _selectedChannelId = id;
    notifyListeners();
  }

  /// Fetch public resources/announcements channels from backend API
  Future<bool> fetchChannels(String token) async {
    _isLoading = true;
    notifyListeners();

    final results = await Future.wait([
      _apiService.getChannels(token),
      _apiService.getSubscribedChannels(token),
    ]);

    final rawChannels = results[0] as List<Map<String, dynamic>>?;
    final subscribedIds = results[1] as List<String>?;

    _isLoading = false;

    if (subscribedIds != null) {
      _followedChannelIds.clear();
      _followedChannelIds.addAll(subscribedIds);
    }

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
