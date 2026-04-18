import 'dart:convert';
import 'dart:io';

import 'package:novella_site/src/content/repository_builder.dart';
import 'package:novella_site/src/content/site_data_loader.dart';

Future<void> main() async {
  final environment = Platform.environment;
  final outputPath =
      environment['REPOSITORY_OUTPUT_PATH'] ?? 'build/jaspr/repository.json';
  final siteDataPath =
      environment['SITE_DATA_PATH'] ?? '.generated/site_data.json';

  try {
    final loader = SiteDataLoader(generatedPath: siteDataPath);
    final siteData = await loader.load();
    final builder = RepositoryBuilder(
      config: RepositoryBuilderConfig.fromEnvironment(environment),
    );
    final sourceJson = builder.build(siteData);

    final outputFile = File(outputPath)..createSync(recursive: true);
    outputFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(sourceJson),
    );

    stdout.writeln('Generated repository -> ${outputFile.path}');
  } catch (error, stackTrace) {
    stderr.writeln('Failed to generate repository: $error');
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}
