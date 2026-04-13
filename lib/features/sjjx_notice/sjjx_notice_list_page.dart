import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'sjjx_notice_model.dart';
import 'sjjx_notice_service.dart';

class SjjxNoticeListPage extends StatefulWidget {
  const SjjxNoticeListPage({super.key});

  @override
  State<SjjxNoticeListPage> createState() => _SjjxNoticeListPageState();
}

class _SjjxNoticeListPageState extends State<SjjxNoticeListPage> {
  List<SjjxNotice> _allNotices = [];
  List<SjjxNotice> _filteredNotices = [];
  List<String> _categories = [];
  String? _selectedCategory;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotices();
  }

  Future<void> _loadNotices() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final notices = await SjjxNoticeService.instance.fetchAllNotices();
      if (!mounted) return;
      final cats = _extractCategories(notices);
      setState(() {
        _allNotices = notices;
        _categories = cats;
        _filteredNotices = _selectedCategory == null
            ? notices
            : notices.where((n) => n.category == _selectedCategory).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<String> _extractCategories(List<SjjxNotice> notices) {
    final seen = <String>{};
    final ordered = <String>[];
    for (final cat in SjjxNotice.categoryOrder) {
      if (notices.any((n) => n.category == cat)) {
        seen.add(cat);
        ordered.add(cat);
      }
    }
    for (final n in notices) {
      if (!seen.contains(n.category)) {
        seen.add(n.category);
        ordered.add(n.category);
      }
    }
    return ordered;
  }

  void _filterByCategory(String? category) {
    setState(() {
      if (_selectedCategory == category) {
        _selectedCategory = null;
        _filteredNotices = _allNotices;
      } else {
        _selectedCategory = category;
        _filteredNotices = category == null
            ? _allNotices
            : _allNotices.where((n) => n.category == category).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('实践通知'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadNotices),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    '加载失败',
                    style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '无法连接实践教学管理平台',
                    style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: _loadNotices,
                    child: const Text('重试'),
                  ),
                ],
              ),
            )
          : _allNotices.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.article_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '暂无通知',
                    style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                _buildCategoryFilter(cs),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadNotices,
                    child: _filteredNotices.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.4,
                                child: Center(
                                  child: Text(
                                    '该分类下暂无通知',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filteredNotices.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _NoticeCard(
                                  notice: _filteredNotices[index],
                                  colorScheme: cs,
                                  onTap: () {
                                    context.pushNamed(
                                      'external-webview',
                                      extra: {
                                        'title': _filteredNotices[index].title,
                                        'url': _filteredNotices[index].url,
                                        'emulateDingTalkEnvironment': false,
                                      },
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCategoryFilter(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildChip('全部', _selectedCategory == null, cs),
            const SizedBox(width: 8),
            ..._categories.map(
              (cat) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildChip(cat, _selectedCategory == cat, cs),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, bool selected, ColorScheme cs) {
    final colorValue = SjjxNotice.categoryColors[label];
    final chipColor = colorValue != null ? Color(colorValue) : cs.primary;

    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => _filterByCategory(selected ? null : label),
      showCheckmark: false,
      selectedColor: chipColor.withValues(alpha: 0.2),
      backgroundColor: cs.surfaceContainerLow,
      side: BorderSide(color: selected ? chipColor : cs.outlineVariant),
      labelStyle: TextStyle(
        color: selected ? chipColor : cs.onSurfaceVariant,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 13,
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final SjjxNotice notice;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _NoticeCard({
    required this.notice,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorValue = SjjxNotice.categoryColors[notice.category];
    final tagColor = colorValue != null
        ? Color(colorValue)
        : const Color(0xFF757575);
    final publishDate = (notice.date ?? '').trim();

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 0.5,
      shadowColor: Colors.black12,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tagColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  notice.category,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notice.title,
                      style: const TextStyle(fontSize: 15),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (publishDate.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '发布日期：$publishDate',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
