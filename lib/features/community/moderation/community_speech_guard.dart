import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:novella/features/community/moderation/community_moderation_rules.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef CommunityModerationHttpGetString = Future<String> Function(Uri uri);
typedef CommunityModerationPrefsLoader = Future<SharedPreferences> Function();
typedef CommunityModerationClock = DateTime Function();

const String communitySpeechDisabledPrefsKey = 'community_speech_disabled_v1';
const String communitySpeechDisabledMetadataPrefsKey =
    'community_speech_disabled_metadata_v1';
const String communityModerationRulesCachePrefsKey =
    'community_moderation_rules_cache_v1';

enum CommunitySpeechDecisionType {
  allowed,
  blocked,
  rulesUnavailable,
  alreadyDisabled,
}

class CommunitySpeechDecision {
  const CommunitySpeechDecision._({
    required this.type,
    this.ruleId,
    this.revision,
    this.error,
  });

  const CommunitySpeechDecision.allowed({required int revision})
    : this._(type: CommunitySpeechDecisionType.allowed, revision: revision);

  const CommunitySpeechDecision.blocked({
    required String ruleId,
    required int revision,
  }) : this._(
         type: CommunitySpeechDecisionType.blocked,
         ruleId: ruleId,
         revision: revision,
       );

  const CommunitySpeechDecision.rulesUnavailable({required Object error})
    : this._(type: CommunitySpeechDecisionType.rulesUnavailable, error: error);

  const CommunitySpeechDecision.alreadyDisabled()
    : this._(type: CommunitySpeechDecisionType.alreadyDisabled);

  final CommunitySpeechDecisionType type;
  final String? ruleId;
  final int? revision;
  final Object? error;

  bool get canPublish => type == CommunitySpeechDecisionType.allowed;
  bool get isBlocked => type == CommunitySpeechDecisionType.blocked;
  bool get areRulesUnavailable =>
      type == CommunitySpeechDecisionType.rulesUnavailable;
}

class CommunitySpeechGuard extends ChangeNotifier {
  factory CommunitySpeechGuard({
    CommunityModerationHttpGetString? httpGetString,
    CommunityModerationPrefsLoader? prefsLoader,
    Uri? manifestUri,
    CommunityModerationClock? now,
  }) {
    if (httpGetString == null &&
        prefsLoader == null &&
        manifestUri == null &&
        now == null) {
      return instance;
    }
    return CommunitySpeechGuard._(
      httpGetString: httpGetString,
      prefsLoader: prefsLoader,
      manifestUri: manifestUri,
      now: now,
    );
  }

  CommunitySpeechGuard._({
    CommunityModerationHttpGetString? httpGetString,
    CommunityModerationPrefsLoader? prefsLoader,
    Uri? manifestUri,
    CommunityModerationClock? now,
  }) : _httpGetString = httpGetString ?? _defaultHttpGetString,
       _prefsLoader = prefsLoader ?? SharedPreferences.getInstance,
       manifestUri = manifestUri ?? Uri.parse(defaultManifestUrl),
       _now = now ?? DateTime.now;

  static final CommunitySpeechGuard instance = CommunitySpeechGuard._();
  static final Logger _logger = Logger('CommunitySpeechGuard');

  static const String defaultManifestUrl =
      'https://novella.celia.sh/assets/community-moderation/manifest.json';
  static const Duration defaultRequestTimeout = Duration(seconds: 10);

  final CommunityModerationHttpGetString _httpGetString;
  final CommunityModerationPrefsLoader _prefsLoader;
  final CommunityModerationClock _now;
  final Uri manifestUri;

  _LoadedCommunityModerationRules? _inMemoryRules;
  bool _speechDisabled = false;

  bool get speechDisabled => _speechDisabled;

  Future<bool> isSpeechDisabled() async {
    if (_speechDisabled) {
      return true;
    }
    final prefs = await _prefsLoader();
    if (prefs.getBool(communitySpeechDisabledPrefsKey) ?? false) {
      _markSpeechDisabled();
    }
    return _speechDisabled;
  }

  Future<CommunitySpeechDecision> check({
    required List<CommunitySpeechField> fields,
  }) async {
    try {
      if (await isSpeechDisabled()) {
        return const CommunitySpeechDecision.alreadyDisabled();
      }

      final loadedRules = await _loadRules();
      final rules = loadedRules.rules;
      final matchedRule = rules.firstMatch(fields);
      if (matchedRule == null) {
        return CommunitySpeechDecision.allowed(revision: rules.revision);
      }

      await _disableSpeech(rule: matchedRule, revision: rules.revision);
      return CommunitySpeechDecision.blocked(
        ruleId: matchedRule.id,
        revision: rules.revision,
      );
    } catch (error, stackTrace) {
      _logger.warning(
        'Community speech moderation check failed',
        error,
        stackTrace,
      );
      return CommunitySpeechDecision.rulesUnavailable(
        error: CommunitySpeechRulesUnavailableException(error),
      );
    }
  }

  Future<CommunitySpeechDecision> evaluate({
    required List<CommunitySpeechField> fields,
  }) {
    return check(fields: fields);
  }

  Future<_LoadedCommunityModerationRules> _loadRules() async {
    final inMemoryRules = _inMemoryRules;
    if (inMemoryRules != null && inMemoryRules.isValidAt(_now())) {
      return inMemoryRules;
    }

    final cachedRules = await _readCachedRules();
    if (cachedRules != null) {
      _inMemoryRules = cachedRules;
      return cachedRules;
    }

    final fetchedRules = await _fetchRules();
    _inMemoryRules = fetchedRules;
    return fetchedRules;
  }

  Future<_LoadedCommunityModerationRules?> _readCachedRules() async {
    final prefs = await _prefsLoader();
    final cacheText = prefs.getString(communityModerationRulesCachePrefsKey);
    if (cacheText == null) {
      return null;
    }

    try {
      final decoded = jsonDecode(cacheText);
      if (decoded is! Map) {
        throw const CommunityModerationFormatException(
          'Cached moderation data must be an object',
        );
      }
      final rawManifest = decoded['manifest'];
      final rulesText = decoded['rulesText'];
      final rawFetchedAt = decoded['fetchedAt'];
      final fetchedAt = rawFetchedAt is String
          ? DateTime.tryParse(rawFetchedAt)
          : null;
      if (rawManifest is! Map || rulesText is! String || fetchedAt == null) {
        throw const CommunityModerationFormatException(
          'Cached moderation data is incomplete',
        );
      }

      final manifest = CommunityModerationManifest.fromJson(rawManifest);
      if (!manifest.isCacheValid(fetchedAt: fetchedAt, now: _now())) {
        throw const CommunityModerationFormatException(
          'Cached moderation data has expired',
        );
      }
      final rules = _parseAndValidateRules(
        manifest: manifest,
        rulesText: rulesText,
      );
      return _LoadedCommunityModerationRules(
        rules: rules,
        validUntil: fetchedAt.toUtc().add(
          Duration(seconds: manifest.cacheMaxAgeSeconds),
        ),
      );
    } catch (_) {
      await prefs.remove(communityModerationRulesCachePrefsKey);
      return null;
    }
  }

  Future<_LoadedCommunityModerationRules> _fetchRules() async {
    final manifestText = await _httpGetString(manifestUri);
    final manifestJson = jsonDecode(manifestText);
    if (manifestJson is! Map) {
      throw const CommunityModerationFormatException(
        'Community moderation manifest must be an object',
      );
    }
    final manifest = CommunityModerationManifest.fromJson(manifestJson);

    final rulesText = await _httpGetString(
      manifest.resolveRulesUri(manifestUri),
    );
    final rules = _parseAndValidateRules(
      manifest: manifest,
      rulesText: rulesText,
    );
    final fetchedAt = _now().toUtc();

    try {
      final prefs = await _prefsLoader();
      final cached = await prefs.setString(
        communityModerationRulesCachePrefsKey,
        jsonEncode({
          'manifest': manifest.toJson(),
          'rulesText': rulesText,
          'fetchedAt': fetchedAt.toIso8601String(),
        }),
      );
      if (!cached) {
        _logger.warning('Failed to cache community moderation rules');
      }
    } catch (error, stackTrace) {
      _logger.warning(
        'Failed to cache community moderation rules',
        error,
        stackTrace,
      );
    }
    return _LoadedCommunityModerationRules(
      rules: rules,
      validUntil: fetchedAt.add(Duration(seconds: manifest.cacheMaxAgeSeconds)),
    );
  }

  CommunityModerationRuleSet _parseAndValidateRules({
    required CommunityModerationManifest manifest,
    required String rulesText,
  }) {
    final rulesBytes = utf8.encode(rulesText);
    if (rulesBytes.length != manifest.size) {
      throw const CommunityModerationFormatException(
        'Community moderation rules size does not match the manifest',
      );
    }
    final digest = sha256.convert(rulesBytes).toString();
    if (digest != manifest.sha256Digest) {
      throw const CommunityModerationFormatException(
        'Community moderation rules digest does not match the manifest',
      );
    }

    final rulesJson = jsonDecode(rulesText);
    if (rulesJson is! Map) {
      throw const CommunityModerationFormatException(
        'Community moderation rules must be an object',
      );
    }
    final rules = CommunityModerationRuleSet.fromJson(rulesJson);
    if (rules.revision != manifest.revision) {
      throw const CommunityModerationFormatException(
        'Community moderation revision does not match the manifest',
      );
    }
    return rules;
  }

  Future<void> _disableSpeech({
    required CommunityModerationRule rule,
    required int revision,
  }) async {
    _markSpeechDisabled();
    try {
      final prefs = await _prefsLoader();
      final disabledSaved = await prefs.setBool(
        communitySpeechDisabledPrefsKey,
        true,
      );
      final metadataSaved = await prefs.setString(
        communitySpeechDisabledMetadataPrefsKey,
        jsonEncode({
          'revision': revision,
          'ruleId': rule.id,
          'triggeredAt': _now().toUtc().toIso8601String(),
        }),
      );
      if (!disabledSaved || !metadataSaved) {
        _logger.warning('Failed to persist community speech disabled state');
      }
    } catch (error, stackTrace) {
      _logger.warning(
        'Failed to persist community speech disabled state',
        error,
        stackTrace,
      );
    }
  }

  void _markSpeechDisabled() {
    if (_speechDisabled) {
      return;
    }
    _speechDisabled = true;
    notifyListeners();
  }

  static Future<String> _defaultHttpGetString(Uri uri) async {
    final response = await http.get(uri).timeout(defaultRequestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CommunityModerationHttpException(
        statusCode: response.statusCode,
        reasonPhrase: response.reasonPhrase,
      );
    }
    return utf8.decode(response.bodyBytes);
  }
}

class _LoadedCommunityModerationRules {
  const _LoadedCommunityModerationRules({
    required this.rules,
    required this.validUntil,
  });

  final CommunityModerationRuleSet rules;
  final DateTime validUntil;

  bool isValidAt(DateTime now) => validUntil.isAfter(now.toUtc());
}

class CommunitySpeechRulesUnavailableException implements Exception {
  const CommunitySpeechRulesUnavailableException(this.cause);

  final Object cause;

  @override
  String toString() => 'Community speech rules are unavailable: $cause';
}

class CommunityModerationHttpException implements Exception {
  const CommunityModerationHttpException({
    required this.statusCode,
    this.reasonPhrase,
  });

  final int statusCode;
  final String? reasonPhrase;

  @override
  String toString() {
    final reason = reasonPhrase;
    return reason == null || reason.isEmpty
        ? 'Community moderation HTTP $statusCode'
        : 'Community moderation HTTP $statusCode: $reason';
  }
}
