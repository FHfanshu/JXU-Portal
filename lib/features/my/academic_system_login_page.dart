import 'package:flutter/material.dart';

import '../../shared/widgets/login_widget.dart';

class AcademicSystemLoginPage extends StatelessWidget {
  const AcademicSystemLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('教务系统登录')),
      body: LoginWidget(onLoginSuccess: () => Navigator.of(context).pop(true)),
    );
  }
}
