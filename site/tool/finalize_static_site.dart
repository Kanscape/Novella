import 'dart:io';

Future<void> main() async {
  final buildDir = Directory('build/jaspr');
  final previewDir = Directory('${buildDir.path}/_not-found-preview');
  final previewFile = File('${previewDir.path}/index.html');
  final output404 = File('${buildDir.path}/404.html');
  final sitemapFile = File('${buildDir.path}/sitemap.xml');

  if (!await previewFile.exists()) {
    stderr.writeln(
      'Missing pre-rendered not found page at ${previewFile.path}. '
      'Run "jaspr build" before finalizing the static site.',
    );
    exitCode = 1;
    return;
  }

  await output404.writeAsString(await previewFile.readAsString());

  if (await previewDir.exists()) {
    await previewDir.delete(recursive: true);
  }

  if (await sitemapFile.exists()) {
    final content = await sitemapFile.readAsString();
    final cleaned = content.replaceAll(
      RegExp(
        r'\s*<url>\s*<loc>[^<]*/_not-found-preview/?</loc>.*?</url>\s*',
        dotAll: true,
      ),
      '\n',
    );

    if (cleaned != content) {
      await sitemapFile.writeAsString(cleaned);
    }
  }
}
