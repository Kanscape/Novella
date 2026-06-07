import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:novella/core/network/request_queue.dart';
import 'package:novella/data/models/community.dart';
import 'package:novella/data/services/community_service.dart';
import 'package:novella/features/community/community_page.dart';
import 'package:novella/features/community/community_post_notice_sheet.dart';
import 'package:novella/features/community/notification_unread_provider.dart';
import 'package:novella/features/settings/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows the community notice before the first post', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = CommunityPostNoticeStore();

    await _pumpCommunityPage(tester, store);

    await tester.tap(find.byTooltip('发布帖子'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('使用须知'), findsOneWidget);
    expect(find.text('社区公告'), findsNothing);
    expect(find.text('应用相关问题请前往 GitHub 反馈'), findsOneWidget);
    expect(find.text('发布帖子'), findsNothing);
    expect(await store.hasAccepted(), isFalse);

    await tester.tap(find.byKey(communityPostNoticeContinueButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.text('使用须知'), findsNothing);
    expect(find.text('发布帖子'), findsOneWidget);
    expect(await store.hasAccepted(), isTrue);

    await _disposeWidgetTree(tester);
  });

  testWidgets('places the notice close button at the top right', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = CommunityPostNoticeStore();

    await _pumpCommunityPage(tester, store);

    await tester.tap(find.byTooltip('发布帖子'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final panelRect = tester.getRect(find.byKey(communityPostNoticePanelKey));
    final contentRect = tester.getRect(
      find.byKey(communityPostNoticeContentKey),
    );
    final closeButtonRect = tester.getRect(
      find.byKey(communityPostNoticeCloseButtonKey),
    );
    final titleCenter = tester.getCenter(find.text('使用须知'));
    expect(closeButtonRect.right, moreOrLessEquals(contentRect.right));
    expect(
      closeButtonRect.top - panelRect.top,
      moreOrLessEquals(panelRect.right - closeButtonRect.right),
    );
    expect(closeButtonRect.center.dy, lessThan(titleCenter.dy - 40));

    await _disposeWidgetTree(tester);
  });

  testWidgets('keeps the notice action fixed at the bottom', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = CommunityPostNoticeStore();

    await _pumpCommunityPage(tester, store);

    await tester.tap(find.byTooltip('发布帖子'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final panelRect = tester.getRect(find.byKey(communityPostNoticePanelKey));
    final continueButtonRect = tester.getRect(
      find.byKey(communityPostNoticeContinueButtonKey),
    );
    expect(
      find.descendant(
        of: find.byKey(communityPostNoticeContentKey),
        matching: find.byKey(communityPostNoticeContinueButtonKey),
      ),
      findsNothing,
    );
    expect(panelRect.bottom - continueButtonRect.bottom, moreOrLessEquals(24));

    await _disposeWidgetTree(tester);
  });

  testWidgets('skips the community notice after it is accepted', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      communityPostNoticeAcceptedPrefsKey: true,
    });
    final store = CommunityPostNoticeStore();

    await _pumpCommunityPage(tester, store);

    await tester.tap(find.byTooltip('发布帖子'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.text('使用须知'), findsNothing);
    expect(find.text('发布帖子'), findsOneWidget);

    await _disposeWidgetTree(tester);
  });
}

Future<void> _pumpCommunityPage(
  WidgetTester tester,
  CommunityPostNoticeStore store,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(() => _FakeSettingsNotifier()),
        notificationUnreadCountProvider.overrideWith(
          () => _FakeNotificationUnreadCountNotifier(),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          FlutterQuillLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh', 'CN'), Locale('en', '')],
        home: CommunityPage(
          communityService: _FakeCommunityService(),
          communityPostNoticeStore: store,
        ),
      ),
    ),
  );

  await tester.pump();
  await tester.pump();
}

Future<void> _disposeWidgetTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

class _FakeSettingsNotifier extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings(isLoaded: true);
}

class _FakeNotificationUnreadCountNotifier
    extends NotificationUnreadCountNotifier {
  @override
  Future<int> build() async => 0;

  @override
  Future<void> refreshCount({bool silent = false}) async {
    state = const AsyncData(0);
  }
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
          title: '综合讨论',
          description: '日常交流',
          icon: 'forum',
          subCategories: [],
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
