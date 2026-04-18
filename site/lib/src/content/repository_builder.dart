import 'models.dart';

class RepositoryBuilderConfig {
  const RepositoryBuilderConfig({
    required this.siteUrl,
    required this.siteBasePath,
    required this.sourceName,
    required this.sourceIdentifier,
    required this.sourceSubtitle,
    required this.sourceWebsite,
    required this.tintColor,
    required this.appName,
    required this.appSubtitle,
    required this.appDescription,
    required this.developerName,
    required this.bundleIdentifier,
    required this.minOsVersion,
    required this.buildVersion,
    required this.iconPath,
    required this.screenshotPaths,
    required this.assetNamePattern,
  });

  factory RepositoryBuilderConfig.fromEnvironment(
    Map<String, String> environment,
  ) {
    final siteUrl = environment['SITE_URL'] ?? 'https://novella.celia.sh';
    final rawScreenshotPaths = environment['REPOSITORY_SCREENSHOT_PATHS'];

    return RepositoryBuilderConfig(
      siteUrl: siteUrl,
      siteBasePath: environment['SITE_BASE_PATH'] ?? '/',
      sourceName: environment['REPOSITORY_NAME'] ?? 'Novella Repository',
      sourceIdentifier:
          environment['REPOSITORY_IDENTIFIER'] ?? 'sh.celia.novella.repository',
      sourceSubtitle:
          environment['REPOSITORY_SUBTITLE'] ?? 'Repository for Novella',
      sourceWebsite: environment['REPOSITORY_WEBSITE'] ?? siteUrl,
      tintColor: environment['REPOSITORY_TINT_COLOR'] ?? '#f59393',
      appName: environment['REPOSITORY_APP_NAME'] ?? 'Novella',
      appSubtitle: environment['REPOSITORY_APP_SUBTITLE'] ?? '轻书架第三方客户端',
      appDescription:
          environment['REPOSITORY_APP_DESCRIPTION'] ??
          '基于 Flutter 构建的轻小说阅读器，提供纯净的界面和阅读体验。',
      developerName: environment['REPOSITORY_DEVELOPER_NAME'] ?? 'Kanscape',
      bundleIdentifier:
          environment['REPOSITORY_BUNDLE_IDENTIFIER'] ?? 'sh.celia.novella',
      minOsVersion: environment['REPOSITORY_MIN_OS_VERSION'] ?? '13.0',
      buildVersion: environment['REPOSITORY_BUILD_VERSION'],
      iconPath:
          environment['REPOSITORY_ICON_PATH'] ??
          'assets/brand/repository-icon.png',
      screenshotPaths: _parseScreenshotPaths(rawScreenshotPaths),
      assetNamePattern:
          environment['REPOSITORY_ASSET_NAME_PATTERN'] ?? r'\.ipa$',
    );
  }

  final String siteUrl;
  final String siteBasePath;
  final String sourceName;
  final String sourceIdentifier;
  final String sourceSubtitle;
  final String sourceWebsite;
  final String tintColor;
  final String appName;
  final String appSubtitle;
  final String appDescription;
  final String developerName;
  final String bundleIdentifier;
  final String minOsVersion;
  final String? buildVersion;
  final String iconPath;
  final List<String> screenshotPaths;
  final String assetNamePattern;

  static List<String> _parseScreenshotPaths(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) {
      return const [
        'assets/screenshots/repository-detail-light.png',
        'assets/screenshots/repository-detail-dark.png',
        'assets/screenshots/repository-reader-light.png',
        'assets/screenshots/repository-reader-dark.png',
        'assets/screenshots/repository-settings-light.png',
        'assets/screenshots/repository-settings-dark.png',
      ];
    }

    return rawValue
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}

class RepositoryBuilder {
  const RepositoryBuilder({required this.config});

  final RepositoryBuilderConfig config;

  Map<String, dynamic> build(SiteData siteData) {
    final ipaAsset = selectIpaAsset(siteData.latestRelease.assets);
    if (ipaAsset == null) {
      throw StateError(
        'Latest release ${siteData.latestRelease.tagName} does not contain a usable IPA asset.',
      );
    }

    final appIconUrl = buildSiteAssetUrl(config.iconPath);
    final screenshotUrls = config.screenshotPaths
        .map(buildSiteAssetUrl)
        .toList(growable: false);
    final version = normalizeVersion(siteData.latestRelease);
    final buildVersion = config.buildVersion?.trim().isNotEmpty == true
        ? config.buildVersion!.trim()
        : version;
    final versionDescription =
        siteData.latestRelease.bodyMarkdown.trim().isEmpty
        ? siteData.latestRelease.excerpt
        : siteData.latestRelease.bodyMarkdown;

    return {
      'name': config.sourceName,
      'identifier': config.sourceIdentifier,
      'subtitle': config.sourceSubtitle,
      'website': config.sourceWebsite,
      'tintColor': config.tintColor,
      'featuredApps': [config.bundleIdentifier],
      'apps': [
        {
          'name': config.appName,
          'bundleIdentifier': config.bundleIdentifier,
          'developerName': config.developerName,
          'subtitle': config.appSubtitle,
          'localizedDescription': config.appDescription,
          'iconURL': appIconUrl,
          'tintColor': config.tintColor,
          'screenshotURLs': screenshotUrls,
          'versions': [
            {
              'version': version,
              'buildVersion': buildVersion,
              'date': siteData.latestRelease.publishedAt
                  .toUtc()
                  .toIso8601String(),
              'localizedDescription': versionDescription,
              'minOSVersion': config.minOsVersion,
              'downloadURL': ipaAsset.url,
              'size': ipaAsset.size,
            },
          ],
        },
      ],
      'news': const [],
    };
  }

  ReleaseAsset? selectIpaAsset(List<ReleaseAsset> assets) {
    if (assets.isEmpty) {
      return null;
    }

    final matcher = RegExp(config.assetNamePattern, caseSensitive: false);
    final ipaAssets = assets.where(_isIpaAsset).toList(growable: false);
    if (ipaAssets.isEmpty) {
      return null;
    }

    for (final asset in ipaAssets) {
      if (matcher.hasMatch(asset.name) || matcher.hasMatch(asset.url)) {
        return asset;
      }
    }

    return ipaAssets.first;
  }

  String buildSiteAssetUrl(String relativePath) {
    final root = Uri.parse(config.siteUrl);
    final joinedPath = _joinUrlPath(
      root.path,
      config.siteBasePath,
      relativePath,
    );
    return root.replace(path: joinedPath).toString();
  }

  String normalizeVersion(LatestRelease release) {
    final candidates = [release.tagName, release.name];

    for (final candidate in candidates) {
      final match = RegExp(
        r'(\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?)',
      ).firstMatch(candidate);
      if (match != null) {
        return match.group(1)!;
      }
    }

    final trimmed = release.tagName.trim();
    if (trimmed.startsWith('v') || trimmed.startsWith('V')) {
      return trimmed.substring(1);
    }

    return trimmed;
  }

  bool _isIpaAsset(ReleaseAsset asset) {
    final name = asset.name.toLowerCase();
    final url = asset.url.toLowerCase();
    final type = asset.contentType.toLowerCase();

    return name.endsWith('.ipa') ||
        url.contains('.ipa') ||
        type.contains('itunes-ipa') ||
        type.endsWith('/ipa');
  }

  String _joinUrlPath(String rootPath, String basePath, String relativePath) {
    final segments = <String>[
      if (rootPath.trim().isNotEmpty) rootPath,
      if (basePath.trim().isNotEmpty) basePath,
      relativePath,
    ];

    final cleaned = segments
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty && segment != '/')
        .map((segment) => segment.replaceAll(RegExp(r'^/+|/+$'), ''))
        .where((segment) => segment.isNotEmpty)
        .join('/');

    return '/$cleaned';
  }
}
