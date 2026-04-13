/// Stub implementation for open source release.
/// Real grade fetching implementation is not included.

import 'grades_model.dart';

class GradesService {
  GradesService._();
  static final GradesService instance = GradesService._();

  Future<List<GradeEntry>> fetchGrades(String studentId) async {
    // Stub - not implemented in open source version
    return [];
  }
}