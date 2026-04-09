class ScheduleTermContext {
  const ScheduleTermContext({required this.academicYear, required this.term});

  final int academicYear;
  final int term;

  factory ScheduleTermContext.current([DateTime? now]) {
    final date = now ?? DateTime.now();
    return ScheduleTermContext(
      academicYear: date.month < 8 ? date.year - 1 : date.year,
      term: date.month >= 2 && date.month < 8 ? 12 : 3,
    );
  }

  String get key => '$academicYear-$term';

  String get termLabel => term == 12 ? '第二学期' : '第一学期';

  ScheduleTermContext copyWith({int? academicYear, int? term}) {
    return ScheduleTermContext(
      academicYear: academicYear ?? this.academicYear,
      term: term ?? this.term,
    );
  }

  Map<String, dynamic> toJson() => {'academicYear': academicYear, 'term': term};

  factory ScheduleTermContext.fromJson(Map<String, dynamic> json) {
    return ScheduleTermContext(
      academicYear: json['academicYear'] as int? ?? 0,
      term: json['term'] as int? ?? 0,
    );
  }
}
