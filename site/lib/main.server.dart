import 'dart:io';

import 'package:jaspr/server.dart';

import 'app.dart';
import 'main.server.options.dart';
import 'src/content/site_data_loader.dart';

Future<void> main() async {
  Jaspr.initializeApp(options: defaultServerOptions);

  final siteUrl =
      Platform.environment['SITE_URL'] ?? 'https://novella.celia.sh';
  final basePath = _normalizeBasePath(
    Platform.environment['SITE_BASE_PATH'] ?? '/',
  );
  final canonicalUrl = _normalizeCanonicalUrl(siteUrl);

  final siteData = await const SiteDataLoader().load();
  final pageTitle = 'Novella — Open Source Light Novel Reader';
  final description = siteData.repository.description;
  final heroImageUrl = _resolveAssetUrl(
    canonicalUrl,
    'assets/screenshots/OG.png',
  );
  final faviconUrl = '${basePath}assets/brand/favicon.png';

  runApp(
    Document(
      title: pageTitle,
      base: basePath,
      meta: {'description': description},
      head: [
        Component.element(
          tag: 'link',
          attributes: {
            'rel': 'preconnect',
            'href': 'https://fonts.googleapis.com',
          },
        ),
        Component.element(
          tag: 'link',
          attributes: {
            'rel': 'preconnect',
            'href': 'https://fonts.gstatic.com',
            'crossorigin': '',
          },
        ),
        Component.element(
          tag: 'link',
          attributes: {
            'rel': 'stylesheet',
            'href':
                'https://fonts.googleapis.com/css2?family=Jost:ital,wght@0,100..900;1,100..900&display=swap',
          },
        ),
        Component.element(
          tag: 'link',
          attributes: {'rel': 'preconnect', 'href': 'https://github.com'},
        ),
        Component.element(
          tag: 'link',
          attributes: {
            'rel': 'preconnect',
            'href': 'https://avatars.githubusercontent.com',
            'crossorigin': '',
          },
        ),
        Component.element(
          tag: 'link',
          attributes: {'rel': 'stylesheet', 'href': 'styles.css'},
        ),
        Component.element(
          tag: 'script',
          attributes: {'src': 'app-sources.js', 'defer': ''},
        ),
        Component.element(
          tag: 'link',
          attributes: {'rel': 'icon', 'type': 'image/png', 'href': faviconUrl},
        ),
        Component.element(
          tag: 'link',
          attributes: {'rel': 'canonical', 'href': canonicalUrl},
        ),
        Component.element(
          tag: 'meta',
          attributes: {'property': 'og:type', 'content': 'website'},
        ),
        Component.element(
          tag: 'meta',
          attributes: {'property': 'og:title', 'content': pageTitle},
        ),
        Component.element(
          tag: 'meta',
          attributes: {'property': 'og:description', 'content': description},
        ),
        Component.element(
          tag: 'meta',
          attributes: {'property': 'og:url', 'content': canonicalUrl},
        ),
        Component.element(
          tag: 'meta',
          attributes: {'property': 'og:image', 'content': heroImageUrl},
        ),
        Component.element(
          tag: 'meta',
          attributes: {
            'name': 'twitter:card',
            'content': 'summary_large_image',
          },
        ),
        Component.element(
          tag: 'meta',
          attributes: {'name': 'twitter:title', 'content': pageTitle},
        ),
        Component.element(
          tag: 'meta',
          attributes: {'name': 'twitter:description', 'content': description},
        ),
        Component.element(
          tag: 'meta',
          attributes: {'name': 'twitter:image', 'content': heroImageUrl},
        ),
        Component.element(
          tag: 'meta',
          attributes: {'name': 'theme-color', 'content': '#080b12'},
        ),
      ],
      body: App(siteData: siteData),
    ),
  );
}

String _normalizeBasePath(String value) {
  if (value.isEmpty || value == '/') {
    return '/';
  }

  var normalized = value.trim();
  if (!normalized.startsWith('/')) {
    normalized = '/$normalized';
  }
  if (!normalized.endsWith('/')) {
    normalized = '$normalized/';
  }
  return normalized;
}

String _normalizeCanonicalUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return 'https://novella.celia.sh/';
  }
  return trimmed.endsWith('/') ? trimmed : '$trimmed/';
}

String _resolveAssetUrl(String canonicalUrl, String assetPath) {
  return Uri.parse(canonicalUrl).resolve(assetPath).toString();
}
