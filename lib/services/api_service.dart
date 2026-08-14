import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/api_config.dart';

class ApiService {
  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  /// POST /api/v1/auth/request-otp
  /// Sends OTP code to user's email.
  Future<bool> requestOtp(String email) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/auth/request-otp');
    try {
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// POST /api/v1/auth/verify-otp
  /// Verifies OTP code. Returns response map data block containing token & profile status if successful.
  Future<Map<String, dynamic>?> verifyOtp(String email, String code) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/auth/verify-otp');
    try {
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'otp': code,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        if (body is Map && body['success'] == true) {
          return Map<String, dynamic>.from(body['data'] ?? {});
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// GET /api/v1/users/me
  /// Fetches current user profile. Returns null if profile is not created yet (404/400) or fails.
  Future<Map<String, dynamic>?> getUserMe(String token) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/users/me');
    try {
      final response = await _client.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is Map) {
          if (body.containsKey('data') && body['data'] is Map) {
            return Map<String, dynamic>.from(body['data']);
          }
          return Map<String, dynamic>.from(body);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// POST /api/v1/users/profile
  /// Creates user profile for onboarding.
  Future<bool> createProfile({
    required String token,
    required String name,
    required String phoneNumber,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/users/profile');
    try {
      final response = await _client.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'phoneNumber': phoneNumber,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// GET /api/v1/devices
  /// Retrieves list of registered user devices (optionally filtered by type OWNER or SHARED).
  Future<List<Map<String, dynamic>>?> getDevices(String token, {String? type}) async {
    final uriStr = type != null 
        ? '${ApiConfig.baseUrl}/api/v1/devices?type=$type'
        : '${ApiConfig.baseUrl}/api/v1/devices';
    final url = Uri.parse(uriStr);
    try {
      final response = await _client.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is Map && body['success'] == true && body['data'] is List) {
          return List<Map<String, dynamic>>.from(body['data']);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// GET /api/v1/devices/{deviceId}
  /// Retrieves details of a single device by ID.
  Future<Map<String, dynamic>?> getDeviceById({
    required String token,
    required String deviceId,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/devices/$deviceId');
    try {
      final response = await _client.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is Map && body['success'] == true && body['data'] is Map) {
          return Map<String, dynamic>.from(body['data']);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// POST /api/v1/devices
  /// Registers a new device. Returns null on success, or error message on failure.
  Future<String?> createDevice({
    required String token,
    required String deviceId,
    required String deviceName,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/devices');
    try {
      final response = await _client.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'deviceId': deviceId,
          'deviceName': deviceName,
        }),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (body is Map && body['success'] == true) {
          return null;
        }
      }
      if (body is Map && body.containsKey('message')) {
        return body['message']?.toString();
      }
      return 'Failed to add device';
    } catch (_) {
      return 'Connection error occurred';
    }
  }



  /// DELETE /api/v1/devices/{deviceId}
  /// Deletes/unregisters a device.
  Future<bool> deleteDevice({
    required String token,
    required String deviceId,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/devices/$deviceId');
    try {
      final response = await _client.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// PUT /api/v1/devices/{deviceId}
  /// Updates name of device.
  Future<bool> updateDeviceName({
    required String token,
    required String deviceId,
    required String deviceName,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/devices/$deviceId');
    try {
      final response = await _client.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'deviceName': deviceName,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// GET /api/v1/updates
  /// Retrieves general announcement updates.
  Future<List<Map<String, dynamic>>?> getUpdates() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/updates');
    try {
      final response = await _client.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is Map && body['success'] == true && body['data'] is List) {
          return List<Map<String, dynamic>>.from(body['data']);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// PUT /api/v1/users/profile
  /// Updates user profile details (name and phoneNumber).
  Future<bool> editProfile({
    required String token,
    required String name,
    required String phoneNumber,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/users/profile');
    try {
      final response = await _client.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'phoneNumber': phoneNumber,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// DELETE /api/v1/users/me
  /// Deactivates current user account.
  Future<bool> deactivateAccount({required String token}) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/users/me');
    try {
      final response = await _client.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// GET /api/v1/channels
  /// Retrieves list of all public guides and resource channels.
  Future<List<Map<String, dynamic>>?> getChannels(String token) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/channels');
    try {
      final response = await _client.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is Map && body['success'] == true && body['data'] is List) {
          return List<Map<String, dynamic>>.from(body['data']);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// GET /api/v1/users/subscribed-channels
  /// Retrieves list of subscribed channels.
  Future<List<String>?> getSubscribedChannels(String token) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/users/subscribed-channels');
    try {
      final response = await _client.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is Map && body['success'] == true && body['data'] is List) {
          final data = body['data'] as List;
          final List<String> ids = [];
          for (var item in data) {
            if (item is String) {
              ids.add(item);
            } else if (item is Map) {
              final id = item['id']?.toString() ?? item['_id']?.toString();
              if (id != null) ids.add(id);
            }
          }
          return ids;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }


  MediaType _resolveMediaType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) {
      return MediaType('image', 'png');
    } else if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return MediaType('image', 'jpeg');
    } else if (lower.endsWith('.gif')) {
      return MediaType('image', 'gif');
    } else if (lower.endsWith('.webp')) {
      return MediaType('image', 'webp');
    } else if (lower.endsWith('.svg')) {
      return MediaType('image', 'svg+xml');
    } else if (lower.endsWith('.bmp')) {
      return MediaType('image', 'bmp');
    }
    return MediaType('application', 'octet-stream');
  }

  /// POST /api/v1/users/profile-picture
  /// Uploads user avatar image file.
  Future<String?> uploadProfileAvatar({
    required String token,
    required List<int> fileBytes,
    required String filename,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/users/profile-picture');
    try {
      final request = http.MultipartRequest('POST', url)
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            fileBytes,
            filename: filename,
            contentType: _resolveMediaType(filename),
          ),
        );
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        if (body is Map && body['success'] == true && body['data'] != null) {
          return body['data']['profilePictureUrl']?.toString() ??
              body['data']['profilePicture']?.toString() ??
              '';
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// DELETE /api/v1/users/profile-picture
  /// Removes user avatar image.
  Future<bool> deleteProfileAvatar({required String token}) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/users/profile-picture');
    try {
      final response = await _client.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        final body = jsonDecode(response.body);
        if (body is Map && body['success'] == true) {
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// POST /api/v1/devices/{deviceId}/image
  /// Uploads device image avatar.
  Future<bool> uploadDeviceImage({
    required String token,
    required String deviceId,
    required List<int> fileBytes,
    required String filename,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/devices/$deviceId/image');
    try {
      final request = http.MultipartRequest('POST', url)
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            fileBytes,
            filename: filename,
            contentType: _resolveMediaType(filename),
          ),
        );
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  /// DELETE /api/v1/devices/{deviceId}/image
  /// Deletes device image avatar.
  Future<bool> deleteDeviceImage({
    required String token,
    required String deviceId,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/devices/$deviceId/image');
    try {
      final response = await _client.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  /// POST /api/v1/devices/{deviceId}/share
  /// Shares device control with target user ID.
  Future<String?> shareDevice({
    required String token,
    required String deviceId,
    required String targetUserId,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/devices/$deviceId/share');
    try {
      final response = await _client.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'userId': targetUserId}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        if (body is Map && body['success'] == true) {
          return null; // Success
        }
      }
      
      // Parse error message if available
      try {
        final body = jsonDecode(response.body);
        if (body is Map) {
          if (body['message'] != null) return body['message'].toString();
          if (body['error'] != null) return body['error'].toString();
          return response.body;
        }
      } catch (_) {}

      return response.body.isNotEmpty ? response.body : 'Failed to share device. Server returned ${response.statusCode}.';
    } catch (e) {
      return 'An error occurred while connecting to the server.';
    }
  }

  /// DELETE /api/v1/devices/{deviceId}/share/{userId}
  /// Removes device control share permissions from target user.
  Future<bool> unshareDevice({
    required String token,
    required String deviceId,
    required String targetUserId,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/devices/$deviceId/share/$targetUserId');
    try {
      final response = await _client.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// GET /api/v1/users/search
  /// Searches for registered users by email or username.
  Future<List<Map<String, dynamic>>?> searchUsers({
    required String token,
    required String query,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/users/search?query=$query');
    try {
      final response = await _client.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is Map && body['success'] == true && body['data'] is List) {
          return List<Map<String, dynamic>>.from(body['data']);
        } else if (body is Map && body['data'] is List) {
          return List<Map<String, dynamic>>.from(body['data']);
        } else if (body is List) {
          return List<Map<String, dynamic>>.from(body);
        } else if (body is Map && body['users'] is List) {
          return List<Map<String, dynamic>>.from(body['users']);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// DELETE /api/v1/devices/{deviceId}/share
  /// Removes control share permissions of the current logged-in shared user.
  Future<bool> unshareDeviceBySharedUser({
    required String token,
    required String deviceId,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/devices/$deviceId/share');
    try {
      final response = await _client.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  // ==========================================
  // CHANNEL APIs
  // ==========================================

  /// POST /api/v1/admin/channels
  /// Create a new channel.
  Future<Map<String, dynamic>?> createChannel({
    required String token,
    required String channelName,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/channels');
    try {
      final response = await _client.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'channelName': channelName,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// GET /api/v1/channels
  /// Get all channels.
  Future<List<dynamic>?> getAllChannels() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/channels');
    try {
      final response = await _client.get(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is List) return body;
        if (body is Map && body['data'] is List) return body['data'];
        return [body];
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// GET /api/v1/channels/{channel_id}
  /// Get Channel By ID.
  Future<Map<String, dynamic>?> getChannelById({
    required String channelId,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/channels/$channelId');
    try {
      final response = await _client.get(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// PATCH /api/v1/admin/channels/{channel_id}/topics
  /// Add Topic to Channel By Channel ID.
  Future<Map<String, dynamic>?> addTopicToChannel({
    required String token,
    required String channelId,
    required String topicName,
    required String link,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/channels/$channelId/topics');
    try {
      final response = await _client.patch(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'topicName': topicName,
          'link': link,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// PUT /api/v1/admin/channels/{channel_id}/topics/{topic_id}
  /// Update topics from channel.
  Future<Map<String, dynamic>?> updateTopic({
    required String token,
    required String channelId,
    required String topicId,
    required String topicName,
    required String link,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/channels/$channelId/topics/$topicId');
    try {
      final response = await _client.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'topicName': topicName,
          'link': link,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// PUT /api/v1/admin/channels/{channel_id}
  /// Update Channel Name.
  Future<Map<String, dynamic>?> updateChannelName({
    required String token,
    required String channelId,
    required String channelName,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/channels/$channelId');
    try {
      final response = await _client.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'channelName': channelName,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// DELETE /api/v1/admin/channels/{channel_id}/topics/{topic_id}
  /// Delete Topic from Channel.
  Future<bool> deleteTopic({
    required String token,
    required String channelId,
    required String topicId,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/channels/$channelId/topics/$topicId');
    try {
      final response = await _client.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// DELETE /api/v1/admin/channels/{channel_id}
  /// Delete Channel.
  Future<bool> deleteChannel({
    required String token,
    required String channelId,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/admin/channels/$channelId');
    try {
      final response = await _client.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// POST /api/v1/users/channels/{channelId}/follow
  /// Follow a channel
  Future<String?> followChannel({
    required String token,
    required String channelId,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/users/channels/$channelId/follow');
    try {
      final response = await _client.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) return null;
      try {
        final body = jsonDecode(response.body);
        if (body is Map) {
          if (body['message'] != null) return body['message'].toString();
          if (body['error'] != null) return body['error'].toString();
          return response.body;
        }
      } catch (_) {}
      return response.body.isNotEmpty ? response.body : 'Failed to follow. Server returned ${response.statusCode}';
    } catch (e) {
      return 'An error occurred while following the channel.';
    }
  }

  /// DELETE /api/v1/users/channels/{channelId}/unfollow
  /// Unfollow a channel
  Future<String?> unfollowChannel({
    required String token,
    required String channelId,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/users/channels/$channelId/unfollow');
    try {
      final response = await _client.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200 || response.statusCode == 204) return null;
      try {
        final body = jsonDecode(response.body);
        if (body is Map) {
          if (body['message'] != null) return body['message'].toString();
          if (body['error'] != null) return body['error'].toString();
          return response.body;
        }
      } catch (_) {}
      return response.body.isNotEmpty ? response.body : 'Failed to unfollow. Server returned ${response.statusCode}';
    } catch (e) {
      return 'An error occurred while unfollowing the channel.';
    }
  }
}
