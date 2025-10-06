import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../main.dart'; // AuthBloc and AuthState are defined here
import '../models/user.dart';

class DeepLinkingService {
  static final DeepLinkingService _instance = DeepLinkingService._internal();
  factory DeepLinkingService() => _instance;
  DeepLinkingService._internal();

  /// Handle deep links based on URL patterns
  void handleDeepLink(String link, BuildContext context, AuthState authState) {
    // Wait for auth to be ready
    if (authState is AuthLoading || authState is AuthInitial) {
      return; // Wait for auth to complete
    }
    
    if (authState is! AuthAuthenticated) {
      // User not authenticated, redirect to login
      context.go('/login');
      return;
    }

    final user = authState.user;
    
    try {
      final uri = Uri.parse(link);
      final path = uri.path;
      final queryParams = uri.queryParameters;

      switch (path) {
        // Teacher deep links
        case '/teacher/profile':
          if (user.isTeacher) {
            context.go('/teacher/profile');
          } else {
            _showUnauthorizedDialog(context);
          }
          break;
          
        case '/teacher/assignments':
          if (user.isTeacher) {
            context.go('/teacher/assignments');
          } else {
            _showUnauthorizedDialog(context);
          }
          break;
          
        case '/teacher/reservations':
          if (user.isTeacher) {
            context.go('/teacher/reservations');
          } else {
            _showUnauthorizedDialog(context);
          }
          break;

        // Student deep links
        case '/student/profile':
          if (user.isStudent) {
            context.go('/student/profile');
          } else {
            _showUnauthorizedDialog(context);
          }
          break;
          
        case '/student/assignments':
          if (user.isStudent) {
            context.go('/student/assignments');
          } else {
            _showUnauthorizedDialog(context);
          }
          break;
          
        case '/student/reservations':
          if (user.isStudent) {
            context.go('/student/reservations');
          } else {
            _showUnauthorizedDialog(context);
          }
          break;

        // Admin deep links
        case '/admin/dashboard':
          if (user.isAdmin) {
            context.go('/admin/dashboard');
          } else {
            _showUnauthorizedDialog(context);
          }
          break;
          
        case '/admin/users':
          if (user.isAdmin) {
            context.go('/admin/users');
          } else {
            _showUnauthorizedDialog(context);
          }
          break;

        // Teacher detail with ID
        case '/teacher':
          if (queryParams.containsKey('id')) {
            final teacherId = queryParams['id'];
            context.go('/teacher/$teacherId');
          } else {
            context.go('/teachers');
          }
          break;

        // Student detail with ID
        case '/student':
          if (queryParams.containsKey('id') && user.isAdmin) {
            final studentId = queryParams['id'];
            context.go('/student/$studentId');
          } else {
            context.go('/students');
          }
          break;

        // Assignment detail with ID
        case '/assignment':
          if (queryParams.containsKey('id')) {
            final assignmentId = queryParams['id'];
            context.go('/assignment/$assignmentId');
          } else {
            context.go('/assignments');
          }
          break;

        // Reservation detail with ID
        case '/reservation':
          if (queryParams.containsKey('id')) {
            final reservationId = queryParams['id'];
            context.go('/reservation/$reservationId');
          } else {
            context.go('/reservations');
          }
          break;

        // Chat with specific user
        case '/chat':
          if (queryParams.containsKey('user_id')) {
            final userId = queryParams['user_id'];
            context.go('/chat/$userId');
          } else {
            context.go('/chats');
          }
          break;

        // Default fallback
        default:
          _handleDefaultRoute(user, context);
          break;
      }
    } catch (e) {
      debugPrint('Deep link parsing error: $e');
      _handleDefaultRoute(user, context);
    }
  }

  void _handleDefaultRoute(User user, BuildContext context) {
    if (user.isAdmin) {
      context.go('/admin/dashboard');
    } else if (user.isTeacher) {
      context.go('/teacher/home');
    } else if (user.isStudent) {
      context.go('/student/home');
    } else {
      context.go('/home');
    }
  }

  void _showUnauthorizedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yetkisiz Erişim'),
        content: const Text('Bu sayfaya erişim yetkiniz bulunmuyor.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _handleDefaultRoute(
                (context.read<AuthBloc>().state as AuthAuthenticated).user,
                context,
              );
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  /// Generate deep link for teacher profile
  String generateTeacherProfileLink(int teacherId) {
    return 'nazliyavuz://teacher?id=$teacherId';
  }

  /// Generate deep link for assignment
  String generateAssignmentLink(int assignmentId) {
    return 'nazliyavuz://assignment?id=$assignmentId';
  }

  /// Generate deep link for reservation
  String generateReservationLink(int reservationId) {
    return 'nazliyavuz://reservation?id=$reservationId';
  }

  /// Generate deep link for chat
  String generateChatLink(int userId) {
    return 'nazliyavuz://chat?user_id=$userId';
  }

  /// Check if URL is a valid deep link
  bool isValidDeepLink(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.scheme == 'nazliyavuz' || uri.host == 'nazliyavuz.com';
    } catch (e) {
      return false;
    }
  }

  /// Extract path from deep link
  String? extractPath(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.scheme == 'nazliyavuz') {
        return uri.path;
      } else if (uri.host == 'nazliyavuz.com') {
        return uri.path;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
