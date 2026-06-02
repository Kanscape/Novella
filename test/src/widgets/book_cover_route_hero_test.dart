import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novella/src/widgets/book_cover_card.dart';
import 'package:novella/src/widgets/book_cover_image.dart';
import 'package:novella/src/widgets/book_cover_route_hero.dart';

void main() {
  const coverUrl = 'https://example.com/cover.jpg';

  testWidgets('keeps a cover Hero on Android with a custom flight shuttle', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: BookCoverRouteHero(
            tag: 'cover',
            coverUrl: coverUrl,
            precacheCover: false,
            child: SizedBox(width: 80, height: 120),
          ),
        ),
      );

      final hero = tester.widget<Hero>(find.byType(Hero));
      expect(hero.tag, 'cover');
      expect(hero.flightShuttleBuilder, isNotNull);

      final heroContext = tester.element(find.byType(Hero));
      final flight = hero.flightShuttleBuilder!(
        heroContext,
        const AlwaysStoppedAnimation<double>(1),
        HeroFlightDirection.pop,
        heroContext,
        heroContext,
      );

      expect(flight, isA<BookCoverCard>());
      final card = flight as BookCoverCard;
      expect(card.coverUrl, coverUrl);
      expect(card.enablePreview, isFalse);
      expect(card.showLoading, isFalse);
      expect(card.revealedBefore, isTrue);
      expect(card.memCacheWidth, 350);

      final pushFlight = hero.flightShuttleBuilder!(
        heroContext,
        const AlwaysStoppedAnimation<double>(1),
        HeroFlightDirection.push,
        heroContext,
        heroContext,
      );

      expect(pushFlight, isNot(isA<BookCoverCard>()));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('passes cache dimensions to the cover image', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 100,
          height: 150,
          child: BookCoverCard(
            coverUrl: coverUrl,
            enablePreview: false,
            resolveNetworkImage: false,
            memCacheWidth: 180,
            memCacheHeight: 270,
          ),
        ),
      ),
    );

    final image = tester.widget<BookCoverImage>(find.byType(BookCoverImage));
    expect(image.memCacheWidth, 180);
    expect(image.memCacheHeight, 270);
  });
}
