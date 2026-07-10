import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novella/core/widgets/m3e_loading_indicator.dart';

void main() {
  const packageActiveIndicatorScale = 38 / 48;

  // 指示器内部实现为私有 _LoadingIndicatorCore，其单个 CustomPaint 承载
  // 活动指示器(foregroundPainter)与容器(painter)。此处按可观察结构取回，
  // 并用 dynamic 读取 painter 上以公开命名保存的颜色字段以校验颜色转发。
  CustomPaint indicatorPaint(WidgetTester tester) {
    return tester
        .widgetList<CustomPaint>(
          find.descendant(
            of: find.byType(M3ELoadingIndicator),
            matching: find.byType(CustomPaint),
          ),
        )
        .firstWhere((p) => p.foregroundPainter != null);
  }

  testWidgets('forwards active color and semantics label', (tester) async {
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

    final active = indicatorPaint(tester).foregroundPainter! as dynamic;
    expect(active.activeIndicatorColor, Colors.red);
    expect(find.bySemanticsLabel('Loading books'), findsOneWidget);
  });

  testWidgets('treats size as the active indicator visual size', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: M3ELoadingIndicator(size: 28))),
    );

    // 外层盒子等于 size；内部绘制指示器按 48/38 放大。
    expect(tester.getSize(find.byType(M3ELoadingIndicator)).width, 28);
    final paintSize = tester.getSize(
      find.descendant(
        of: find.byType(M3ELoadingIndicator),
        matching: find.byType(CustomPaint),
      ).first,
    );
    expect(paintSize.width, moreOrLessEquals(28 / packageActiveIndicatorScale));
    expect(paintSize.height, moreOrLessEquals(28 / packageActiveIndicatorScale));
  });

  testWidgets('supports the contained variant colors', (tester) async {
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

    final paint = indicatorPaint(tester);
    final active = paint.foregroundPainter! as dynamic;
    final container = paint.painter! as dynamic;
    expect(active.activeIndicatorColor, Colors.red);
    expect(container.containerColor, Colors.blue);
    expect(find.bySemanticsLabel('Refreshing books'), findsOneWidget);
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

    final active = indicatorPaint(tester).foregroundPainter! as dynamic;
    expect(active.activeIndicatorColor, colorScheme.onPrimaryContainer);
  });
}
