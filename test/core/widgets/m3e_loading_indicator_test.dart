import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_loading_indicator/loading_indicator.dart'
    as material_loading_indicator;
import 'package:novella/core/widgets/m3e_loading_indicator.dart';

void main() {
  const packageActiveIndicatorScale = 38 / 48;

  testWidgets('uses the package Material 3 loading indicator', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: M3ELoadingIndicator(
            size: 28,
            color: Colors.red,
            semanticsLabel: 'Loading books',
          ),
        ),
      ),
    );

    final packageIndicator = tester
        .widget<material_loading_indicator.LoadingIndicator>(
          find.byType(material_loading_indicator.LoadingIndicator),
        );

    expect(packageIndicator.activeIndicatorColor, Colors.red);
    expect(packageIndicator.semanticsLabel, 'Loading books');
  });

  testWidgets('treats size as the active indicator visual size', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: M3ELoadingIndicator(size: 28))),
    );

    final packageSize = tester.getSize(
      find.byType(material_loading_indicator.LoadingIndicator),
    );

    expect(
      packageSize.width,
      moreOrLessEquals(28 / packageActiveIndicatorScale),
    );
    expect(
      packageSize.height,
      moreOrLessEquals(28 / packageActiveIndicatorScale),
    );
  });

  testWidgets('supports the contained package indicator variant', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: M3ELoadingIndicator.contained(
            size: 28,
            color: Colors.red,
            containerColor: Colors.blue,
            semanticsLabel: 'Refreshing books',
          ),
        ),
      ),
    );

    final packageIndicator = tester
        .widget<material_loading_indicator.LoadingIndicator>(
          find.byType(material_loading_indicator.LoadingIndicator),
        );

    expect(packageIndicator.activeIndicatorColor, Colors.red);
    expect(packageIndicator.containerColor, Colors.blue);
    expect(packageIndicator.semanticsLabel, 'Refreshing books');
  });

  testWidgets('uses onPrimaryContainer for default contained active color', (
    tester,
  ) async {
    const colorScheme = ColorScheme.light(
      primary: Color(0xFF111111),
      onPrimaryContainer: Color(0xFF222222),
      primaryContainer: Color(0xFFEEEEEE),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Theme(
          data: ThemeData(colorScheme: colorScheme),
          child: const Center(child: M3ELoadingIndicator.contained()),
        ),
      ),
    );

    final packageIndicator = tester
        .widget<material_loading_indicator.LoadingIndicator>(
          find.byType(material_loading_indicator.LoadingIndicator),
        );

    expect(
      packageIndicator.activeIndicatorColor,
      colorScheme.onPrimaryContainer,
    );
  });
}
