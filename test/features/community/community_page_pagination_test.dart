import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novella/core/network/request_queue.dart';
import 'package:novella/data/models/community.dart';
import 'package:novella/data/services/community_service.dart';
import 'package:novella/features/community/community_page.dart';
import 'package:novella/features/community/notification_unread_provider.dart';
import 'package:novella/features/settings/settings_provider.dart';

const _loadMoreErrorKey = ValueKey('community-feed-load-more-error');
const _retryButtonKey = ValueKey('community-feed-load-more-retry-button');

void main() {
  testWidgets('shows a retry action after automatic pagination fails', (
    tester,
  ) async {
    final service = _RetryingCommunityService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(() => _FakeSettingsNotifier()),
          notificationUnreadCountProvider.overrideWith(
            () => _FakeNotificationUnreadCountNotifier(),
          ),
        ],
        child: MaterialApp(home: CommunityPage(communityService: service)),
      ),
    );

    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(_feedCardFinder(1), findsOneWidget);
    await tester.scrollUntilVisible(
      _feedCardFinder(3),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(_loadMoreErrorKey), findsOneWidget);
    expect(find.byKey(_retryButtonKey), findsOneWidget);
    expect(service.pageTwoRequests, 1);

    await tester.tap(find.byKey(_retryButtonKey));
    await tester.pump();
    await tester.pump();

    expect(_feedCardFinder(4), findsOneWidget);
    expect(find.byKey(_loadMoreErrorKey), findsNothing);
    expect(service.pageTwoRequests, 2);
  });
}

Finder _feedCardFinder(int id) {
  return find.byKey(ValueKey('community-feed-card-$id'));
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

class _RetryingCommunityService extends CommunityService {
  int pageTwoRequests = 0;

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
      catalogBoards: const [],
      boards: const [
        CommunityBoardSummary(
          id: 0,
          key: 'all',
          title: 'all',
          description: '',
          icon: '',
          todayPosts: 0,
          heatLabel: '',
        ),
      ],
      subCategories: const [],
      selectedSubCategoryKey: '',
      feed: [
        _feedItem(1, 'first page item 1'),
        _feedItem(2, 'first page item 2'),
        _feedItem(3, 'first page item 3'),
      ],
      feedPage: const CommunityPagination(
        page: 1,
        size: 3,
        total: 4,
        totalPages: 2,
        hasMore: true,
      ),
      hotThreads: const [],
      activeUsers: const [],
    );
  }

  @override
  Future<CommunityFeedPayload> getCommunityFeed({
    CommunityListQuery query = const CommunityListQuery(),
    String? requestScope,
    RequestPriority priority = RequestPriority.normal,
  }) async {
    pageTwoRequests += 1;
    if (pageTwoRequests == 1) {
      throw Exception('append failed');
    }

    return CommunityFeedPayload(
      subCategories: const [],
      selectedSubCategoryKey: '',
      feed: [_feedItem(4, 'second page item')],
      feedPage: const CommunityPagination(
        page: 2,
        size: 3,
        total: 4,
        totalPages: 2,
        hasMore: false,
      ),
    );
  }
}

CommunityFeedItem _feedItem(int id, String title) {
  return CommunityFeedItem(
    id: id,
    boardKey: 'general',
    boardName: 'general board',
    subCategoryKey: '',
    subCategoryLabel: '',
    title: title,
    excerpt: 'excerpt',
    authorName: 'user',
    authorAvatar: '',
    publishedAt: DateTime(2026),
    replies: 0,
    views: 0,
    heat: 0,
    likes: 0,
    favorites: 0,
    tags: const [],
    featured: false,
    pinned: false,
    locked: false,
  );
}
