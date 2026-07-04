import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novella/core/widgets/m3e_loading_indicator.dart';
import 'package:novella/core/widgets/m3e_refresh_indicator.dart';

void main() {
  testWidgets('does not show the indicator for a short unarmed drag', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: M3ERefreshIndicator(
          onRefresh: () async {},
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [SizedBox(height: 800)],
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ListView)),
    );
    await gesture.moveBy(const Offset(0, 12));
    await tester.pump();

    expect(find.byType(M3ELoadingIndicator), findsNothing);

    await gesture.up();
  });

  testWidgets('positions the indicator below the configured edge offset', (
    tester,
  ) async {
    final refreshCompleter = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        home: M3ERefreshIndicator(
          edgeOffset: 44,
          onRefresh: () => refreshCompleter.future,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [SizedBox(height: 800)],
          ),
        ),
      ),
    );

    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(tester.getTopLeft(find.byType(M3ELoadingIndicator)).dy, 64);

    refreshCompleter.complete();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'positions the indicator above the bottom edge for reversed lists',
    (tester) async {
      final refreshCompleter = Completer<void>();

      await tester.pumpWidget(
        MaterialApp(
          home: M3ERefreshIndicator(
            onRefresh: () => refreshCompleter.future,
            child: ListView(
              reverse: true,
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [SizedBox(height: 400)],
            ),
          ),
        ),
      );

      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(tester.getBottomLeft(find.byType(M3ELoadingIndicator)).dy, 580);

      refreshCompleter.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('shows a contained M3E indicator while refreshing', (
    tester,
  ) async {
    final refreshCompleter = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        home: M3ERefreshIndicator(
          onRefresh: () => refreshCompleter.future,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [SizedBox(height: 800)],
          ),
        ),
      ),
    );

    expect(find.byType(M3ELoadingIndicator), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    final indicator = tester.widget<M3ELoadingIndicator>(
      find.byType(M3ELoadingIndicator),
    );

    expect(indicator.contained, isTrue);

    refreshCompleter.complete();
    await tester.pumpAndSettle();

    expect(find.byType(M3ELoadingIndicator), findsNothing);
  });
}
