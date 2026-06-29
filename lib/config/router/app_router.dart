import 'package:go_router/go_router.dart';
import 'package:nic_pre_u/screens/calificar_asesor.dart';
import 'package:nic_pre_u/screens/steam/steam_home_screen.dart';
import 'package:nic_pre_u/screens/evaluaciones_screen.dart';
import 'package:nic_pre_u/screens/explorar_screen.dart';
import 'package:nic_pre_u/screens/home_screen.dart';
import 'package:nic_pre_u/screens/login_screen.dart';
import 'package:nic_pre_u/screens/myqr_screen.dart';
import 'package:nic_pre_u/screens/onboarding/splash_screen.dart';
import 'package:nic_pre_u/screens/onboarding/onboarding_flow.dart';
import 'package:nic_pre_u/screens/perfil_screen.dart';
import 'package:nic_pre_u/screens/reportes/asistencia_report_screen.dart';
import 'package:nic_pre_u/screens/reportes/notas_report_screen.dart';
import 'package:nic_pre_u/screens/reportes/orientacion_vocacional_screen.dart';
import 'package:nic_pre_u/screens/empezar_clase_screen.dart';
import 'package:nic_pre_u/screens/register_screen.dart';
import 'package:nic_pre_u/screens/scan_screen.dart';
import 'package:nic_pre_u/screens/simuladores/simuladores_screen.dart';
import 'package:nic_pre_u/screens/student_schedule_screen.dart';
import 'package:nic_pre_u/screens/ver_section_screen.dart';
import 'package:nic_pre_u/services/auth_service.dart';
import 'package:nic_pre_u/services/course_service.dart';
import 'package:nic_pre_u/shared/ui/course_grades_screen.dart';
import 'package:nic_pre_u/shared/ui/courses_list_screen.dart';

final AuthService _authService = AuthService();
const String _devInitialRoute = String.fromEnvironment('NIC_DEV_INITIAL_ROUTE');

GoRouter buildRouter({
  bool hasCompletedOnboarding = false,
  bool isAuthenticated = false,
  bool isSteam = false,
}) {
  return GoRouter(
    initialLocation: _devInitialRoute.isNotEmpty
        ? _devInitialRoute
        : isAuthenticated
        ? (isSteam ? '/steam' : '/home')
        : (hasCompletedOnboarding ? '/' : '/onboarding/splash'),
    routes: [
      // ─── Onboarding ───
      GoRoute(
        path: '/onboarding/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding/flow',
        name: 'onboarding-flow',
        builder: (context, state) => const OnboardingFlow(),
      ),

      // ─── Auth ───
      GoRoute(
        path: '/',
        redirect: (context, state) async {
          final hasToken = await _authService.hasToken();
          return hasToken ? '/home' : '/login';
        },
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
        redirect: (context, state) async {
          final hasToken = await _authService.hasToken();
          if (!hasToken) return null;
          return await _authService.isSteamUser() ? '/steam' : '/home';
        },
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // ─── STEAM mode ───
      GoRoute(
        path: '/steam',
        name: 'steam',
        builder: (context, state) => const SteamHomeScreen(),
        redirect: (context, state) async {
          final hasToken = await _authService.hasToken();
          return hasToken ? null : '/login';
        },
      ),

      // ─── App principal ───
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
        redirect: (context, state) async {
          final hasToken = await _authService.hasToken();
          if (!hasToken) return '/login';
          // Redirect STEAM students to their special experience
          if (await _authService.isSteamUser()) return '/steam';
          return null;
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
            path: 'horarios-estudiantes',
            name: 'horarios-estudiantes',
            builder: (context, state) => const StudentScheduleScreen(),
          ),
          GoRoute(
            path: 'asistencia',
            name: 'asistencia',
            builder: (context, state) => const AsistenciaReportScreen(),
          ),
          GoRoute(
            path: 'evaluaciones-activas',
            name: 'evaluaciones-activas',
            builder: (context, state) => const EvaluacionesScreen(),
          ),
          GoRoute(
            path: 'notas',
            name: 'notas',
            builder: (context, state) => const NotasReportScreen(),
          ),
          GoRoute(
            path: 'calificacion',
            name: 'calificacion',
            builder: (context, state) => const CalificarAtencionScreen(),
          ),
          GoRoute(
            path: 'orientacion',
            name: 'orientacion',
            builder: (context, state) => const OVScreen(),
          ),
          GoRoute(
            path: 'simuladores',
            name: 'simuladores',
            builder: (context, state) => const SimuladoresScreen(),
          ),
          GoRoute(
            path: 'explorar',
            name: 'explorar',
            builder: (context, state) => const ExplorarScreen(),
            routes: [
              GoRoute(
                path: ':id',
                name: 'ver-seccion',
                builder: (context, state) {
                  final id =
                      int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
                  final extra = state.extra as Map<String, dynamic>?;
                  return VerSectionScreen(
                    courseId: id,
                    courseData: extra ?? {},
                  );
                },
                routes: [
                  GoRoute(
                    path: 'clase',
                    name: 'empezar-clase',
                    builder: (context, state) {
                      final extra =
                          (state.extra as Map<String, dynamic>?) ?? {};
                      return EmpezarClaseScreen(
                        courseData:
                            (extra['courseData'] as Map<String, dynamic>?) ??
                            {},
                        unitIndex: (extra['unitIndex'] as int?) ?? 0,
                        lessonIndex: (extra['lessonIndex'] as int?) ?? 0,
                        lesson: extra['lesson'],
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: 'perfil',
            name: 'perfil',
            builder: (context, state) => const PerfilScreen(),
          ),
          GoRoute(
            path: 'courses',
            builder: (context, state) =>
                CoursesListScreen(service: CourseService()),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return CourseGradesScreen(id: id, service: CourseService());
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
