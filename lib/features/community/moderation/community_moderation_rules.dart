enum CommunitySpeechScope {
  threadTitle,
  threadBody,
  reply;

  static CommunitySpeechScope parse(String value) {
    for (final scope in values) {
      if (scope.name == value) {
        return scope;
      }
    }
    throw CommunityModerationFormatException(
      'Unknown community speech scope: $value',
    );
  }
}

class CommunitySpeechField {
  const CommunitySpeechField({required this.scope, required this.text});

  const CommunitySpeechField.threadTitle(String text)
    : this(scope: CommunitySpeechScope.threadTitle, text: text);

  const CommunitySpeechField.threadBody(String text)
    : this(scope: CommunitySpeechScope.threadBody, text: text);

  const CommunitySpeechField.reply(String text)
    : this(scope: CommunitySpeechScope.reply, text: text);

  final CommunitySpeechScope scope;
  final String text;
}

class CommunityModerationManifest {
  const CommunityModerationManifest({
    required this.schemaVersion,
    required this.revision,
    required this.rulesPath,
    required this.sha256Digest,
    required this.size,
    required this.cacheMaxAgeSeconds,
  });

  factory CommunityModerationManifest.fromJson(Map<dynamic, dynamic> json) {
    final schemaVersion = _requiredPositiveInt(json, 'schemaVersion');
    if (schemaVersion != supportedSchemaVersion) {
      throw CommunityModerationFormatException(
        'Unsupported community moderation manifest schema: $schemaVersion',
      );
    }

    final rulesPath = _requiredString(json, 'rulesPath');
    final parsedRulesPath = Uri.tryParse(rulesPath);
    if (parsedRulesPath == null ||
        parsedRulesPath.hasScheme ||
        parsedRulesPath.hasAuthority) {
      throw const CommunityModerationFormatException(
        'rulesPath must be a relative URL',
      );
    }

    final digest = _requiredString(json, 'sha256').toLowerCase();
    if (!_sha256Pattern.hasMatch(digest)) {
      throw const CommunityModerationFormatException(
        'sha256 must be a 64-character hexadecimal digest',
      );
    }

    final cacheMaxAgeSeconds = _requiredPositiveInt(json, 'cacheMaxAgeSeconds');
    if (cacheMaxAgeSeconds < minimumCacheMaxAgeSeconds ||
        cacheMaxAgeSeconds > maximumCacheMaxAgeSeconds) {
      throw CommunityModerationFormatException(
        'cacheMaxAgeSeconds must be between $minimumCacheMaxAgeSeconds and '
        '$maximumCacheMaxAgeSeconds',
      );
    }

    return CommunityModerationManifest(
      schemaVersion: schemaVersion,
      revision: _requiredPositiveInt(json, 'revision'),
      rulesPath: rulesPath,
      sha256Digest: digest,
      size: _requiredPositiveInt(json, 'size'),
      cacheMaxAgeSeconds: cacheMaxAgeSeconds,
    );
  }

  static const int supportedSchemaVersion = 1;
  static const int minimumCacheMaxAgeSeconds = 60;
  static const int maximumCacheMaxAgeSeconds = 86400;
  static final RegExp _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');

  final int schemaVersion;
  final int revision;
  final String rulesPath;
  final String sha256Digest;
  final int size;
  final int cacheMaxAgeSeconds;

  bool isCacheValid({required DateTime fetchedAt, required DateTime now}) {
    final utcFetchedAt = fetchedAt.toUtc();
    final utcNow = now.toUtc();
    if (utcFetchedAt.isAfter(utcNow)) {
      return false;
    }
    return utcNow.difference(utcFetchedAt) <
        Duration(seconds: cacheMaxAgeSeconds);
  }

  Uri resolveRulesUri(Uri manifestUri) => manifestUri.resolve(rulesPath);

  Map<String, Object> toJson() => {
    'schemaVersion': schemaVersion,
    'revision': revision,
    'rulesPath': rulesPath,
    'sha256': sha256Digest,
    'size': size,
    'cacheMaxAgeSeconds': cacheMaxAgeSeconds,
  };
}

class CommunityModerationRuleSet {
  CommunityModerationRuleSet({
    required this.schemaVersion,
    required this.revision,
    required this.normalization,
    required this.publishedAt,
    required List<CommunityModerationRule> rules,
  }) : rules = List.unmodifiable(rules);

  factory CommunityModerationRuleSet.fromJson(Map<dynamic, dynamic> json) {
    final schemaVersion = _requiredPositiveInt(json, 'schemaVersion');
    if (schemaVersion != supportedSchemaVersion) {
      throw CommunityModerationFormatException(
        'Unsupported community moderation rules schema: $schemaVersion',
      );
    }

    final normalization = _requiredString(json, 'normalization');
    if (normalization != supportedNormalization) {
      throw CommunityModerationFormatException(
        'Unsupported community moderation normalization: $normalization',
      );
    }

    final rawRules = json['rules'];
    if (rawRules is! List || rawRules.isEmpty) {
      throw const CommunityModerationFormatException(
        'rules must be a non-empty list',
      );
    }

    final rules = <CommunityModerationRule>[];
    final ids = <String>{};
    for (final rawRule in rawRules) {
      if (rawRule is! Map) {
        throw const CommunityModerationFormatException(
          'Each rule must be an object',
        );
      }
      final rule = CommunityModerationRule.fromJson(rawRule);
      if (!ids.add(rule.id)) {
        throw CommunityModerationFormatException(
          'Duplicate community moderation rule id: ${rule.id}',
        );
      }
      rules.add(rule);
    }

    return CommunityModerationRuleSet(
      schemaVersion: schemaVersion,
      revision: _requiredPositiveInt(json, 'revision'),
      normalization: normalization,
      publishedAt: _requiredDateTime(json, 'publishedAt'),
      rules: rules,
    );
  }

  static const int supportedSchemaVersion = 1;
  static const String supportedNormalization = 'compact-v1';

  final int schemaVersion;
  final int revision;
  final String normalization;
  final DateTime publishedAt;
  final List<CommunityModerationRule> rules;

  CommunityModerationRule? firstMatch(List<CommunitySpeechField> fields) {
    final normalizedFields = <CommunitySpeechScope, List<String>>{};
    for (final field in fields) {
      final normalized = normalizeCommunitySpeechText(field.text);
      if (normalized.isEmpty) {
        continue;
      }
      normalizedFields.putIfAbsent(field.scope, () => []).add(normalized);
    }

    for (final rule in rules) {
      if (rule.matches(normalizedFields)) {
        return rule;
      }
    }
    return null;
  }
}

class CommunityModerationRule {
  CommunityModerationRule({
    required this.id,
    required Set<CommunitySpeechScope> scopes,
    required List<CommunityModerationClause> clauses,
  }) : scopes = Set.unmodifiable(scopes),
       clauses = List.unmodifiable(clauses);

  factory CommunityModerationRule.fromJson(Map<dynamic, dynamic> json) {
    final rawScopes = json['scopes'];
    if (rawScopes is! List || rawScopes.isEmpty) {
      throw const CommunityModerationFormatException(
        'Rule scopes must be a non-empty list',
      );
    }
    final scopes = <CommunitySpeechScope>{};
    for (final rawScope in rawScopes) {
      if (rawScope is! String || rawScope.trim().isEmpty) {
        throw const CommunityModerationFormatException(
          'Rule scope must be a non-empty string',
        );
      }
      scopes.add(CommunitySpeechScope.parse(rawScope.trim()));
    }

    final rawClauses = json['clauses'];
    if (rawClauses is! List || rawClauses.isEmpty) {
      throw const CommunityModerationFormatException(
        'Rule clauses must be a non-empty list',
      );
    }
    final clauses = <CommunityModerationClause>[];
    for (final rawClause in rawClauses) {
      if (rawClause is! Map) {
        throw const CommunityModerationFormatException(
          'Each rule clause must be an object',
        );
      }
      clauses.add(CommunityModerationClause.fromJson(rawClause));
    }

    return CommunityModerationRule(
      id: _requiredString(json, 'id'),
      scopes: scopes,
      clauses: clauses,
    );
  }

  final String id;
  final Set<CommunitySpeechScope> scopes;
  final List<CommunityModerationClause> clauses;

  bool matches(Map<CommunitySpeechScope, List<String>> fields) {
    final candidateTexts = <String>[
      for (final scope in scopes) ...?fields[scope],
    ];
    if (candidateTexts.isEmpty) {
      return false;
    }

    return clauses.every(
      (clause) => candidateTexts.any(clause.matchesNormalizedText),
    );
  }
}

class CommunityModerationClause {
  CommunityModerationClause({required List<String> anyOf})
    : anyOf = List.unmodifiable(anyOf);

  factory CommunityModerationClause.fromJson(Map<dynamic, dynamic> json) {
    final rawTerms = json['anyOf'];
    if (rawTerms is! List || rawTerms.isEmpty) {
      throw const CommunityModerationFormatException(
        'Clause anyOf must be a non-empty list',
      );
    }

    final terms = <String>[];
    final seen = <String>{};
    for (final rawTerm in rawTerms) {
      if (rawTerm is! String || rawTerm.trim().isEmpty) {
        throw const CommunityModerationFormatException(
          'Clause terms must be non-empty strings',
        );
      }
      final term = normalizeCommunitySpeechText(rawTerm);
      if (term.isEmpty) {
        throw const CommunityModerationFormatException(
          'Clause terms cannot normalize to an empty string',
        );
      }
      if (seen.add(term)) {
        terms.add(term);
      }
    }

    return CommunityModerationClause(anyOf: terms);
  }

  final List<String> anyOf;

  bool matchesNormalizedText(String text) {
    return anyOf.any(text.contains);
  }
}

String normalizeCommunitySpeechText(String text) {
  final widthFolded = String.fromCharCodes(
    text.runes.map((codePoint) {
      if (codePoint >= 0xff01 && codePoint <= 0xff5e) {
        return codePoint - 0xfee0;
      }
      if (codePoint == 0x3000) {
        return 0x20;
      }
      return codePoint;
    }),
  );
  return widthFolded.toLowerCase().replaceAll(
    _communitySpeechIgnoredCharacters,
    '',
  );
}

final RegExp _communitySpeechIgnoredCharacters = RegExp(
  r'[\p{P}\p{S}\p{Z}\p{C}]',
  unicode: true,
);

class CommunityModerationFormatException implements Exception {
  const CommunityModerationFormatException(this.message);

  final String message;

  @override
  String toString() => 'CommunityModerationFormatException: $message';
}

int _requiredPositiveInt(Map<dynamic, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value <= 0) {
    throw CommunityModerationFormatException('$key must be a positive integer');
  }
  return value;
}

String _requiredString(Map<dynamic, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw CommunityModerationFormatException('$key must be a non-empty string');
  }
  return value.trim();
}

DateTime _requiredDateTime(Map<dynamic, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw CommunityModerationFormatException('$key must be an ISO 8601 date');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw CommunityModerationFormatException('$key must be an ISO 8601 date');
  }
  return parsed.toUtc();
}
