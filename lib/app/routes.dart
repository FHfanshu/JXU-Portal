import 'package:go_router/go_router.dart';

import 'app_route_observer.dart';
import 'app_shell_page.dart';
import '../features/home/home_page.dart';
import '../features/my/my_page.dart';
import '../features/my/academic_service_page.dart';
import '../features/my/unified_auth_login_page.dart';
import '../features/my/academic_system_login_page.dart';
import '../features/schedule/schedule_page.dart';
import '../features/grades/grades_page.dart';
import '../features/campus_card/campus_card_page.dart';
import '../features/campus_card/campus_card_payment_page.dart';
import '../features/notice/notice_list_page.dart';
import '../features/service_hall/service_hall_page.dart';
import '../features/settings/settings_page.dart';
import '../features/dorm_electricity/dorm_electricity_page.dart';
import '../features/dorm_electricity/dorm_electricity_settings_page.dart';
import '../features/changxing_jiada/changxing_back_school_form_page.dart';
import '../features/changxing_jiada/changxing_jiada_page.dart';
import '../features/changxing_jiada/changxing_leave_form_page.dart';
import '../features/changxing_jiada/changxing_overtime_form_page.dart';
import '../features/changxing_jiada/changxing_jiada_model.dart';
import '../shared/widgets/unified_auth_protected_webview_page.dart';
import '../shared/widgets/webview_page.dart';

int? _parseOptionalId(GoRouterState state) {
  final text = state.uri.queryParameters['id']?.trim() ?? '';
  if (text.isEmpty) return null;
  return int.tryParse(text);
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  observers: [appRouteObserver],
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AppShellPage(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              name: 'home',
              builder: (context, state) => const HomePage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/my',
              name: 'my',
              builder: (context, state) => const MyPage(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/schedule',
      name: 'schedule',
      builder: (context, state) => const SchedulePage(),
    ),
    GoRoute(
      path: '/grades',
      name: 'grades',
      builder: (context, state) => const GradesPage(),
    ),
    GoRoute(
      path: '/campus-card',
      name: 'campus-card',
      builder: (context, state) => const CampusCardPage(),
    ),
    GoRoute(
      path: '/campus-card-payment',
      name: 'campus-card-payment',
      builder: (context, state) => const CampusCardPaymentPage(),
    ),
    GoRoute(
      path: '/service-hall',
      name: 'service-hall',
      builder: (context, state) => const ServiceHallPage(),
    ),
    GoRoute(
      path: '/library',
      name: 'library',
      builder: (context, state) => UnifiedAuthProtectedWebViewPage(
        title: '图书馆',
        url: 'https://libapp.zjxu.edu.cn/#!/Content/Index/index',
        serviceUrl:
            'https://libapp.zjxu.edu.cn/Info/Thirdparty/ssoFromDingDing',
        loginDescription: '统一认证登录后可直接进入图书馆',
        preferWebViewBackNavigation: true,
        onHomePressed: () => context.goNamed('home'),
      ),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: '/unified-auth-login',
      name: 'unified-auth-login',
      builder: (context, state) => const UnifiedAuthLoginPage(),
    ),
    GoRoute(
      path: '/academic-system-login',
      name: 'academic-system-login',
      builder: (context, state) => const AcademicSystemLoginPage(),
    ),
    GoRoute(
      path: '/academic-service',
      name: 'academic-service',
      builder: (context, state) => const AcademicServicePage(),
    ),
    GoRoute(
      path: '/notice-list',
      name: 'notice-list',
      builder: (context, state) => const NoticeListPage(),
    ),
    GoRoute(
      path: '/news-detail',
      name: 'news-detail',
      builder: (context, state) {
        final extra = state.extra as Map<String, String>;
        return WebViewPage(
          title: extra['title'] ?? '新闻详情',
          url: extra['url'] ?? '',
        );
      },
    ),
    GoRoute(
      path: '/dorm-electricity',
      name: 'dorm-electricity',
      builder: (context, state) => const DormElectricityPage(),
    ),
    GoRoute(
      path: '/dorm-electricity-settings',
      name: 'dorm-electricity-settings',
      builder: (context, state) => const DormElectricitySettingsPage(),
    ),
    GoRoute(
      path: '/external-webview',
      name: 'external-webview',
      builder: (context, state) {
        final extra = Map<String, dynamic>.from(
          (state.extra as Map?) ?? const <String, dynamic>{},
        );
        return WebViewPage(
          title: extra['title'] ?? '网页',
          url: extra['url'] ?? '',
          enableLoginQuickFill: extra['enableLoginQuickFill'] == true,
        );
      },
    ),
    GoRoute(
      path: '/changxing-jiada',
      name: 'changxing-jiada',
      builder: (context, state) => const ChangxingJiadaPage(),
    ),
    GoRoute(
      path: '/changxing-jiada/leave-request',
      name: ChangxingFormType.leaveRequest.routeName,
      builder: (context, state) => ChangxingLeaveFormPage(
        formType: ChangxingFormType.leaveRequest,
        applicationId: _parseOptionalId(state),
      ),
    ),
    GoRoute(
      path: '/changxing-jiada/leave-school',
      name: ChangxingFormType.leaveSchool.routeName,
      builder: (context, state) => ChangxingLeaveFormPage(
        formType: ChangxingFormType.leaveSchool,
        applicationId: _parseOptionalId(state),
      ),
    ),
    GoRoute(
      path: '/changxing-jiada/back-school',
      name: ChangxingFormType.backSchool.routeName,
      builder: (context, state) =>
          ChangxingBackSchoolFormPage(applicationId: _parseOptionalId(state)),
    ),
    GoRoute(
      path: '/changxing-jiada/overtime',
      name: ChangxingFormType.overtime.routeName,
      builder: (context, state) =>
          ChangxingOvertimeFormPage(applicationId: _parseOptionalId(state)),
    ),
  ],
);
