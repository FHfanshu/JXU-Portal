import 'package:flutter_test/flutter_test.dart';

import 'package:jiaxing_university_portal/core/update/update_model.dart';

void main() {
  test('parses github release payload and picks apk asset', () {
    final release = AppRelease.fromGitHubJson({
      'tag_name': 'v0.1.3',
      'html_url': 'https://github.com/FHfanshu/JXU-Portal/releases/tag/v0.1.3',
      'body': '更新内容',
      'published_at': '2026-04-09T17:05:48Z',
      'assets': [
        {
          'name': 'JXU-Portal-v0.1.3.apk',
          'content_type': 'application/vnd.android.package-archive',
          'browser_download_url':
              'https://github.com/FHfanshu/JXU-Portal/releases/download/v0.1.3/JXU-Portal-v0.1.3.apk',
        },
      ],
    });

    expect(release.version, '0.1.3');
    expect(release.changelog, '更新内容');
    expect(release.hasDownloadUrl, isTrue);
    expect(release.launchUrl, endsWith('.apk'));
  });

  test('parses gitee release payload and falls back to tag page', () {
    final release = AppRelease.fromGiteeJson(
      {
        'tag_name': 'v0.2.0',
        'body': '镜像更新内容',
        'created_at': '2026-04-10T23:30:00+08:00',
        'assets': [
          {
            'name': 'JXU-Portal-v0.2.0.apk',
            'browser_download_url':
                'https://gitee.com/fhfanshu/JXU-Portal/releases/download/v0.2.0/JXU-Portal-v0.2.0.apk',
          },
        ],
      },
      owner: 'fhfanshu',
      repo: 'JXU-Portal',
    );

    expect(release.version, '0.2.0');
    expect(release.changelog, '镜像更新内容');
    expect(
      release.releaseUrl,
      'https://gitee.com/fhfanshu/JXU-Portal/releases/tag/v0.2.0',
    );
    expect(
      release.downloadUrl,
      'https://gitee.com/fhfanshu/JXU-Portal/releases/download/v0.2.0/JXU-Portal-v0.2.0.apk',
    );
  });

  test('treats larger semantic version as newer', () {
    final release = AppRelease(
      version: '0.1.3',
      changelog: '',
      downloadUrl: '',
      releaseUrl: 'https://example.com',
      publishedAt: DateTime(2026),
    );

    expect(release.isNewerThan('0.1.2'), isTrue);
    expect(release.isNewerThan('0.1.3'), isFalse);
    expect(release.isNewerThan('0.2.0'), isFalse);
  });

  test('ignores build metadata while comparing versions', () {
    final release = AppRelease(
      version: '1.2.4',
      changelog: '',
      downloadUrl: '',
      releaseUrl: 'https://example.com',
      publishedAt: DateTime(2026),
    );

    expect(release.isNewerThan('1.2.3+9'), isTrue);
    expect(AppRelease.normalizeVersion('v1.2.3+9'), '1.2.3');
  });
}
