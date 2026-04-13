class ChangxingFormValidator {
  ChangxingFormValidator._();

  static final RegExp _phoneRegex = RegExp(r'^1[3-9]\d{9}$');

  static bool isPhone(String value) {
    return _phoneRegex.hasMatch(value.trim());
  }

  static bool isBlank(String value) {
    return value.trim().isEmpty;
  }

  static String? validateContactName(String value) {
    final text = value.trim();
    if (text.isEmpty) return '紧急联系人为空';
    if (text.length < 2) return '紧急联系人姓名过短';
    if (text.length >= 10) return '紧急联系人姓名过长';
    return null;
  }

  static String? validateReason(
    String value, {
    required String emptyMessage,
    required String tooLongMessage,
    int maxLength = 200,
  }) {
    final text = value.trim();
    if (text.isEmpty) return emptyMessage;
    if (text.length > maxLength) return tooLongMessage;
    return null;
  }

  static String? validateDateOrder(DateTime startTime, DateTime endTime) {
    if (!endTime.isAfter(startTime)) {
      return '结束时间需大于开始时间';
    }
    return null;
  }

  static String? validateNotBackReason(String value, {int minLength = 10}) {
    final text = value.trim();
    if (text.length < minLength) {
      return '请填写无法报到原因，并不少于10个字';
    }
    return null;
  }
}
