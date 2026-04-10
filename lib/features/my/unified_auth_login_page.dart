import 'package:flutter/material.dart';

import '../../shared/widgets/login_shell.dart';
import '../../shared/widgets/unified_auth_login_widget.dart';

class UnifiedAuthLoginPage extends StatelessWidget {
  const UnifiedAuthLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('统一认证登录')),
      body: LoginShell(
        title: '登录统一认证',
        description: '登录后可进入一卡通、服务大厅等服务',
        badgeText: '统一认证',
        topSafeArea: false,
        child: UnifiedAuthLoginWidget(
          title: '登录统一认证',
          description: '登录后可进入一卡通、服务大厅等服务',
          showHeader: false,
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          onLoginSuccess: () => Navigator.of(context).pop(true),
        ),
      ),
    );
  }
}
