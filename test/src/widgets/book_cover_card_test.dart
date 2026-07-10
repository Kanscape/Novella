import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novella/src/widgets/book_cover_card.dart';

void main() {
  testWidgets('rapid consecutive pops keep the list cover visible', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    const coverKey = ValueKey('list-cover');

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: Scaffold(
          body: Builder(
            builder:
                (context) => Column(
                  children: [
                    const Hero(
                      tag: 'cover',
                      placeholderBuilder: bookCoverHeroPlaceholderBuilder,
                      child: SizedBox(key: coverKey, width: 80, height: 120),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => const _DetailPage(),
                          ),
                        );
                      },
                      child: const Text('详情'),
                    ),
                  ],
                ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('详情'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('评论'));
    await tester.pumpAndSettle();

    navigatorKey.currentState!
      ..pop()
      ..pop();
    await tester.pumpAndSettle();

    expect(find.byKey(coverKey), findsOneWidget);
  });

  testWidgets('placeholder retains the cover while its route is covered', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    const coverKey = ValueKey('placeholder-cover');

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: Scaffold(
          body: Builder(
            builder:
                (context) => Column(
                  children: [
                    bookCoverHeroPlaceholderBuilder(
                      context,
                      const Size(80, 120),
                      const SizedBox(key: coverKey),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => const Scaffold(body: Text('下一页')),
                          ),
                        );
                      },
                      child: const Text('打开'),
                    ),
                  ],
                ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.byKey(coverKey), findsNothing);
    expect(find.byKey(coverKey, skipOffstage: false), findsOneWidget);

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(coverKey), findsOneWidget);
  });
}

class _DetailPage extends StatelessWidget {
  const _DetailPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const Hero(tag: 'cover', child: SizedBox(width: 100, height: 150)),
          TextButton(
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('评论页')),
                ),
              );
            },
            child: const Text('评论'),
          ),
        ],
      ),
    );
  }
}
