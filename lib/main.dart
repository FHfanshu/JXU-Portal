import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_bootstrap_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppBootstrapController.instance.prepareForFirstFrame();
  runApp(const JiaxingUniversityApp());
  AppBootstrapController.instance.scheduleWarmUpAfterFirstFrame();
}
