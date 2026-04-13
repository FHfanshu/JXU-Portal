import 'package:flutter/material.dart';

import '../../core/auth/zhengfang_auth.dart';
import '../../shared/widgets/zhengfang_protected_webview_page.dart';

class AcademicServicePage extends StatelessWidget {
  const AcademicServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ZhengfangProtectedWebViewPage(
      title: '教务系统',
      url: ZhengfangAuth.instance.academicServiceUrl,
      loginDescription: '账号为学号',
    );
  }
}
