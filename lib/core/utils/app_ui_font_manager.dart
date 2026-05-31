import 'dart:io';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImportedAppUiFont {
  const ImportedAppUiFont({
    required this.fontFamily,
    required this.fileName,
    required this.displayName,
  });

  final String fontFamily;
  final String fileName;
  final String displayName;
}

class AppUiFontManager {
  AppUiFontManager._internal();

  static final AppUiFontManager _instance = AppUiFontManager._internal();
  static final Logger _logger = Logger('APP_FONT');
  static const Set<String> _supportedExtensions = <String>{'.ttf', '.otf'};

  final Set<String> _loadedFontFamilies = <String>{};

  factory AppUiFontManager() => _instance;

  Future<ImportedAppUiFont> importFont({
    required String originalFileName,
    String? sourcePath,
    Uint8List? bytes,
  }) async {
    final extension = p.extension(originalFileName).toLowerCase();
    if (!_supportedExtensions.contains(extension)) {
      throw UnsupportedError('Only .ttf and .otf fonts are supported.');
    }

    final fontBytes = await _readFontBytes(
      sourcePath: sourcePath,
      bytes: bytes,
    );
    final hash = md5.convert(fontBytes);
    final fontFamily = 'novella_app_${hex.encode(hash.bytes).substring(0, 16)}';
    final fileName = '$fontFamily$extension';
    final fontsDir = await _getFontsDir();
    final fontFile = File(p.join(fontsDir.path, fileName));

    if (!await fontFile.exists()) {
      await fontFile.writeAsBytes(fontBytes, flush: true);
    }

    final loadedFamily = await loadFont(
      fontFamily: fontFamily,
      fileName: fileName,
    );
    if (loadedFamily == null) {
      throw StateError('Failed to load the imported font.');
    }

    return ImportedAppUiFont(
      fontFamily: loadedFamily,
      fileName: fileName,
      displayName: _displayNameFor(originalFileName),
    );
  }

  Future<String?> loadFont({
    required String fontFamily,
    required String fileName,
  }) async {
    if (_loadedFontFamilies.contains(fontFamily)) {
      return fontFamily;
    }

    try {
      final fontsDir = await _getFontsDir();
      final fontFile = File(p.join(fontsDir.path, fileName));
      if (!await fontFile.exists()) {
        _logger.info('Saved app font not found: $fileName');
        return null;
      }

      final fontBytes = await fontFile.readAsBytes();
      if (fontBytes.isEmpty) {
        _logger.info('Saved app font is empty: $fileName');
        return null;
      }

      final fontLoader = FontLoader(fontFamily);
      fontLoader.addFont(
        Future<ByteData>.value(ByteData.sublistView(fontBytes)),
      );
      await fontLoader.load();

      _loadedFontFamilies.add(fontFamily);
      _logger.info('Loaded app font: $fontFamily');
      return fontFamily;
    } catch (error, stackTrace) {
      _logger.warning(
        'Failed to load app font $fontFamily: $error',
        error,
        stackTrace,
      );
      return null;
    }
  }

  Future<void> deleteFont(String fileName) async {
    if (fileName.isEmpty) {
      return;
    }

    final fontsDir = await _getFontsDir();
    final fontFile = File(p.join(fontsDir.path, fileName));
    if (await fontFile.exists()) {
      await fontFile.delete();
    }
  }

  Future<void> pruneFonts({
    Set<String> keepFileNames = const <String>{},
  }) async {
    try {
      final fontsDir = await _getFontsDir();
      final files = fontsDir.listSync().whereType<File>();

      for (final file in files) {
        final name = p.basename(file.path);
        if (!keepFileNames.contains(name)) {
          await file.delete();
        }
      }
    } catch (error, stackTrace) {
      _logger.warning('Failed to prune app fonts: $error', error, stackTrace);
    }
  }

  Future<Directory> _getFontsDir() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final fontsDir = Directory(
      p.join(documentsDirectory.path, 'novella_app_ui_fonts'),
    );
    if (!await fontsDir.exists()) {
      await fontsDir.create(recursive: true);
    }
    return fontsDir;
  }

  Future<Uint8List> _readFontBytes({
    String? sourcePath,
    Uint8List? bytes,
  }) async {
    if (bytes != null && bytes.isNotEmpty) {
      return bytes;
    }

    if (sourcePath == null || sourcePath.isEmpty) {
      throw StateError('No font data was returned by the file picker.');
    }

    final file = File(sourcePath);
    if (!await file.exists()) {
      throw StateError('The selected font file is no longer available.');
    }

    final fileBytes = await file.readAsBytes();
    if (fileBytes.isEmpty) {
      throw StateError('The selected font file is empty.');
    }

    return fileBytes;
  }

  String _displayNameFor(String originalFileName) {
    final baseName = p.basenameWithoutExtension(originalFileName).trim();
    return baseName.isEmpty ? 'Imported Font' : baseName;
  }
}
