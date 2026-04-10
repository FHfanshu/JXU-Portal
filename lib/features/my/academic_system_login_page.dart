import 'package:flutter/material.dart';

import '../../shared/widgets/login_shell.dart';
import '../../shared/widgets/login_widget.dart';

class AcademicSystemLoginPage extends StatelessWidget {
  const AcademicSystemLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('教务系统登录')),
      body: LoginShell(
        title: '登录教务系统',
        description: '登录后可查看课表、成绩与教务服务',
        badgeText: '教务系统',
        topSafeArea: false,
        child: LoginWidget(
          showHeader: false,
          padding: EdgeInsets.zero,
          onLoginSuccess: () => Navigator.of(context).pop(true),
        ),
      ),
    );
  }
}
