import 'package:flutter/material.dart';
import '../config/supabase_config.dart';
import '../services/auth_service.dart';
import '../services/admin_service.dart';
import '../core/utils/preferences_helper.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/admin/admin_dashboard_screen.dart';
import '../features/user/user_dashboard_screen.dart';

/// Authentication middleware for handling role-based routing and authentication state
class AuthMiddleware {
  /// Determines the initial screen based on authentication and onboarding status
  static Future<Widget> getInitialScreen() async {
    try {
      // Check if user has seen onboarding
      final hasSeenOnboarding = await _checkOnboardingStatus();

      if (!hasSeenOnboarding) {
        return const OnboardingScreen();
      }

      // Check authentication status
      final authState = await _checkAuthenticationStatus();

      switch (authState) {
        case AuthState.authenticated:
          return await _getRoleBasedScreen();
        case AuthState.pendingAdmin:
          // Show login screen for pending admin approval
          return const LoginScreen();
        case AuthState.rejectedAdmin:
          // Show login screen for rejected admin
          return const LoginScreen();
        case AuthState.unauthenticated:
        default:
          return const LoginScreen();
      }
    } catch (e) {
      // On error, default to login screen
      return const LoginScreen();
    }
  }

  /// Checks if user has completed onboarding
  static Future<bool> _checkOnboardingStatus() async {
    try {
      final hasSeenOnboarding = await PreferencesHelper.getHasSeenOnboarding();
      return hasSeenOnboarding;
    } catch (e) {
      // On error, assume onboarding is not completed
      return false;
    }
  }

  /// Checks the current authentication status
  static Future<AuthState> _checkAuthenticationStatus() async {
    try {
      final user = SupabaseConfig.currentUser;

      if (user == null) {
        return AuthState.unauthenticated;
      }

      // First check if user exists in user_profiles (approved users)
      final userRole = await AuthService.getCurrentUserRole();
      if (userRole != null) {
        return AuthState.authenticated;
      }

      // If not in user_profiles, check their admin request status
      final userRequest = await AdminService.getUserAdminRequest(user.id);
      if (userRequest != null) {
        final status = userRequest['status'];
        if (status == 'pending') {
          return AuthState.pendingAdmin;
        } else if (status == 'rejected') {
          return AuthState.rejectedAdmin;
        }
      }

      // If not in either table, they were rejected
      return AuthState.rejectedAdmin;
    } catch (e) {
      return AuthState.unauthenticated;
    }
  }

  /// Gets the appropriate screen based on user role
  static Future<Widget> _getRoleBasedScreen() async {
    try {
      final userRole = await AuthService.getCurrentUserRole();
      print('🎯 Routing user with role: $userRole');

      switch (userRole) {
        case 'admin':
          print('🏢 Routing to AdminDashboardScreen');
          return const AdminDashboardScreen();
        case 'user':
          print('👤 Routing to UserDashboardScreen');
          return const UserDashboardScreen();
        case 'pending_admin':
          print('⏳ Routing pending admin to LoginScreen');
          return const LoginScreen();
        default:
          print('❓ Unknown role "$userRole", defaulting to UserDashboardScreen');
          return const UserDashboardScreen();
      }
    } catch (e) {
      print('❌ Error getting user role: $e');
      print('👤 Defaulting to UserDashboardScreen on error');
      // Default to user dashboard on error
      return const UserDashboardScreen();
    }
  }

  /// Validates if a user can access a specific route based on their role
  static Future<bool> canAccessRoute(String routeName) async {
    try {
      final userRole = await AuthService.getCurrentUserRole();

      // Define role-based access control
      const adminRoutes = ['/admin-dashboard'];
      const userRoutes = ['/home', '/user-dashboard', '/plant-details'];
      const publicRoutes = ['/login', '/register', '/onboarding'];

      if (publicRoutes.contains(routeName)) {
        return true;
      }

      if (adminRoutes.contains(routeName)) {
        return userRole == 'admin';
      }

      if (userRoutes.contains(routeName)) {
        return userRole == 'user' || userRole == 'admin';
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Gets the default route for a user role
  static Future<String> getDefaultRouteForRole() async {
    try {
      final userRole = await AuthService.getCurrentUserRole();

      switch (userRole) {
        case 'admin':
          return '/admin-dashboard';
        case 'user':
        default:
          return '/home';
      }
    } catch (e) {
      return '/login';
    }
  }
}

/// Authentication states
enum AuthState {
  authenticated,
  unauthenticated,
  pendingAdmin,
  rejectedAdmin,
}

/// Extension for AuthState
extension AuthStateExtension on AuthState {
  String get description {
    switch (this) {
      case AuthState.authenticated:
        return 'User is authenticated';
      case AuthState.unauthenticated:
        return 'User is not authenticated';
      case AuthState.pendingAdmin:
        return 'Admin account pending approval';
      case AuthState.rejectedAdmin:
        return 'Admin request was rejected';
    }
  }
}