import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_session.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';

/// Provider managing application session state and real auth API workflows.
class UserSessionProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final SharedPreferences? _prefs;
  
  UserSession _session = UserSession.initial();
  bool _isLoading = false;

  UserSessionProvider({SharedPreferences? prefs}) : _prefs = prefs {
    _loadSession();
  }

  void _loadSession() {
    if (_prefs == null) return;
    final token = _prefs!.getString('auth_token');
    if (token != null && token.isNotEmpty) {
      _session = _session.copyWith(
        token: token,
        isAuthenticated: true,
      );
      // We asynchronously fetch the user profile here to hydrate the state
      _fetchProfileAndHydrate(token);
    }
  }

  Future<void> _fetchProfileAndHydrate(String token) async {
    _setLoading(true);
    try {
      final profile = await _apiService.getUserMe(token);
      if (profile != null) {
      final id = profile['id']?.toString() ?? profile['_id']?.toString();
      final name = profile['name']?.toString() ?? '';
      final phone = profile['phoneNumber']?.toString() ?? '';
      final email = profile['email']?.toString() ?? '';
      final avatar = profile['profilePictureUrl']?.toString() ??
          profile['profilePicture']?.toString() ??
          '';

      _session = _session.copyWith(
        fullName: name,
        mobileNumber: phone,
        email: email,
        profilePictureUrl: _formatAvatarUrl(avatar),
        userId: id,
      );
    } else {
      // If profile fetch fails (e.g. token expired), we should probably clear it
      logout();
    }
    } catch (e, s) {
      if (_prefs != null) {
        _prefs!.setString('crash_log', 'fetchProfileAndHydrate: $e\n$s');
      }
      logout();
    }
    _setLoading(false);
  }

  UserSession get session => _session;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _session.isAuthenticated;
  bool get otpSent => _session.otpSent;
  bool get otpVerified => _session.otpVerified;
  bool get isNewUser => _session.isNewUser;
  String? get email => _session.email;
  String? get fullName => _session.fullName;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// STEP 1: Send OTP to user's email using request-otp API
  Future<bool> sendOtp({
    required String email,
    required bool isRegisterMode,
  }) async {
    _setLoading(true);
    final success = await _apiService.requestOtp(email);

    if (success) {
      _session = _session.copyWith(
        email: email,
        isRegisterMode: isRegisterMode,
        otpSent: true,
        otpVerified: false,
      );
    }
    _setLoading(false);
    return success;
  }

  /// STEP 2: Verify 6-digit OTP code using verify-otp API
  /// If successful, fetches profile via users/me to check if the user is new/existing.
  Future<bool> verifyOtp(String otpCode) async {
    if (_session.email == null) return false;
    _setLoading(true);

    final data = await _apiService.verifyOtp(_session.email!, otpCode);
    if (data == null) {
      _setLoading(false);
      return false; // OTP verification failed
    }

    final token = data['accessToken']?.toString();
    if (token == null) {
      _setLoading(false);
      return false;
    }

    final profileCompleted = data['profileCompleted'] as bool? ?? false;

    // Routing Logic Rules matching Postman collection payloads:
    // - If profileCompleted is false -> SHOW create profile page (isNewUser = true)
    // - If profileCompleted is true -> DONT show create profile page (direct login, isNewUser = false)
    if (profileCompleted) {
      // Existing User: Fetch user profile details from backend to display on Home profile tab
      final profile = await _apiService.getUserMe(token);
      final id = profile?['id']?.toString() ?? profile?['_id']?.toString();
      final name = profile?['name']?.toString() ?? '';
      final phone = profile?['phoneNumber']?.toString() ?? '';
      final email = profile?['email']?.toString() ?? '';
      final avatar = profile?['profilePictureUrl']?.toString() ??
          profile?['profilePicture']?.toString() ??
          '';

      _session = _session.copyWith(
        token: token,
        otpVerified: true,
        isNewUser: false,
        fullName: name,
        mobileNumber: phone,
        email: email.isNotEmpty ? email : null,
        profilePictureUrl: _formatAvatarUrl(avatar),
        isAuthenticated: true,
        sessionStartTime: DateTime.now(),
        userId: id,
      );
      _prefs?.setString('auth_token', token);
    } else {
      // New User: must fill profile name and phone number
      _session = _session.copyWith(
        token: token,
        otpVerified: true,
        isNewUser: true,
      );
    }

    _setLoading(false);
    return _session.isNewUser;
  }

  /// STEP 3: Complete user profile information for new users
  Future<bool> completeProfile({
    required String name,
    required String mobileNumber,
    String countryCode = '+91',
  }) async {
    if (_session.token == null) return false;
    _setLoading(true);

    final success = await _apiService.createProfile(
      token: _session.token!,
      name: name,
      phoneNumber: mobileNumber,
    );

    if (success) {
      final profile = await _apiService.getUserMe(_session.token!);
      final id = profile?['id']?.toString() ?? profile?['_id']?.toString();
      _session = _session.copyWith(
        fullName: name,
        mobileNumber: mobileNumber,
        countryCode: countryCode,
        isAuthenticated: true,
        sessionStartTime: DateTime.now(),
        userId: id,
      );
      _prefs?.setString('auth_token', _session.token!);
    }

    _setLoading(false);
    return success;
  }

  /// STEP 4: Update user profile details
  Future<bool> updateProfile({
    required String name,
    required String mobileNumber,
  }) async {
    if (_session.token == null) return false;
    _setLoading(true);

    final success = await _apiService.editProfile(
      token: _session.token!,
      name: name,
      phoneNumber: mobileNumber,
    );

    if (success) {
      _session = _session.copyWith(
        fullName: name,
        mobileNumber: mobileNumber,
      );
    }

    _setLoading(false);
    return success;
  }

  /// STEP 5: Deactivate user account
  Future<bool> deactivateAccount() async {
    if (_session.token == null) return false;
    _setLoading(true);

    final success = await _apiService.deactivateAccount(token: _session.token!);

    if (success) {
      logout();
    } else {
      _setLoading(false);
    }
    return success;
  }

  /// STEP 6: Upload profile picture avatar
  Future<bool> uploadAvatar({
    required List<int> bytes,
    required String filename,
  }) async {
    if (_session.token == null) return false;
    _setLoading(true);

    final avatarUrl = await _apiService.uploadProfileAvatar(
      token: _session.token!,
      fileBytes: bytes,
      filename: filename,
    );

    if (avatarUrl != null) {
      _session = _session.copyWith(
        profilePictureUrl: _formatAvatarUrl(avatarUrl),
      );
      _setLoading(false);
      return true;
    }

    _setLoading(false);
    return false;
  }

  /// STEP 7: Delete profile picture avatar
  Future<bool> deleteAvatar() async {
    if (_session.token == null) return false;
    _setLoading(true);

    final success = await _apiService.deleteProfileAvatar(token: _session.token!);

    if (success) {
      _session = _session.copyWith(
        clearAvatar: true,
      );
    }

    _setLoading(false);
    return success;
  }

  /// STEP 8: Logout user session
  void logout() {
    _session = UserSession.initial();
    _isLoading = false;
    _prefs?.remove('auth_token');
    notifyListeners();
  }

  String? _formatAvatarUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('/')) {
      return '${ApiConfig.baseUrl}$url';
    }
    return url;
  }
}
