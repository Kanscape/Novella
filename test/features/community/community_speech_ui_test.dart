import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novella/core/network/request_queue.dart';
import 'package:novella/data/models/community.dart';
import 'package:novella/data/services/community_service.dart';
import 'package:novella/features/community/community_page.dart';
import 'package:novella/features/community/community_thread_page.dart';
import 'package:novella/features/community/moderation/community_speech_guard.dart';
import 'package:novella/features/community/notification_unread_provider.dart';
import 'package:novella/features/settings/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('disables the community post button from persisted state', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      communitySpeechDisabledPrefsKey: true,
    });
    final guard = CommunitySpeechGuard(
      prefsLoader: SharedPreferences.getInstance,
      httpGetString: (uri) async => throw StateError('must not fetch'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(() => _FakeSettingsNotifier()),
          notificationUnreadCountProvider.overrideWith(
            () => _FakeNotificationUnreadCountNotifier(),
          ),
        ],
        child: MaterialApp(
          home: CommunityPage(communityService: _HomeCommunityService(guard)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final postButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.edit_note_rounded),
    );
    expect(postButton.onPressed, isNull);
  });

  testWidgets('disables every reply entry from persisted state', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      communitySpeechDisabledPrefsKey: true,
    });
    final guard = CommunitySpeechGuard(
      prefsLoader: SharedPreferences.getInstance,
      httpGetString: (uri) async => throw StateError('must not fetch'),
    );
    final invoker = _ThreadInvoker();

    await tester.pumpWidget(
      MaterialApp(
        home: CommunityThreadPage(
          threadId: 1,
          communityService: CommunityService(
            speechGuard: guard,
            signalRInvoker: invoker.call,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final fab = tester.widget<FloatingActionButton>(
      find.byKey(const ValueKey('community-thread-reply-fab')),
    );
    expect(fab.onPressed, isNull);

    final replyInkWell = tester.widget<InkWell>(
      find.descendant(
        of: find.byKey(const ValueKey('community-thread-reply-action-2')),
        matching: find.byType(InkWell),
      ),
    );
    expect(replyInkWell.onTap, isNull);

    final childReplyButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('community-thread-child-reply-3')),
    );
    expect(childReplyButton.onPressed, isNull);
  });

  testWidgets('silently returns home when a reply matches a rule', (
    tester,
  ) async {
    final guard = _guardWithRules();
    final invoker = _ThreadInvoker();

    await _pumpThreadFromHome(tester, guard: guard, invoker: invoker);
    expect(
      tester
          .widget<FloatingActionButton>(
            find.byKey(const ValueKey('community-thread-reply-fab')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const ValueKey('community-thread-reply-fab')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '这个软件从哪里下载');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '发送'));
    await tester.pumpAndSettle();

    expect(guard.speechDisabled, isTrue);
    expect(invoker.createReplyCalls, 0);
    expect(find.text('社区根页面'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('keeps the reply draft when rules cannot be loaded', (
    tester,
  ) async {
    final guard = CommunitySpeechGuard(
      prefsLoader: SharedPreferences.getInstance,
      httpGetString: (uri) async => throw StateError('offline'),
    );
    final invoker = _ThreadInvoker();

    await _pumpThreadFromHome(tester, guard: guard, invoker: invoker);
    expect(
      tester
          .widget<FloatingActionButton>(
            find.byKey(const ValueKey('community-thread-reply-fab')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const ValueKey('community-thread-reply-fab')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '普通交流内容');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '发送'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final input = tester.widget<TextField>(find.byType(TextField));
    expect(input.controller?.text, '普通交流内容');
    expect(find.text('请稍后重试'), findsOneWidget);
    expect(invoker.createReplyCalls, 0);
    expect(find.text('社区根页面'), findsNothing);
  });
}

Future<void> _pumpThreadFromHome(
  WidgetTester tester, {
  required CommunitySpeechGuard guard,
  required _ThreadInvoker invoker,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CommunityThreadPage(
                      threadId: 1,
                      communityService: CommunityService(
                        speechGuard: guard,
                        signalRInvoker: invoker.call,
                      ),
                    ),
                  ),
                );
              },
              child: const Text('社区根页面'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('社区根页面'));
  await tester.pumpAndSettle();
}

CommunitySpeechGuard _guardWithRules() {
  final rulesText = jsonEncode({
    'schemaVersion': 1,
    'revision': 2026071801,
    'normalization': 'compact-v1',
    'publishedAt': '2026-07-18T00:00:00Z',
    'rules': [
      {
        'id': 'software-or-download',
        'scopes': ['threadTitle', 'threadBody', 'reply'],
        'clauses': [
          {
            'anyOf': ['软件', '下载'],
          },
        ],
      },
    ],
  });
  final rulesBytes = utf8.encode(rulesText);
  final manifestUri = Uri.parse(
    'https://example.test/assets/community-moderation/manifest.json',
  );
  final manifestText = jsonEncode({
    'schemaVersion': 1,
    'revision': 2026071801,
    'rulesPath': 'rules-2026071801.json',
    'sha256': sha256.convert(rulesBytes).toString(),
    'size': rulesBytes.length,
    'cacheMaxAgeSeconds': 21600,
  });
  return CommunitySpeechGuard(
    manifestUri: manifestUri,
    now: () => DateTime.utc(2026, 7, 18, 12),
    prefsLoader: SharedPreferences.getInstance,
    httpGetString: (uri) async {
      return uri == manifestUri ? manifestText : rulesText;
    },
  );
}

class _HomeCommunityService extends CommunityService {
  _HomeCommunityService(CommunitySpeechGuard guard) : super(speechGuard: guard);

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

class _ThreadInvoker {
  int createReplyCalls = 0;

  Future<T> call<T>(
    String methodName, {
    List<Object>? args,
    String? requestScope,
    RequestPriority priority = RequestPriority.normal,
    bool bypassQueue = false,
  }) async {
    if (methodName == 'GetCommunityThread') {
      return _threadPayload() as T;
    }
    if (methodName == 'CreateCommunityReply') {
      createReplyCalls += 1;
      return <dynamic, dynamic>{'Id': 9, 'Content': '回复'} as T;
    }
    throw StateError('Unexpected method: $methodName');
  }
}

Map<dynamic, dynamic> _threadPayload() {
  return {
    'Id': 1,
    'BoardKey': 'general',
    'BoardName': '综合',
    'Title': '主帖',
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
        'AuthorName': 'Alice',
        'Content': '一级回复',
        'ChildReplies': [
          {'Id': 3, 'AuthorName': 'Bob', 'Content': '楼中楼'},
        ],
      },
    ],
    'RelatedThreads': const [],
  };
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
