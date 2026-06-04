import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novella/core/network/request_queue.dart';
import 'package:novella/data/models/community.dart';
import 'package:novella/data/services/community_service.dart';
import 'package:novella/features/community/community_page.dart';
import 'package:novella/features/community/community_thread_page.dart';
import 'package:novella/features/community/notification_unread_provider.dart';
import 'package:novella/features/settings/settings_provider.dart';

void main() {
  testWidgets('shows deleted author status in community feed', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(() => _FakeSettingsNotifier()),
          notificationUnreadCountProvider.overrideWith(
            () => _FakeNotificationUnreadCountNotifier(),
          ),
        ],
        child: MaterialApp(
          home: CommunityPage(communityService: _FakeFeedCommunityService()),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Alice', findRichText: true), findsWidgets);
    expect(find.textContaining('被封禁', findRichText: true), findsOneWidget);
  });

  testWidgets('shows deleted author status in thread detail and replies', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityThreadPage(
          threadId: 1,
          communityService: _FakeThreadCommunityService(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Alice', findRichText: true), findsWidgets);
    expect(find.textContaining('Bob', findRichText: true), findsWidgets);
    expect(find.textContaining('Carol', findRichText: true), findsWidgets);
    expect(find.textContaining('被封禁', findRichText: true), findsNWidgets(4));
  });
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

class _FakeFeedCommunityService extends CommunityService {
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
      boards: const [],
      subCategories: const [],
      selectedSubCategoryKey: '',
      feed: [_feedItem(authorName: 'Alice', authorIsDeleted: true)],
      feedPage: const CommunityPagination(
        page: 1,
        size: 1,
        total: 1,
        totalPages: 1,
        hasMore: false,
      ),
      hotThreads: const [],
      activeUsers: const [],
    );
  }
}

class _FakeThreadCommunityService extends CommunityService {
  @override
  Future<CommunityThreadDetail?> getCommunityThread({
    required int threadId,
    int replyPage = 1,
    int replySize = 5,
    bool? trackView,
    String? requestScope,
    RequestPriority priority = RequestPriority.normal,
  }) async {
    return CommunityThreadDetail.fromJson({
      'Id': threadId,
      'BoardKey': 'general',
      'BoardName': '综合',
      'Title': '主帖',
      'Excerpt': '',
      'AuthorName': 'Alice',
      'AuthorIsDeleted': true,
      'PublishedAt': '2026-06-04T00:00:00Z',
      'Replies': 1,
      'Views': 0,
      'Heat': 0,
      'Likes': 0,
      'Favorites': 0,
      'BodyHtml': '<p>body</p>',
      'RepliesPage': {
        'Page': 1,
        'Size': 5,
        'Total': 1,
        'TotalPages': 1,
        'HasMore': false,
      },
      'ReplyItems': [
        {
          'Id': 2,
          'AuthorName': 'Bob',
          'AuthorIsDeleted': true,
          'PublishedAt': '2026-06-04T00:00:00Z',
          'Content': 'reply',
          'Likes': 0,
          'ReplyTo': {'Id': 1, 'AuthorName': 'Alice', 'AuthorIsDeleted': true},
          'ChildReplies': [
            {
              'Id': 3,
              'AuthorName': 'Carol',
              'AuthorIsDeleted': true,
              'PublishedAt': '2026-06-04T00:00:00Z',
              'Content': 'child reply',
              'Likes': 0,
              'ReplyTo': {
                'Id': 2,
                'AuthorName': 'Bob',
                'AuthorIsDeleted': true,
              },
            },
          ],
        },
      ],
      'RelatedThreads': const [],
    });
  }
}

CommunityFeedItem _feedItem({
  required String authorName,
  required bool authorIsDeleted,
}) {
  return CommunityFeedItem.fromJson({
    'Id': 1,
    'BoardKey': 'general',
    'BoardName': '综合',
    'Title': '帖子标题',
    'Excerpt': '摘要',
    'AuthorName': authorName,
    'AuthorIsDeleted': authorIsDeleted,
    'PublishedAt': '2026-06-04T00:00:00Z',
    'Replies': 0,
    'Views': 0,
    'Heat': 0,
    'Likes': 0,
    'Favorites': 0,
  });
}
