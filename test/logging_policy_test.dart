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
}
