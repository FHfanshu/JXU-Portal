import 'package:flutter_test/flutter_test.dart';

import 'package:jiaxing_university_portal/core/logging/app_logger.dart';

void main() {
  setUp(() {
    AppLogger.instance.debugReset();
  });

  test('scrubs session password phone and student id', () {
    AppLogger.instance.log(
      LogLevel.info,
      LogCategory.auth,
      'sid=2025000123 password=secret mm=token JSESSIONID=abcdef 13812345678',
      force: true,
    );

    final entry = AppLogger.instance.entries.single;
    expect(entry.message, contains('password=[REDACTED]'));
    expect(entry.message, contains('mm=[REDACTED]'));
    expect(entry.message, contains('JSESSIONID=[REDACTED]'));
    expect(entry.message, isNot(contains('13812345678')));
    expect(entry.message, isNot(contains('2025000123')));
  });

  test('formats entries with app prefix for filtering', () {
    AppLogger.instance.log(
      LogLevel.info,
      LogCategory.network,
      'hello',
      force: true,
    );

    final entry = AppLogger.instance.entries.single;
    expect(entry.formatted, startsWith('[JXU] ['));
    expect(entry.formatted, contains(' [INFO] [network] hello'));
  });

  test('respects minimum level and category unless forced', () {
    AppLogger.instance.config.value = const LogConfig.defaults().copyWith(
      minimumLevel: LogLevel.warn,
      enabledCategories: {LogCategory.network},
    );

    AppLogger.instance.log(LogLevel.info, LogCategory.network, 'skip me');
    AppLogger.instance.log(LogLevel.warn, LogCategory.ui, 'skip category');
    AppLogger.instance.log(LogLevel.warn, LogCategory.network, 'keep me');
    AppLogger.instance.log(
      LogLevel.info,
      LogCategory.ui,
      'forced',
      force: true,
    );

    expect(AppLogger.instance.entries.map((entry) => entry.message), [
      'keep me',
      'forced',
    ]);
  });

  test('always keeps error logs even when category disabled', () {
    AppLogger.instance.config.value = const LogConfig.defaults().copyWith(
      minimumLevel: LogLevel.error,
      enabledCategories: {LogCategory.network},
    );

    AppLogger.instance.log(LogLevel.error, LogCategory.ui, 'must keep');

    expect(AppLogger.instance.entries.single.message, 'must keep');
  });

  test('evicts oldest entries when buffer exceeds capacity', () {
    for (var index = 0; index < 505; index++) {
      AppLogger.instance.log(
        LogLevel.info,
        LogCategory.general,
        'entry-$index',
        force: true,
      );
    }

    expect(AppLogger.instance.entries, hasLength(500));
    expect(AppLogger.instance.entries.first.message, 'entry-5');
    expect(AppLogger.instance.entries.last.message, 'entry-504');
  });
}
