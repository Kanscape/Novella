import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novella/core/navigation/m3e_center_reveal_route.dart';
import 'package:novella/core/widgets/m3e_loading_indicator.dart';

void main() {
  testWidgets('shows M3E loading while revealing the destination from center', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Center(child: Text('Loading'))),
      ),
    );

    navigatorKey.currentState!.pushReplacement(
      createM3ECenterRevealRoute<void>(
        builder: (_) => const Scaffold(body: Center(child: Text('Home'))),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byType(M3ELoadingIndicator), findsOneWidget);

    final firstClip = tester.widget<ClipPath>(find.byType(ClipPath));
    final firstClipper = firstClip.clipper! as M3ECenterRevealClipper;
    expect(firstClipper.progress, 0);

    await tester.pump(const Duration(milliseconds: 260));

    final midClip = tester.widget<ClipPath>(find.byType(ClipPath));
    final midClipper = midClip.clipper! as M3ECenterRevealClipper;
    expect(midClipper.progress, greaterThan(0));
    expect(midClipper.progress, lessThan(1));

    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.byType(M3ELoadingIndicator), findsNothing);
    expect(find.byType(ClipPath), findsNothing);
  });

  test('clipper reveals from the center before covering the viewport', () {
    final clipper = M3ECenterRevealClipper(progress: 0.5);
    final path = clipper.getClip(const Size(100, 80));

    expect(path.contains(const Offset(50, 40)), isTrue);
    expect(path.contains(Offset.zero), isFalse);

    final fullClipper = M3ECenterRevealClipper(progress: 1);
    final fullPath = fullClipper.getClip(const Size(100, 80));

    expect(fullPath.contains(Offset.zero), isTrue);
  });
}
