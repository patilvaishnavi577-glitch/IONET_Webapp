/// Data model representing the user's authentication and onboarding session.
class UserSession {
  final String? email;
  final bool isRegisterMode;
  final bool otpSent;
  final bool otpVerified;
  final bool isNewUser;
  final String? fullName;
  final String? mobileNumber;
  final String countryCode;
  final bool isAuthenticated;
  final DateTime? sessionStartTime;
  final String? token; // JWT token
  final String? profilePictureUrl;
  final String? userId;

  const UserSession({
    this.email,
    this.isRegisterMode = false,
    this.otpSent = false,
    this.otpVerified = false,
    this.isNewUser = false,
    this.fullName,
    this.mobileNumber,
    this.countryCode = '+91',
    this.isAuthenticated = false,
    this.sessionStartTime,
    this.token,
    this.profilePictureUrl,
    this.userId,
  });

  UserSession copyWith({
    String? email,
    bool? isRegisterMode,
    bool? otpSent,
    bool? otpVerified,
    bool? isNewUser,
    String? fullName,
    String? mobileNumber,
    String? countryCode,
    bool? isAuthenticated,
    DateTime? sessionStartTime,
    String? token,
    String? profilePictureUrl,
    String? userId,
    bool clearAvatar = false,
  }) {
    return UserSession(
      email: email ?? this.email,
      isRegisterMode: isRegisterMode ?? this.isRegisterMode,
      otpSent: otpSent ?? this.otpSent,
      otpVerified: otpVerified ?? this.otpVerified,
      isNewUser: isNewUser ?? this.isNewUser,
      fullName: fullName ?? this.fullName,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      countryCode: countryCode ?? this.countryCode,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      sessionStartTime: sessionStartTime ?? this.sessionStartTime,
      token: token ?? this.token,
      profilePictureUrl: clearAvatar ? null : (profilePictureUrl ?? this.profilePictureUrl),
      userId: userId ?? this.userId,
    );
  }

  /// Factory for an unauthenticated initial state
  factory UserSession.initial() {
    return const UserSession();
  }
}
