import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novella/core/network/request_queue.dart';
import 'package:novella/data/models/community.dart';
import 'package:novella/data/services/community_service.dart';
import 'package:novella/features/community/moderation/community_speech_guard.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('blocks a matching thread before invoking SignalR', () async {
    final invoker = _RecordingInvoker();
    final service = CommunityService(
      speechGuard: _guard(_rulesText()),
      signalRInvoker: invoker.call,
    );

    await expectLater(
      service.createCommunityThread(
        const CreateCommunityThreadRequest(
          boardKey: 'general',
          title: '求一份资源',
          contentHtml: '<p>请上<span>传</span>给我</p>',
        ),
      ),
      throwsA(isA<CommunitySpeechBlockedException>()),
    );

    expect(invoker.callCount, 0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(communitySpeechDisabledPrefsKey), isTrue);
  });

  test('refuses a reply when moderation rules are unavailable', () async {
    final invoker = _RecordingInvoker();
    final guard = CommunitySpeechGuard(
      prefsLoader: SharedPreferences.getInstance,
      httpGetString: (uri) async => throw StateError('offline'),
    );
    final service = CommunityService(
      speechGuard: guard,
      signalRInvoker: invoker.call,
    );

    await expectLater(
      service.createCommunityReply(
        const CreateCommunityReplyRequest(threadId: 1, content: '普通回复'),
      ),
      throwsA(isA<CommunitySpeechRulesUnavailableException>()),
    );

    expect(invoker.callCount, 0);
    expect(guard.speechDisabled, isFalse);
  });

  test('invokes SignalR once after a reply passes moderation', () async {
    final invoker = _RecordingInvoker();
    final service = CommunityService(
      speechGuard: _guard(_rulesText()),
      signalRInvoker: invoker.call,
    );

    final reply = await service.createCommunityReply(
      const CreateCommunityReplyRequest(threadId: 1, content: '普通交流内容'),
    );

    expect(reply.id, 7);
    expect(invoker.callCount, 1);
    expect(invoker.lastMethodName, 'CreateCommunityReply');
  });
}

CommunitySpeechGuard _guard(String rulesText) {
  final manifestUri = Uri.parse(
    'https://example.test/assets/community-moderation/manifest.json',
  );
  final rulesBytes = utf8.encode(rulesText);
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

String _rulesText() {
  return jsonEncode({
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
      {
        'id': 'request-upload-or-send',
        'scopes': ['threadTitle', 'threadBody', 'reply'],
        'clauses': [
          {
            'anyOf': ['求'],
          },
          {
            'anyOf': ['上传', '发'],
          },
        ],
      },
    ],
  });
}

class _RecordingInvoker {
  int callCount = 0;
  String? lastMethodName;

  Future<T> call<T>(
    String methodName, {
    List<Object>? args,
    String? requestScope,
    RequestPriority priority = RequestPriority.normal,
    bool bypassQueue = false,
  }) async {
    callCount += 1;
    lastMethodName = methodName;
    return <dynamic, dynamic>{'Id': 7, 'Content': '普通交流内容'} as T;
  }
}
