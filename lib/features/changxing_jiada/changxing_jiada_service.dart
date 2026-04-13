/// Stub implementation for open source release.
/// Real changxing jiada service implementation is not included.
/// 
/// This file provides type definitions and stub implementations
/// to allow the UI code to compile without the actual service logic.

import 'package:flutter/foundation.dart';

import 'changxing_jiada_model.dart';

class ChangxingAuthExpiredException implements Exception {
  ChangxingAuthExpiredException([this.message = '畅行嘉大登录已失效，请重新登录']);
  final String message;
  @override
  String toString() => message;
}

class ChangxingCasLoginException implements Exception {
  ChangxingCasLoginException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ChangxingNeedUnifiedAuthException implements Exception {
  @override
  String toString() => '一卡通登录已失效，请重新登录';
}

@immutable
class ChangxingSubmitRequest {
  const ChangxingSubmitRequest({required this.path, required this.payload});
  final String path;
  final Map<String, dynamic> payload;
}

class ChangxingJiadaService {
  ChangxingJiadaService._();
  static final ChangxingJiadaService instance = ChangxingJiadaService._();

  String? _token;
  bool _restored = false;

  bool get hasToken => (_token ?? '').isNotEmpty;

  Future<void> restoreSession() async {
    // Stub - not implemented
    _restored = true;
  }

  Future<void> logout() async {
    // Stub - not implemented
    _token = null;
  }

  Future<void> loginViaCas() async {
    // Stub - not implemented
    throw ChangxingNeedUnifiedAuthException();
  }

  Future<ChangxingUserProfile> fetchUserProfile() async {
    // Stub - not implemented
    throw ChangxingAuthExpiredException();
  }

  Future<int> fetchUnreadCount() async {
    // Stub - not implemented
    return 0;
  }

  Future<List<ChangxingApplication>> fetchApplications({
    int page = 1,
    int pageSize = 20,
    int status = 999,
  }) async {
    // Stub - not implemented
    return [];
  }

  Future<ChangxingApplicationDetail> fetchApplicationDetail(int id) async {
    // Stub - not implemented
    throw ChangxingAuthExpiredException();
  }

  Future<List<ChangxingAreaNode>> fetchAreaChildren(int parentId) async {
    // Stub - not implemented
    return [];
  }

  Future<List<ChangxingAreaNode>> fetchAreaParents(int areaId) async {
    // Stub - not implemented
    return [];
  }

  Future<bool> fetchFanxiaoEnableFlag() async {
    // Stub - not implemented
    return false;
  }

  Future<String?> fetchImageByMd5(String md5) async {
    // Stub - not implemented
    return null;
  }

  Future<ChangxingUploadResult> uploadAttachment(
    String filePath,
    String fileName,
  ) async {
    // Stub - not implemented
    throw ChangxingAuthExpiredException();
  }

  Future<void> submitLeaveRequest({
    int? id,
    required DateTime startTime,
    required DateTime endTime,
    required String descr,
    required int toAreaCode,
    required String toAddr,
    required String emergencyContact,
    required String emergencyPhone,
    required String userPhone,
    required List<String> trafficTools,
    String img = '',
    String annex = '',
  }) async {
    // Stub - not implemented
    throw ChangxingAuthExpiredException();
  }

  Future<void> submitLeaveSchool({
    int? id,
    required DateTime startTime,
    required DateTime endTime,
    required String descr,
    required int toAreaCode,
    required String toAddr,
    required String emergencyContact,
    required String emergencyPhone,
    required String userPhone,
    required List<String> trafficTools,
  }) async {
    // Stub - not implemented
    throw ChangxingAuthExpiredException();
  }

  Future<void> submitBackSchool({
    int? id,
    required String userPhone,
    required DateTime startTime,
    required String trafficTool,
    required String trafficDetail,
    required String nativePlace,
    required int fromAreaCode,
    required String emergencyContact,
    required String emergencyPhone,
    required int backStatus,
    required String notBackReason,
    String img = '',
    String annex = '',
  }) async {
    // Stub - not implemented
    throw ChangxingAuthExpiredException();
  }

  Future<void> submitOvertime({int? id, required String descr}) async {
    // Stub - not implemented
    throw ChangxingAuthExpiredException();
  }

  @visibleForTesting
  static ChangxingSubmitRequest buildLeaveRequestSubmitRequest({
    int? id,
    required DateTime startTime,
    required DateTime endTime,
    required String descr,
    required int toAreaCode,
    required String toAddr,
    required String emergencyContact,
    required String emergencyPhone,
    required String userPhone,
    required List<String> trafficTools,
    String img = '',
    String annex = '',
  }) {
    final payload = <String, dynamic>{
      'startTime': startTime,
      'endTime': endTime,
      'descr': descr,
      'toAreaCode': toAreaCode,
      'toAddr': toAddr,
      'emergencyContact': emergencyContact,
      'emergencyPhone': emergencyPhone,
      'userPhone': userPhone,
      'trafficTool': trafficTools.join(','),
      'img': img,
      'annex': annex,
      'type': 1,
    };
    if (id != null) payload['id'] = id;
    return ChangxingSubmitRequest(
      path: id == null ? '/approvalForm/qingjia/add' : '/approvalForm/edit',
      payload: payload,
    );
  }

  @visibleForTesting
  static ChangxingSubmitRequest buildLeaveSchoolSubmitRequest({
    int? id,
    required DateTime startTime,
    required DateTime endTime,
    required String descr,
    required int toAreaCode,
    required String toAddr,
    required String emergencyContact,
    required String emergencyPhone,
    required String userPhone,
    required List<String> trafficTools,
  }) {
    final payload = <String, dynamic>{
      'startTime': startTime,
      'endTime': endTime,
      'descr': descr,
      'toAreaCode': toAreaCode,
      'toAddr': toAddr,
      'emergencyContact': emergencyContact,
      'emergencyPhone': emergencyPhone,
      'userPhone': userPhone,
      'trafficTool': trafficTools.join(','),
      'type': 2,
    };
    if (id != null) payload['id'] = id;
    return ChangxingSubmitRequest(
      path: id == null ? '/approvalForm/lixiao/add' : '/approvalForm/edit',
      payload: payload,
    );
  }

  @visibleForTesting
  static ChangxingSubmitRequest buildBackSchoolSubmitRequest({
    int? id,
    required String userPhone,
    required DateTime startTime,
    required String trafficTool,
    required String trafficDetail,
    required String nativePlace,
    required int fromAreaCode,
    required String emergencyContact,
    required String emergencyPhone,
    required int backStatus,
    required String notBackReason,
    String img = '',
    String annex = '',
  }) {
    final payload = <String, dynamic>{
      'userPhone': userPhone,
      'startTime': startTime,
      'trafficTool': trafficTool,
      'trafficDetail': trafficDetail,
      'nativePlace': nativePlace,
      'fromAreaCode': fromAreaCode,
      'emergencyContact': emergencyContact,
      'emergencyPhone': emergencyPhone,
      'backStatus': backStatus,
      'notBackReason': notBackReason,
      'img': img,
      'annex': annex,
      'type': 3,
    };
    if (id != null) payload['id'] = id;
    return ChangxingSubmitRequest(
      path: id == null ? '/approvalForm/fanxiao/add' : '/approvalForm/edit',
      payload: payload,
    );
  }

  @visibleForTesting
  static ChangxingSubmitRequest buildOvertimeSubmitRequest({
    int? id,
    required String descr,
  }) {
    final payload = <String, dynamic>{'type': 4, 'descr': descr};
    if (id != null) payload['id'] = id;
    return ChangxingSubmitRequest(
      path: '/approvalForm/overtime/add',
      payload: payload,
    );
  }

  @visibleForTesting
  static bool isUnifiedAuthLoginFormResponse(String url, String html) {
    return false;
  }
}