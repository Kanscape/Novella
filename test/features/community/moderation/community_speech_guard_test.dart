import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novella/features/community/moderation/community_moderation_rules.dart';
import 'package:novella/features/community/moderation/community_speech_guard.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final now = DateTime.utc(2026, 7, 18, 12);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('normalizes width, punctuation, and zero-width characters', () {
    expect(normalizeCommunitySpeechText('  求\u200B，＋ＦＡＴ！ '), '求fat');
  });

  test('requires every clause and accepts any term in a clause', () async {
    final rulesText = _rulesText([
      _rule(
        id: 'request-upload-or-send',
        scopes: ['threadTitle', 'threadBody'],
        clauses: [
          {
            'anyOf': ['求'],
          },
          {
            'anyOf': ['上传', '发'],
          },
        ],
      ),
    ]);
    final guard = _guard(rulesText);

    final crossField = await guard.check(
      fields: const [
        CommunitySpeechField.threadTitle('求一个主题'),
        CommunitySpeechField.threadBody('请上传文件'),
      ],
    );
    expect(crossField.type, CommunitySpeechDecisionType.blocked);
    expect(crossField.ruleId, 'request-upload-or-send');

    final alreadyDisabled = await guard.check(
      fields: const [CommunitySpeechField.threadBody('普通内容')],
    );
    expect(alreadyDisabled.type, CommunitySpeechDecisionType.alreadyDisabled);
  });

  test('does not join text across fields for one term', () async {
    final rulesText = _rulesText([
      _rule(
        id: 'software-or-download',
        scopes: ['threadTitle', 'threadBody'],
        clauses: [
          {
            'anyOf': ['软件', '下载'],
          },
        ],
      ),
    ]);
    final guard = _guard(rulesText);

    final result = await guard.check(
      fields: const [
        CommunitySpeechField.threadTitle('软'),
        CommunitySpeechField.threadBody('件'),
      ],
    );
    expect(result.type, CommunitySpeechDecisionType.allowed);
  });

  test('persists permanent disable and skips future network loads', () async {
    final rulesText = _rulesText([
      _rule(
        id: 'software-or-download',
        scopes: ['threadBody'],
        clauses: [
          {
            'anyOf': ['软件', '下载'],
          },
        ],
      ),
    ]);
    final firstGuard = _guard(rulesText);
    var notifications = 0;
    firstGuard.addListener(() => notifications++);
    final firstResult = await firstGuard.check(
      fields: const [CommunitySpeechField.threadBody('讨论软件下载')],
    );
    expect(firstResult.type, CommunitySpeechDecisionType.blocked);
    expect(await firstGuard.isSpeechDisabled(), isTrue);
    expect(firstGuard.speechDisabled, isTrue);
    expect(notifications, 1);

    var networkCalled = false;
    final secondGuard = CommunitySpeechGuard(
      prefsLoader: SharedPreferences.getInstance,
      now: () => now,
      httpGetString: (uri) async {
        networkCalled = true;
        throw StateError('network must not be called');
      },
    );
    var secondGuardNotifications = 0;
    secondGuard.addListener(() => secondGuardNotifications++);
    final secondResult = await secondGuard.check(
      fields: const [CommunitySpeechField.threadBody('普通内容')],
    );
    expect(secondResult.type, CommunitySpeechDecisionType.alreadyDisabled);
    expect(secondGuard.speechDisabled, isTrue);
    expect(secondGuardNotifications, 1);
    expect(networkCalled, isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(communitySpeechDisabledPrefsKey), isTrue);
    final metadata =
        jsonDecode(prefs.getString(communitySpeechDisabledMetadataPrefsKey)!)
            as Map<String, dynamic>;
    expect(metadata['ruleId'], 'software-or-download');
  });

  test('keeps the block when persistence fails after a match', () async {
    final rulesText = _rulesText([
      _rule(
        id: 'software-or-download',
        scopes: ['threadBody'],
        clauses: [
          {
            'anyOf': ['软件'],
          },
        ],
      ),
    ]);
    var failPersistence = false;
    final manifestText = _manifestText(rulesText);
    final manifestUri = Uri.parse(
      'https://example.test/assets/community-moderation/manifest.json',
    );
    final guard = CommunitySpeechGuard(
      manifestUri: manifestUri,
      now: () => now,
      prefsLoader: () async {
        if (failPersistence) {
          throw StateError('storage unavailable');
        }
        return SharedPreferences.getInstance();
      },
      httpGetString: (uri) async {
        if (uri == manifestUri) {
          return manifestText;
        }
        failPersistence = true;
        return rulesText;
      },
    );

    final result = await guard.check(
      fields: const [CommunitySpeechField.threadBody('讨论软件')],
    );
    expect(result.type, CommunitySpeechDecisionType.blocked);
    expect(guard.speechDisabled, isTrue);
  });

  test('returns rulesUnavailable when the remote digest is invalid', () async {
    final guard = _guard(
      _rulesText([
        _rule(
          id: 'software-or-download',
          scopes: ['threadBody'],
          clauses: [
            {
              'anyOf': ['软件'],
            },
          ],
        ),
      ]),
      overrideDigest: List.filled(64, '0').join(),
    );

    final result = await guard.check(
      fields: const [CommunitySpeechField.threadBody('普通内容')],
    );
    expect(result.type, CommunitySpeechDecisionType.rulesUnavailable);
    expect(result.error, isA<CommunitySpeechRulesUnavailableException>());
  });

  test('uses a valid cache without another network request', () async {
    final rulesText = _rulesText([
      _rule(
        id: 'software-or-download',
        scopes: ['threadBody'],
        clauses: [
          {
            'anyOf': ['软件'],
          },
        ],
      ),
    ]);
    var requestCount = 0;
    final firstGuard = _guard(rulesText, onRequest: () => requestCount++);
    final firstResult = await firstGuard.check(
      fields: const [CommunitySpeechField.threadBody('普通内容')],
    );
    expect(firstResult.type, CommunitySpeechDecisionType.allowed);
    expect(requestCount, 2);

    final secondGuard = CommunitySpeechGuard(
      prefsLoader: SharedPreferences.getInstance,
      now: () => now.add(const Duration(minutes: 5)),
      httpGetString: (uri) async {
        throw StateError('cache should satisfy this check');
      },
    );
    final secondResult = await secondGuard.check(
      fields: const [CommunitySpeechField.threadBody('普通内容')],
    );
    expect(secondResult.type, CommunitySpeechDecisionType.allowed);
  });

  test('refreshes an expired cache and refuses when refresh fails', () async {
    final rulesText = _rulesText([
      _rule(
        id: 'software-or-download',
        scopes: ['threadBody'],
        clauses: [
          {
            'anyOf': ['软件'],
          },
        ],
      ),
    ]);
    final firstGuard = _guard(rulesText);
    expect(
      (await firstGuard.check(
        fields: const [CommunitySpeechField.threadBody('普通内容')],
      )).type,
      CommunitySpeechDecisionType.allowed,
    );

    final expiredGuard = CommunitySpeechGuard(
      prefsLoader: SharedPreferences.getInstance,
      now: () => now.add(const Duration(hours: 7)),
      httpGetString: (uri) async => throw StateError('offline'),
    );
    final result = await expiredGuard.check(
      fields: const [CommunitySpeechField.threadBody('普通内容')],
    );
    expect(result.type, CommunitySpeechDecisionType.rulesUnavailable);
  });

  test('rejects malformed rule sets', () async {
    final malformedRules = _rulesText([
      _rule(
        id: 'duplicate',
        scopes: ['threadBody'],
        clauses: [
          {
            'anyOf': ['软件'],
          },
        ],
      ),
      _rule(
        id: 'duplicate',
        scopes: ['threadBody'],
        clauses: [
          {
            'anyOf': ['下载'],
          },
        ],
      ),
    ]);
    final guard = _guard(malformedRules);
    final result = await guard.check(
      fields: const [CommunitySpeechField.threadBody('普通内容')],
    );
    expect(result.type, CommunitySpeechDecisionType.rulesUnavailable);
  });
}

CommunitySpeechGuard _guard(
  String rulesText, {
  String? overrideDigest,
  void Function()? onRequest,
}) {
  final manifestText = _manifestText(rulesText, digest: overrideDigest);
  final manifestUri = Uri.parse(
    'https://example.test/assets/community-moderation/manifest.json',
  );
  return CommunitySpeechGuard(
    manifestUri: manifestUri,
    now: () => DateTime.utc(2026, 7, 18, 12),
    prefsLoader: SharedPreferences.getInstance,
    httpGetString: (uri) async {
      onRequest?.call();
      if (uri == manifestUri) {
        return manifestText;
      }
      return rulesText;
    },
  );
}

String _manifestText(String rulesText, {String? digest}) {
  final rulesBytes = utf8.encode(rulesText);
  return jsonEncode({
    'schemaVersion': 1,
    'revision': 2026071801,
    'rulesPath': 'rules-2026071801.json',
    'sha256': digest ?? sha256.convert(rulesBytes).toString(),
    'size': rulesBytes.length,
    'cacheMaxAgeSeconds': 21600,
  });
}

String _rulesText(List<Map<String, Object>> rules) {
  return jsonEncode({
    'schemaVersion': 1,
    'revision': 2026071801,
    'normalization': 'compact-v1',
    'publishedAt': '2026-07-18T00:00:00Z',
    'rules': rules,
  });
}

Map<String, Object> _rule({
  required String id,
  required List<String> scopes,
  required List<Map<String, Object>> clauses,
}) {
  return {'id': id, 'scopes': scopes, 'clauses': clauses};
}
