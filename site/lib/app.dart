import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

import 'src/components/landing_page.dart';
import 'src/content/models.dart';

class App extends StatelessComponent {
  const App({required this.siteData, required this.releaseUrl, super.key});

  final SiteData siteData;
  final String releaseUrl;

  @override
  Component build(BuildContext context) {
    return Router(
      errorBuilder: (context, _) => Component.fragment([
        Document.head(title: '404 - Novella'),
        NotFoundPage(siteData: siteData),
      ]),
      routes: [
        Route(
          path: '/',
          title: 'Novella — Open Source Light Novel Reader',
          settings: const RouteSettings(
            changeFreq: ChangeFreq.daily,
            priority: 1.0,
          ),
          builder: (context, _) =>
              HomePage(siteData: siteData, releaseUrl: releaseUrl),
        ),
        Route(
          path: '/download',
          title: 'Download - Novella',
          settings: const RouteSettings(
            changeFreq: ChangeFreq.daily,
            priority: 0.9,
          ),
          builder: (context, _) => DownloadPage(siteData: siteData),
        ),
        Route(
          path: '/changelog',
          title: 'Changelog - Novella',
          settings: const RouteSettings(
            changeFreq: ChangeFreq.daily,
            priority: 0.8,
          ),
          builder: (context, _) => ChangelogPage(siteData: siteData),
        ),
      ],
    );
  }
}
