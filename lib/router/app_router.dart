import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../providers/user_session_provider.dart';
import '../screens/auth_screen.dart';
import '../screens/verify_otp_screen.dart';
import '../screens/complete_profile_screen.dart';
import '../screens/home_screen.dart';

class AppRouter {
  static GoRouter createRouter(UserSessionProvider sessionProvider) {
    return GoRouter(
      initialLocation: '/auth',
      refreshListenable: sessionProvider,
      routes: [
        GoRoute(
          path: '/auth',
          name: 'auth',
          builder: (context, state) => const AuthScreen(),
        ),
        GoRoute(
          path: '/verify-otp',
          name: 'verify-otp',
          builder: (context, state) => const VerifyOtpScreen(),
        ),
        GoRoute(
          path: '/complete-profile',
          name: 'complete-profile',
          builder: (context, state) => const CompleteProfileScreen(),
        ),
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (context, state) => const HomeScreen(),
        ),
      ],
      redirect: (BuildContext context, GoRouterState state) {
        final session = sessionProvider.session;
        final isAuth = session.isAuthenticated;
        final currentLoc = state.matchedLocation;

        // If authenticated, keep user on /home
        if (isAuth) {
          if (currentLoc != '/home') {
            return '/home';
          }
          return null;
        }

        // Unauthenticated guard rules
        if (currentLoc == '/home') {
          return '/auth';
        }

        if (currentLoc == '/complete-profile') {
          if (!session.otpVerified || !session.isNewUser) {
            return '/auth';
          }
        }

        if (currentLoc == '/verify-otp') {
          if (!session.otpSent) {
            return '/auth';
          }
        }

        return null;
      },
    );
  }
}
