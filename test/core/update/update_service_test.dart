import 'package:flutter_test/flutter_test.dart';

import 'package:jiaxing_university_portal/core/update/update_model.dart';
import 'package:jiaxing_university_portal/core/update/update_service.dart';

void main() {
  setUp(() {
    UpdateService.instance.debugReset();
  });

  tearDown(() {
    UpdateService.instance.debugReset();
  });

  test('returns release when github version is newer', () async {
    final release = AppRelease(
      version: '0.1.3',
      changelog: '',
      downloadUrl: '',
      releaseUrl: 'https://example.com',
      publishedAt: DateTime(2026),
    );
    UpdateService.instance.debugReleaseProvider = () async => release;
    UpdateService.instance.debugCurrentVersionProvider = () async => '0.1.2';

    final result = await UpdateService.instance.checkForUpdate();

    expect(result, same(release));
  });

  test('returns null when current version is already latest', () async {
    final release = AppRelease(
      version: '0.1.3',
      changelog: '',
      downloadUrl: '',
      releaseUrl: 'https://example.com',
      publishedAt: DateTime(2026),
    );
    UpdateService.instance.debugReleaseProvider = () async => release;
    UpdateService.instance.debugCurrentVersionProvider = () async => '0.1.3';

    final result = await UpdateService.instance.checkForUpdate();

    expect(result, isNull);
  });

  test('throws when release loading fails', () async {
    UpdateService.instance.debugReleaseProvider = () async {
      throw StateError('failed');
    };
    UpdateService.instance.debugCurrentVersionProvider = () async => '0.1.0';

    expect(UpdateService.instance.checkForUpdate(), throwsStateError);
  });

  test('prefers gitee release when mirror is available', () async {
    final giteeRelease = AppRelease(
      version: '0.1.4',
      changelog: '',
      downloadUrl: 'https://gitee.com/example.apk',
      releaseUrl: 'https://gitee.com/example',
      publishedAt: DateTime(2026),
    );
    var githubRequested = false;
    UpdateService.instance.debugGiteeReleaseProvider = () async => giteeRelease;
    UpdateService.instance.debugGitHubReleaseProvider = () async {
      githubRequested = true;
      return giteeRelease;
    };

    final result = await UpdateService.instance.fetchLatestRelease();

    expect(result, same(giteeRelease));
    expect(githubRequested, isFalse);
  });

  test('falls back to github when gitee mirror fails', () async {
    final githubRelease = AppRelease(
      version: '0.2.0',
      changelog: '',
      downloadUrl: 'https://github.com/example.apk',
      releaseUrl: 'https://github.com/example',
      publishedAt: DateTime(2026),
    );
    UpdateService.instance.debugGiteeReleaseProvider = () async {
      throw StateError('gitee failed');
    };
    UpdateService.instance.debugGitHubReleaseProvider = () async =>
        githubRelease;

    final result = await UpdateService.instance.fetchLatestRelease();

    expect(result, same(githubRelease));
  });
}
