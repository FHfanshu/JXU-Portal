import 'package:flutter_test/flutter_test.dart';

import 'package:jiaxing_university_portal/core/update/update_checker.dart';
import 'package:jiaxing_university_portal/core/update/update_model.dart';
import 'package:jiaxing_university_portal/core/update/update_service.dart';

void main() {
  setUp(() {
    UpdateService.instance.debugReset();
    UpdateChecker.instance.debugReset();
  });

  tearDown(() {
    UpdateService.instance.debugReset();
    UpdateChecker.instance.debugReset();
  });

  test('stores available release when update is found', () async {
    final release = AppRelease(
      version: '0.1.3',
      changelog: '',
      downloadUrl: '',
      releaseUrl: 'https://example.com',
      publishedAt: DateTime(2026),
    );
    UpdateService.instance.debugReleaseProvider = () async => release;
    UpdateService.instance.debugCurrentVersionProvider = () async => '0.1.0';

    final result = await UpdateChecker.instance.check();

    expect(result.status, UpdateCheckStatus.updateAvailable);
    expect(result.release, same(release));
    expect(UpdateChecker.instance.availableRelease.value, same(release));
    expect(UpdateChecker.instance.isChecking.value, isFalse);
  });

  test('clears available release when already up to date', () async {
    final staleRelease = AppRelease(
      version: '0.1.2',
      changelog: '',
      downloadUrl: '',
      releaseUrl: 'https://example.com',
      publishedAt: DateTime(2026),
    );
    UpdateChecker.instance.availableRelease.value = staleRelease;
    UpdateService.instance.debugReleaseProvider = () async => staleRelease;
    UpdateService.instance.debugCurrentVersionProvider = () async => '0.1.2';

    final result = await UpdateChecker.instance.check();

    expect(result.status, UpdateCheckStatus.upToDate);
    expect(UpdateChecker.instance.availableRelease.value, isNull);
  });

  test('keeps previous release when checking fails', () async {
    final existingRelease = AppRelease(
      version: '0.1.3',
      changelog: '',
      downloadUrl: '',
      releaseUrl: 'https://example.com',
      publishedAt: DateTime(2026),
    );
    UpdateChecker.instance.availableRelease.value = existingRelease;
    UpdateService.instance.debugReleaseProvider = () async {
      throw StateError('failed');
    };
    UpdateService.instance.debugCurrentVersionProvider = () async => '0.1.0';

    final result = await UpdateChecker.instance.check();

    expect(result.status, UpdateCheckStatus.error);
    expect(
      UpdateChecker.instance.availableRelease.value,
      same(existingRelease),
    );
    expect(UpdateChecker.instance.isChecking.value, isFalse);
  });
}
