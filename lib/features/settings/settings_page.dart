import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/text_scale_controller.dart';
import '../../app/theme_mode_controller.dart';
import '../../core/logging/app_logger.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/network_settings.dart';
import '../../core/semester/semester_calendar.dart';
import '../dorm_electricity/dorm_electricity_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  String _formatScaleFactor(double value) => '${(value * 100).round()}%';

  String _formatDate(DateTime date) {
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _pickSemesterStartDate(
    BuildContext context,
    DateTime currentDate,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: '选择开学日',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked == null) return;
    await SemesterCalendar.instance.setSemesterStartDate(picked);
  }

  Future<void> _setIgnoreSystemProxy(bool value) async {
    await NetworkSettings.instance.setIgnoreSystemProxy(value);
    // 延迟到下一微任务，避免阻塞切换动画
    Future.microtask(() {
      DioClient.instance.applyProxyMode();
      DormElectricityService.instance.applyProxyMode();
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('外观', style: textTheme.titleMedium),
          const SizedBox(height: 12),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeModeController.instance.themeMode,
            builder: (context, themeMode, child) {
              return Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                      child: Text('主题模式', style: textTheme.titleSmall),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.system,
                            icon: Icon(Icons.brightness_auto),
                            label: Text(
                              '跟随系统',
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                            ),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.light,
                            icon: Icon(Icons.light_mode),
                            label: Text('浅色'),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.dark,
                            icon: Icon(Icons.dark_mode),
                            label: Text('深色'),
                          ),
                        ],
                        selected: {themeMode},
                        onSelectionChanged: (selection) {
                          ThemeModeController.instance.setThemeMode(
                            selection.first,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<double>(
            valueListenable: TextScaleController.instance.textScaleFactor,
            builder: (context, textScaleFactor, child) {
              return Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      title: const Text('应用字号'),
                      subtitle: const Text('基于系统字号缩放，最大限制到 120%'),
                      trailing: Text(_formatScaleFactor(textScaleFactor)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Column(
                        children: [
                          Slider.adaptive(
                            min: TextScaleController.minScaleFactor,
                            max: TextScaleController.maxScaleFactor,
                            divisions: TextScaleController.sliderDivisions,
                            label: _formatScaleFactor(textScaleFactor),
                            value: textScaleFactor,
                            onChanged: (value) {
                              TextScaleController.instance.setTextScaleFactor(
                                value,
                              );
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '紧凑 ${_formatScaleFactor(TextScaleController.minScaleFactor)}',
                                  style: textTheme.bodySmall,
                                ),
                                Text(
                                  '上限 ${_formatScaleFactor(TextScaleController.maxScaleFactor)}',
                                  style: textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: TextButton(
                          onPressed: () {
                            TextScaleController.instance.setTextScaleFactor(
                              TextScaleController.defaultScaleFactor,
                            );
                          },
                          child: const Text('恢复默认'),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text('学期', style: textTheme.titleMedium),
          const SizedBox(height: 12),
          ValueListenableBuilder<DateTime>(
            valueListenable: SemesterCalendar.instance.semesterStartDate,
            builder: (context, semesterStartDate, child) {
              return Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('当前学期开学日'),
                      subtitle: Text(
                        '${_formatDate(semesterStartDate)}（用于周次与下一节课计算）',
                      ),
                      trailing: const Icon(Icons.edit_calendar_outlined),
                      onTap: () async {
                        await _pickSemesterStartDate(
                          context,
                          semesterStartDate,
                        );
                      },
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        child: TextButton(
                          onPressed: () async {
                            await SemesterCalendar.instance
                                .resetSemesterStartDate();
                          },
                          child: const Text('恢复默认（3月2日）'),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text('网络', style: textTheme.titleMedium),
          const SizedBox(height: 12),
          ValueListenableBuilder<bool>(
            valueListenable: NetworkSettings.instance.ignoreSystemProxy,
            builder: (context, ignoreSystemProxy, child) {
              return Card(
                clipBehavior: Clip.antiAlias,
                child: SwitchListTile.adaptive(
                  title: const Text('忽略系统代理（直连）'),
                  subtitle: const Text('开启后，App 内网络请求不走系统代理'),
                  value: ignoreSystemProxy,
                  onChanged: _setIgnoreSystemProxy,
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text('设置会立即生效。', style: textTheme.bodySmall),
          const SizedBox(height: 24),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final version = snapshot.hasData
                  ? 'v${snapshot.data!.version}+${snapshot.data!.buildNumber}'
                  : '';
              return Center(
                child: Text(
                  '嘉兴大学-校园门户 $version',
                  style: textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            },
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 16),
            Text('调试', style: textTheme.titleMedium),
            const SizedBox(height: 12),
            ValueListenableBuilder<bool>(
              valueListenable: AppLogger.instance.loggingEnabled,
              builder: (context, loggingEnabled, child) {
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: SwitchListTile.adaptive(
                    title: const Text('调试日志'),
                    subtitle: const Text('开启后记录网络请求和错误日志'),
                    value: loggingEnabled,
                    onChanged: (value) {
                      AppLogger.instance.setEnabled(value);
                    },
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
