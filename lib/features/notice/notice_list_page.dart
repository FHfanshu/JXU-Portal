import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'notice_model.dart';
import 'notice_service.dart';

class NoticeListPage extends StatefulWidget {
  const NoticeListPage({super.key});

  @override
  State<NoticeListPage> createState() => _NoticeListPageState();
}

class _NoticeListPageState extends State<NoticeListPage> {
  List<Notice> _notices = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadNotices();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || !_hasMore) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll - 200) {
      _loadMore();
    }
  }

  Future<void> _loadNotices() async {
    setState(() => _loading = true);
    _currentPage = 1;
    final notices = await NoticeService.instance.fetchNotices();
    if (!mounted) return;
    setState(() {
      _notices = notices;
      _loading = false;
      _hasMore = true;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    _currentPage++;
    final more = await NoticeService.instance.fetchMoreNews(_currentPage);
    if (!mounted) return;
    setState(() {
      if (more.isEmpty) {
        _hasMore = false;
      } else {
        _notices.addAll(more);
      }
      _loadingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('校园资讯'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadNotices),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notices.isEmpty
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
                    '暂无资讯',
                    style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadNotices,
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                itemCount: _notices.length + (_hasMore ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (index >= _notices.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  final notice = _notices[index];
                  return _NoticeCard(
                    notice: notice,
                    colorScheme: cs,
                    onTap: () {
                      context.pushNamed(
                        'news-detail',
                        extra: {'title': notice.title, 'url': notice.url},
                      );
                    },
                  );
                },
              ),
            ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final Notice notice;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _NoticeCard({
    required this.notice,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isTeaching = notice.category == '教学';
    final tagColor = isTeaching ? Colors.red : const Color(0xFF1565C0);
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
