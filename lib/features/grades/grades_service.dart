import 'package:dio/dio.dart';

import '../../core/network/dio_client.dart';
import 'grades_model.dart';

class GradesService {
  GradesService._();
  static final GradesService instance = GradesService._();

  Future<List<GradeEntry>> fetchGrades(String studentId) async {
    await DioClient.instance.ensureInitialized();
    final dio = DioClient.instance.dio;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final resp = await dio.post<Map<String, dynamic>>(
      '/cjcx/cjcx_cxDgXscj.html',
      queryParameters: {
        'doType': 'query',
        'gnmkdm': 'N305005',
        'su': studentId,
      },
      data:
          'xnm=&xqm=&_search=false&nd=$ts'
          '&queryModel.showCount=100&queryModel.currentPage=1'
          '&queryModel.sortName=&queryModel.sortOrder=asc&time=1',
      options: Options(contentType: 'application/x-www-form-urlencoded'),
    );

    final items = resp.data?['items'] as List<dynamic>? ?? [];
    return items.cast<Map<String, dynamic>>().map(GradeEntry.fromJson).toList();
  }
}
