class AppRelease {
  const AppRelease({
    required this.version,
    required this.changelog,
    required this.downloadUrl,
    required this.releaseUrl,
    required this.publishedAt,
  });

  final String version;
  final String changelog;
  final String downloadUrl;
  final String releaseUrl;
  final DateTime publishedAt;

  bool get hasDownloadUrl => downloadUrl.isNotEmpty;

  String get launchUrl => hasDownloadUrl ? downloadUrl : releaseUrl;

  factory AppRelease.fromGitHubJson(Map<String, dynamic> json) {
    return _fromReleaseJson(
      json,
      sourceName: 'GitHub',
      publishedAtText: (json['published_at'] as String? ?? '').trim(),
    );
  }

  factory AppRelease.fromGiteeJson(
    Map<String, dynamic> json, {
    required String owner,
    required String repo,
  }) {
    final rawTag = (json['tag_name'] as String? ?? '').trim();
    final fallbackReleaseUrl = rawTag.isEmpty
        ? ''
        : 'https://gitee.com/$owner/$repo/releases/tag/$rawTag';
    final publishedAtText =
        (json['published_at'] as String? ?? json['created_at'] as String? ?? '')
            .trim();
    return _fromReleaseJson(
      json,
      sourceName: 'Gitee',
      fallbackReleaseUrl: fallbackReleaseUrl,
      publishedAtText: publishedAtText,
    );
  }

  static AppRelease _fromReleaseJson(
    Map<String, dynamic> json, {
    required String sourceName,
    required String publishedAtText,
    String fallbackReleaseUrl = '',
  }) {
    final version = normalizeVersion(
      (json['tag_name'] as String? ?? '').trim(),
    );
    final releaseUrl = (json['html_url'] as String? ?? fallbackReleaseUrl)
        .trim();
    final changelog = (json['body'] as String? ?? '').trim();
    final publishedAt = DateTime.tryParse(publishedAtText);

    if (version.isEmpty) {
      throw FormatException('$sourceName release 缺少 tag_name。');
    }
    if (releaseUrl.isEmpty) {
      throw FormatException('$sourceName release 缺少 html_url。');
    }

    return AppRelease(
      version: version,
      changelog: changelog,
      downloadUrl: _pickApkDownloadUrl(json['assets']),
      releaseUrl: releaseUrl,
      publishedAt: publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static String _pickApkDownloadUrl(dynamic assets) {
    if (assets is! List) return '';
    for (final asset in assets) {
      if (asset is! Map) continue;
      final item = Map<String, dynamic>.from(asset);
      final name = (item['name'] as String? ?? '').trim().toLowerCase();
      final contentType = (item['content_type'] as String? ?? '')
          .trim()
          .toLowerCase();
      final assetUrl =
          (item['browser_download_url'] as String? ??
                  item['url'] as String? ??
                  '')
              .trim();
      if (assetUrl.isEmpty) continue;
      if (name.endsWith('.apk') ||
          contentType == 'application/vnd.android.package-archive') {
        return assetUrl;
      }
    }
    return '';
  }

  bool isNewerThan(String currentVersion) {
    final latestSegments = tryParseVersionSegments(version);
    final currentSegments = tryParseVersionSegments(
      normalizeVersion(currentVersion),
    );
    if (latestSegments == null || currentSegments == null) {
      return version.compareTo(normalizeVersion(currentVersion)) > 0;
    }

    final maxLength = latestSegments.length > currentSegments.length
        ? latestSegments.length
        : currentSegments.length;
    for (var index = 0; index < maxLength; index++) {
      final latest = index < latestSegments.length ? latestSegments[index] : 0;
      final current = index < currentSegments.length
          ? currentSegments[index]
          : 0;
      if (latest == current) continue;
      return latest > current;
    }
    return false;
  }

  static String normalizeVersion(String value) {
    var normalized = value.trim();
    if (normalized.startsWith('v') || normalized.startsWith('V')) {
      normalized = normalized.substring(1);
    }
    final plusIndex = normalized.indexOf('+');
    if (plusIndex >= 0) {
      normalized = normalized.substring(0, plusIndex);
    }
    return normalized.trim();
  }

  static List<int>? tryParseVersionSegments(String value) {
    if (value.isEmpty) return null;
    final result = <int>[];
    for (final part in value.split('.')) {
      final parsed = int.tryParse(part.trim());
      if (parsed == null) return null;
      result.add(parsed);
    }
    return result.isEmpty ? null : result;
  }
}
