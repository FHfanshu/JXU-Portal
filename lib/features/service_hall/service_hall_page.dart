import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/unified_auth_protected_webview_page.dart';

class ServiceHallPage extends StatelessWidget {
  const ServiceHallPage({super.key});

  @override
  Widget build(BuildContext context) {
    return UnifiedAuthProtectedWebViewPage(
      title: '服务大厅',
      url:
          'https://mobilehall.zjxu.edu.cn/mportal/start/index.html#/business/ydd/portal/home',
      loginDescription: '统一认证登录后可直接进入服务大厅',
      preferWebViewBackNavigation: true,
      onHomePressed: () => context.goNamed('home'),
    );
  }
}
