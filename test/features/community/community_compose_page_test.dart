import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:novella/core/network/request_queue.dart';
import 'package:novella/data/models/community.dart';
import 'package:novella/data/services/community_service.dart';
import 'package:novella/features/community/community_compose_page.dart';

const _boardChipKey = ValueKey('community-compose-board-chip');
const _emptyBoardContextKey = ValueKey('community-compose-context-board-empty');
const _selectedBoardContextKey = ValueKey(
  'community-compose-context-board-selected',
);
const _subcategoryChipKey = ValueKey('community-compose-subcategory-chip');
const _publishButtonKey = ValueKey('community-compose-publish-button');

void main() {
  testWidgets('keeps board and subcategory empty after catalog loads', (
    tester,
  ) async {
    await _pumpComposePage(tester);

    expect(find.byKey(_boardChipKey), findsOneWidget);
    expect(find.byKey(_emptyBoardContextKey), findsOneWidget);
    expect(find.byKey(_selectedBoardContextKey), findsNothing);
    expect(find.byKey(_subcategoryChipKey), findsNothing);

    await _disposeWidgetTree(tester);
  });

  testWidgets('keeps subcategory empty after selecting a board', (
    tester,
  ) async {
    await _pumpComposePage(tester);

    await tester.tap(find.byKey(_boardChipKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(_pickerItemFinder('general'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byKey(_selectedBoardContextKey), findsOneWidget);
    expect(find.byKey(_subcategoryChipKey), findsOneWidget);

    await tester.tap(find.byKey(_subcategoryChipKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final dynamic emptyOption = tester.widget(_pickerItemFinder(''));
    final dynamic chatOption = tester.widget(_pickerItemFinder('chat'));
    expect(emptyOption.selected, isTrue);
    expect(chatOption.selected, isFalse);

    await _disposeWidgetTree(tester);
  });

  testWidgets(
    'keeps publish disabled after selecting a board without content',
    (tester) async {
      await _pumpComposePage(tester);

      await tester.tap(find.byKey(_boardChipKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(_pickerItemFinder('general'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final publishButton = tester.widget<TextButton>(
        find.byKey(_publishButtonKey),
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

Finder _pickerItemFinder(String value) {
  return find.byKey(ValueKey('community-compose-picker-item-$value'));
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
      title: 'community',
      subtitle: '',
      announcement: '',
      announcementLink: '',
      todayThreads: 0,
      onlineUserCount: 0,
      catalogBoards: const [
        CommunityCatalogBoard(
          id: 1,
          key: 'general',
          title: 'general board',
          description: 'daily talk',
          icon: 'forum',
          subCategories: [
            CommunityCatalogSubCategory(id: 11, key: 'chat', label: 'chat'),
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
