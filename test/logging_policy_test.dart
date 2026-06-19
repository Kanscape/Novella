import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app logging does not use dart developer logs', () {
    const scannedRoots = ['lib', 'packages/cloudflare_turnstile/lib'];
    final dartFiles = scannedRoots.expand(
      (root) => Directory(root)
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart')),
    );

    final violations = <String>[];
    for (final file in dartFiles) {
      final source = file.readAsStringSync();
      if (source.contains("import 'dart:developer'") ||
          source.contains('import "dart:developer"') ||
          source.contains('developer.log(') ||
          source.contains('dev.log(')) {
        violations.add(file.path);
      }
    }

    expect(violations, isEmpty);
  });

  test('devtools options file is not kept in the app repository root', () {
    expect(File('devtools_options.yaml').existsSync(), isFalse);
  });

  test('manual screen reporting stays on navigation-level pages', () {
    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    final violations = <String>[];
    for (final file in dartFiles) {
      final source = file.readAsStringSync();
      if (source.contains('TelemetryScreens.comments') ||
          source.contains('TelemetryScreens.communityCompose')) {
        violations.add(file.path);
      }
    }

    expect(violations, isEmpty);
  });

  test('settings preference changes are not usage telemetry', () {
    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    final violations = <String>[];
    for (final file in dartFiles) {
      final source = file.readAsStringSync();
      if (source.contains('setting_preference_changed') ||
          source.contains('settingPreferenceChanged')) {
        violations.add(file.path);
      }
    }

    expect(violations, isEmpty);
  });
}
