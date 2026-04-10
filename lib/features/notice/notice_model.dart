class Notice {
  const Notice({
    required this.title,
    required this.url,
    required this.category,
    this.date,
  });

  final String title;
  final String url;
  final String category; // e.g. '通知公告'
  final String? date; // e.g. '2026-04-02'
}
