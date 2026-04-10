class SjjxNotice {
  const SjjxNotice({
    required this.title,
    required this.url,
    required this.category,
    this.date,
  });

  final String title;
  final String url;
  final String category;
  final String? date;

  static const categoryOrder = ['学科竞赛', '毕业设计', '实验教学', '实践平台', '创新训练'];

  static const categoryColors = <String, int>{
    '学科竞赛': 0xFFFF6F00,
    '毕业设计': 0xFF7B1FA2,
    '实验教学': 0xFF00897B,
    '实践平台': 0xFF1565C0,
    '创新训练': 0xFF2E7D32,
  };
}
