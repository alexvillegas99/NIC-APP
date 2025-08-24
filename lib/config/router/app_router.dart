import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nic_pre_u/data/course.dart';
import 'package:nic_pre_u/screens/home_screen.dart';
import 'package:nic_pre_u/screens/login_screen.dart';
import 'package:nic_pre_u/screens/myqr_screen.dart';
import 'package:nic_pre_u/screens/scan_screen.dart';
import 'package:nic_pre_u/services/auth_service.dart';
import 'package:nic_pre_u/services/course_service.dart';
import 'package:nic_pre_u/shared/ui/course_grades_screen.dart';
import 'package:nic_pre_u/shared/ui/courses_list_screen.dart';

final AuthService _authService = AuthService(); // 🔹 Servicio de autenticación

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/', // 🔹 La primera ruta que se evalúa
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) async {
          final hasToken = await _authService.hasToken();
          return hasToken ? '/home' : '/login';
        },
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
        redirect: (context, state) async {
          final hasToken = await _authService.hasToken();
          return hasToken ? '/home' : null; // Si hay token, redirigir a Home
        },
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
        redirect: (context, state) async {
          final hasToken = await _authService.hasToken();
          return hasToken
              ? null
              : '/login'; // Si no hay token, redirigir a Login
        },
        routes: [
          GoRoute(
            path: 'scan',
            name: 'scan',
            builder: (context, state) => const ScanScreen(),
          ),
          GoRoute(
            path: 'myqr',
            name: 'myqr',
            builder: (context, state) => const MyQRScreen(),
          ),
          GoRoute(
            path: 'courses',
            builder: (context, state) => CoursesListScreen(
              service: CourseService(), // <-- ajusta
            ),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  final extra = state.extra;
                  return CourseGradesScreen(
                    id: id,
                    service: CourseService(),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
