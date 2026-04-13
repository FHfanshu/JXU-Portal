import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import 'dorm_electricity_service.dart';

class DormElectricityPage extends StatefulWidget {
  const DormElectricityPage({super.key});

  @override
  State<DormElectricityPage> createState() => _DormElectricityPageState();
}

class _DormElectricityPageState extends State<DormElectricityPage> {
  final _service = DormElectricityService.instance;
  double? _electricity;
  bool _loading = true;
  bool _hasConfig = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(forceRefresh: true);
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() => _loading = true);
    _hasConfig = await _service.hasRoomConfig();
    if (_hasConfig) {
      _electricity = await _service.fetchElectricity(
        forceRefresh: forceRefresh,
      );
      _error = _service.lastError;
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('寝室电费'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '选择寝室',
            onPressed: () async {
              await context.pushNamed('dorm-electricity-settings');
              _load(forceRefresh: true);
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_hasConfig
          ? _buildNoConfig(context, cs)
          : RefreshIndicator(
              onRefresh: () => _load(forceRefresh: true),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_error != null) ...[
                    _buildErrorBanner(cs),
                    const SizedBox(height: 16),
                  ],
                  _buildMainCard(context, cs),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _load(forceRefresh: true),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('刷新'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildNoConfig(BuildContext context, ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.home_outlined,
                size: 36,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '尚未配置寝室',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '选择寝室后即可查看剩余电量',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () async {
                await context.pushNamed('dorm-electricity-settings');
                _load(forceRefresh: true);
              },
              icon: const Icon(Icons.add_home_outlined, size: 18),
              label: const Text('去选择寝室'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_outlined, size: 18, color: cs.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(switch (_error) {
              '数据解析失败' => '数据解析失败，请刷新重试',
              final message? => message,
              _ => '请确认已连接校园网络',
            }, style: TextStyle(fontSize: 13, color: cs.onErrorContainer)),
          ),
        ],
      ),
    );
  }

  Widget _buildMainCard(BuildContext context, ColorScheme cs) {
    final value = _service.formatElectricity(_electricity);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final updatedAt = _service.lastUpdated;
    final updatedAtText = updatedAt == null
        ? '未刷新'
        : '${updatedAt.hour.toString().padLeft(2, '0')}:${updatedAt.minute.toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerLowest : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.bolt,
                  color: AppColors.success,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '剩余电量',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '上次更新 $updatedAtText',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.bold,
                  color: _electricity != null && _electricity! < 10
                      ? cs.error
                      : AppColors.success,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '度',
                  style: TextStyle(fontSize: 18, color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
          if (_electricity != null && _electricity! < 10) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: cs.onErrorContainer,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '电量不足，请及时充值',
                    style: TextStyle(fontSize: 12, color: cs.onErrorContainer),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
