import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_bootstrap_controller.dart';
import 'core/shortcut/app_shortcut_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppBootstrapController.instance.prepareForFirstFrame();
  await AppShortcutService.instance.initialize();
  runApp(const JiaxingUniversityApp());
  AppBootstrapController.instance.scheduleWarmUpAfterFirstFrame();
}
