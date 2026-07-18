import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

void main() {
  final assetsDirectory = Directory('web/assets/community-moderation');
  final manifestFile = File('${assetsDirectory.path}/manifest.json');

  test('manifest references an intact versioned rules file', () {
    final manifest = _readObject(manifestFile);

    expect(manifest['schemaVersion'], 1);
    expect(manifest['revision'], isA<int>());
    expect(manifest['cacheMaxAgeSeconds'], 21600);
    expect(manifest.containsKey('expiresAt'), isFalse);

    final rulesPath = manifest['rulesPath'];
    expect(rulesPath, matches(r'^rules-[0-9]{10}\.json$'));

    final rulesFile = File('${assetsDirectory.path}/$rulesPath');
    expect(rulesFile.existsSync(), isTrue);

    final bytes = rulesFile.readAsBytesSync();
    expect(manifest['size'], bytes.length);
    expect(manifest['sha256'], sha256.convert(bytes).toString());

    final rulesDocument = _readObject(rulesFile);
    expect(rulesDocument['schemaVersion'], manifest['schemaVersion']);
    expect(rulesDocument['revision'], manifest['revision']);
  });

  test('rules use supported fields and non-empty unique terms', () {
    final manifest = _readObject(manifestFile);
    final rulesDocument = _readObject(
      File('${assetsDirectory.path}/${manifest['rulesPath']}'),
    );

    expect(rulesDocument['normalization'], 'compact-v1');
    expect(
      DateTime.tryParse(rulesDocument['publishedAt'] as String),
      isNotNull,
    );

    final rules = rulesDocument['rules'] as List<dynamic>;
    expect(rules, isNotEmpty);

    final ids = <String>{};
    const supportedScopes = {'threadTitle', 'threadBody', 'reply'};

    for (final value in rules) {
      final rule = value as Map<String, dynamic>;
      expect(
        ids.add(rule['id'] as String),
        isTrue,
        reason: 'duplicate rule ID',
      );

      final scopes = (rule['scopes'] as List<dynamic>).cast<String>();
      expect(scopes, isNotEmpty);
      expect(scopes.every(supportedScopes.contains), isTrue);

      final clauses = rule['clauses'] as List<dynamic>;
      expect(clauses, isNotEmpty);

      for (final value in clauses) {
        final clause = value as Map<String, dynamic>;
        final terms = (clause['anyOf'] as List<dynamic>).cast<String>();
        expect(terms, isNotEmpty);
        expect(terms.every((term) => term.trim().isNotEmpty), isTrue);
        expect(terms.toSet().length, terms.length);
      }
    }
  });

  test('initial rules express the approved OR and AND relationships', () {
    final manifest = _readObject(manifestFile);
    final rulesDocument = _readObject(
      File('${assetsDirectory.path}/${manifest['rulesPath']}'),
    );
    final rules = {
      for (final value in rulesDocument['rules'] as List<dynamic>)
        (value as Map<String, dynamic>)['id'] as String: value,
    };

    expect(_clauses(rules['software-or-download']!), [
      ['软件', '下载'],
    ]);
    expect(_clauses(rules['request-upload-or-send']!), [
      ['求'],
      ['上传', '发'],
    ]);
  });
}

Map<String, dynamic> _readObject(File file) {
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

List<List<String>> _clauses(Map<String, dynamic> rule) {
  return [
    for (final value in rule['clauses'] as List<dynamic>)
      ((value as Map<String, dynamic>)['anyOf'] as List<dynamic>)
          .cast<String>(),
  ];
}
