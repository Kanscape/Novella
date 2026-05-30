import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:novella/core/network/request_queue.dart';
import 'package:novella/data/models/community.dart';
import 'package:novella/data/services/community_service.dart';
import 'package:novella/features/community/community_compose_page.dart';

void main() {
  testWidgets('keeps board and subcategory empty after catalog loads', (
    tester,
  ) async {
    await _pumpComposePage(tester);

    expect(find.text('选择板块'), findsOneWidget);
    expect(find.text('根据内容选择板块'), findsOneWidget);
    expect(find.text('综合讨论'), findsNothing);
    expect(find.text('闲聊'), findsNothing);
    expect(find.text('这里更像一个连续的编辑器，而不是拆成很多格子的表单页。'), findsNothing);

    await _disposeWidgetTree(tester);
  });

  testWidgets('keeps subcategory empty after selecting a board', (
    tester,
  ) async {
    await _pumpComposePage(tester);

    await tester.tap(find.text('选择板块'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('综合讨论'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('综合讨论'), findsWidgets);
    expect(find.text('子分类'), findsOneWidget);
    expect(find.text('闲聊'), findsNothing);

    await _disposeWidgetTree(tester);
  });

  testWidgets(
    'keeps publish disabled after selecting a board without content',
    (tester) async {
      await _pumpComposePage(tester);

      await tester.tap(find.text('选择板块'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('综合讨论'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final publishButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, '发布'),
      );
      expect(publishButton.onPressed, isNull);

      await _disposeWidgetTree(tester);
    },
  );

  testWidgets('moves focus from title to editor when tapping body', (
    tester,
  ) async {
    await _pumpComposePage(tester);

    await tester.tap(find.byType(TextFormField));
    await tester.pump();

    var editor = tester.widget<QuillEditor>(find.byType(QuillEditor));
    expect(editor.focusNode.hasFocus, isFalse);

    final editorRect = tester.getRect(find.byType(QuillEditor));
    await tester.tapAt(editorRect.center);
    await tester.pump();

    editor = tester.widget<QuillEditor>(find.byType(QuillEditor));
    expect(editor.focusNode.hasFocus, isTrue);

    await _disposeWidgetTree(tester);
  });
}

Future<void> _pumpComposePage(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        FlutterQuillLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', '')],
      home: CommunityComposePage(communityService: _FakeCommunityService()),
    ),
  );

  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1));
}

Future<void> _disposeWidgetTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

class _FakeCommunityService extends CommunityService {
  @override
  Future<CommunityHomePayload> getCommunityHome({
    CommunityListQuery query = const CommunityListQuery(),
    String? requestScope,
    RequestPriority priority = RequestPriority.normal,
  }) async {
    return CommunityHomePayload(
      title: '社区',
      subtitle: '',
      announcement: '',
      announcementLink: '',
      todayThreads: 0,
      onlineUserCount: 0,
      catalogBoards: const [
        CommunityCatalogBoard(
          id: 1,
          key: 'general',
          title: '综合讨论',
          description: '聊点日常',
          icon: 'forum',
          subCategories: [
            CommunityCatalogSubCategory(id: 11, key: 'chat', label: '闲聊'),
          ],
        ),
      ],
      boards: const [],
      subCategories: const [],
      selectedSubCategoryKey: '',
      feed: const [],
      feedPage: const CommunityPagination(
        page: 1,
        size: 0,
        total: 0,
        totalPages: 0,
        hasMore: false,
      ),
      hotThreads: const [],
      activeUsers: const [],
    );
  }
}
