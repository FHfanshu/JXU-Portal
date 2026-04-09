import 'package:flutter/material.dart';

import '../../core/auth/zhengfang_auth.dart';
import '../../shared/widgets/login_widget.dart';
import 'grades_model.dart';
import 'grades_service.dart';

class GradesPage extends StatefulWidget {
  const GradesPage({super.key});

  @override
  State<GradesPage> createState() => _GradesPageState();
}

class _GradesPageState extends State<GradesPage> {
  bool _loggedIn = false;
  bool _loading = false;
  String? _error;
  List<GradeEntry> _grades = [];

  @override
  void initState() {
    super.initState();
    _loggedIn = ZhengfangAuth.instance.isLoggedIn;
    if (_loggedIn) _fetchGrades();
  }

  Future<void> _fetchGrades() async {
    final studentId = ZhengfangAuth.instance.currentStudentId ?? '';
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final grades = await GradesService.instance.fetchGrades(studentId);
      if (mounted) setState(() => _grades = grades);
    } catch (e) {
      if (mounted) setState(() => _error = '获取成绩失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onLoginSuccess() {
    setState(() => _loggedIn = true);
    _fetchGrades();
  }

  // ── GPA summary ─────────────────────────────────────────────────────────────

  double get _weightedGpa {
    double totalPoints = 0;
    double totalCredits = 0;
    for (final g in _grades) {
      if (g.gpaPoints > 0) {
        totalPoints += g.gpaPoints * g.credits;
        totalCredits += g.credits;
      }
    }
    return totalCredits > 0 ? totalPoints / totalCredits : 0;
  }

  double get _totalCredits =>
      _grades.fold(0.0, (sum, g) => sum + (g.gpaPoints > 0 ? g.credits : 0));

  // ── Grade color ──────────────────────────────────────────────────────────────

  Color _gradeColor(String percentageScore) {
    final score = double.tryParse(percentageScore) ?? 0;
    if (score >= 90) return Colors.green.shade600;
    if (score >= 75) return Colors.blue.shade600;
    if (score >= 60) return Colors.orange.shade700;
    return Colors.red.shade600;
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('成绩查询'),
        actions: _loggedIn
            ? [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _fetchGrades,
                ),
              ]
            : null,
      ),
      body: _loggedIn ? _buildGradesBody() : _buildLoginBody(),
    );
  }

  Widget _buildLoginBody() =>
      LoginWidget(onLoginSuccess: _onLoginSuccess);

  Widget _buildGradesBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _fetchGrades, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_grades.isEmpty) {
      return const Center(child: Text('暂无成绩数据'));
    }

    // Group by semester
    final Map<String, List<GradeEntry>> grouped = {};
    for (final g in _grades) {
      final key = '${g.academicYear} 第${g.semester}学期';
      grouped.putIfAbsent(key, () => []).add(g);
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _SummaryCard(
          totalCredits: _totalCredits,
          weightedGpa: _weightedGpa,
        ),
        const SizedBox(height: 12),
        for (final entry in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              entry.key,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          for (final grade in entry.value)
            _GradeCard(grade: grade, gradeColor: _gradeColor),
        ],
      ],
    );
  }
}

// ── Summary Card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard(
      {required this.totalCredits, required this.weightedGpa});
  final double totalCredits;
  final double weightedGpa;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(
              label: '已获学分',
              value: totalCredits.toStringAsFixed(1),
              color: cs.onPrimaryContainer,
            ),
            _StatItem(
              label: '加权绩点',
              value: weightedGpa.toStringAsFixed(2),
              color: cs.onPrimaryContainer,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}

// ── Grade Card ────────────────────────────────────────────────────────────────

class _GradeCard extends StatelessWidget {
  const _GradeCard({required this.grade, required this.gradeColor});
  final GradeEntry grade;
  final Color Function(String) gradeColor;

  @override
  Widget build(BuildContext context) {
    final color = gradeColor(grade.percentageScore);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    grade.courseName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${grade.credits} 学分 · ${grade.assessmentMethod} · ${grade.examType}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    grade.grade,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'GPA ${grade.gpaPoints.toStringAsFixed(1)}',
                  style: TextStyle(fontSize: 11, color: color),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
