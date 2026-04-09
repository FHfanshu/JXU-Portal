class Notice {
  const Notice({
    required this.title,
    required this.url,
    required this.category,
    this.date,
  });

  final String title;
  final String url;
  final String category; // '教学' or '新闻'
  final String? date; // e.g. '2026-04-02'

  factory Notice.fromClassAdjustment(Map<String, dynamic> json) {
    return Notice(
      title: json['TKXX'] as String? ?? '',
      url: 'https://jwzx.zjxu.edu.cn/jwglxt/xtgl/index_cxDbsy.html?flag=1',
      category: '教学',
    );
  }

  factory Notice.fromNews(Map<String, dynamic> json) {
    return Notice(
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
      category: '新闻',
    );
  }
}
