import 'package:shared_preferences/shared_preferences.dart';

class SettingsSyncCodec {
  static const String enabledKey = 'setting_sync_appSettingsEnabled';
  static const String needsCloudAdoptionKey =
      'setting_sync_appSettingsNeedsCloudAdoption';

  static const Set<String> excludedKeys = {
    'setting_iosDisplayStyle',
    'setting_useSystemColor',
    'setting_dynamicSchemeVariant',
    'setting_appFontFamily',
    'setting_appFontFileName',
    'setting_appFontLabel',
    'setting_readerBatteryIndicatorStyle',
    'setting_readerPagedShowSystemStatusBar',
    enabledKey,
    needsCloudAdoptionKey,
  };

  static const Map<String, Object> _generalDefaults = {
    'setting_fontSize': 18.0,
    'setting_readerFirstLineIndent': false,
    'setting_readerLineHeight': 1.6,
    'setting_readerParagraphSpacing': 0.0,
    'setting_readerSidePadding': 30.0,
    'setting_readerViewMode': 'paged',
    'setting_readerPagedNoAnimation': false,
    'setting_readerPagedShowSystemStatusBar': false,
    'setting_readerBatteryIndicatorStyle': 'text',
    'setting_readerImagePreviewOpenOnLongPress': false,
    'setting_theme': 'system',
    'setting_convertType': 'none',
    'setting_fontCacheEnabled': true,
    'setting_fontCacheLimit': 30,
    'setting_homeRankType': 'weekly',
    'setting_oledBlack': false,
    'setting_cleanChapterTitle': true,
    'setting_cleanChapterTitleScopes': <String>[
      'continueReading',
      'readerTitle',
    ],
    'setting_ignoreJapanese': false,
    'setting_ignoreAI': false,
    'setting_ignoreLevel6': true,
    'setting_startupTabIndex': 0,
    'setting_homeModuleOrder': <String>[
      'stats',
      'continueReading',
      'ranking',
      'recentlyUpdated',
    ],
    'setting_enabledHomeModules': <String>[
      'stats',
      'continueReading',
      'ranking',
      'recentlyUpdated',
    ],
    'setting_bookDetailCacheEnabled': true,
    'setting_bookTypeBadgeScopes': <String>[
      'ranking',
      'recent',
      'search',
      'shelf',
      'history',
    ],
    'setting_coverColorExtraction': false,
    'setting_seedColorValue': 0xFFB71C1C,
    'setting_useCustomTheme': false,
    'setting_readerUseThemeBackground': true,
    'setting_readerBackgroundColor': 0xFFFFFFFF,
    'setting_readerTextColor': 0xFF000000,
    'setting_readerPresetIndex': 0,
    'setting_readerUseCustomColor': false,
    'setting_autoCheckUpdate': true,
    'setting_ignoredUpdateVersion': '',
  };

  static bool isEnabled(SharedPreferences prefs) =>
      prefs.getBool(enabledKey) ?? false;

  static bool needsCloudAdoption(SharedPreferences prefs) =>
      prefs.getBool(needsCloudAdoptionKey) ?? false;

  static Future<void> setEnabled(SharedPreferences prefs, bool enabled) async {
    final wasEnabled = isEnabled(prefs);
    await prefs.setBool(enabledKey, enabled);

    if (enabled && !wasEnabled) {
      await prefs.setBool(needsCloudAdoptionKey, true);
      return;
    }

    if (!enabled) {
      await prefs.setBool(needsCloudAdoptionKey, false);
    }
  }

  static Future<void> markCloudAdopted(SharedPreferences prefs) async {
    await prefs.setBool(needsCloudAdoptionKey, false);
  }

  static Map<String, dynamic> collectGeneralSettings(SharedPreferences prefs) {
    final data = <String, dynamic>{};

    for (final entry in _generalDefaults.entries) {
      if (excludedKeys.contains(entry.key)) {
        continue;
      }
      data[entry.key] = _readValue(prefs, entry.key, entry.value);
    }

    return data;
  }

  static Future<void> applyRemoteSettingsIfEnabled(
    SharedPreferences prefs,
    Map<String, dynamic> data,
  ) async {
    if (!isEnabled(prefs)) {
      return;
    }

    for (final entry in _generalDefaults.entries) {
      final key = entry.key;
      if (excludedKeys.contains(key) || !data.containsKey(key)) {
        continue;
      }
      await _writeValue(prefs, key, data[key], entry.value);
    }
  }

  static dynamic _readValue(
    SharedPreferences prefs,
    String key,
    Object defaultValue,
  ) {
    if (defaultValue is bool) {
      return prefs.getBool(key) ?? defaultValue;
    }
    if (defaultValue is int) {
      return prefs.getInt(key) ?? defaultValue;
    }
    if (defaultValue is double) {
      return prefs.getDouble(key) ?? defaultValue;
    }
    if (defaultValue is String) {
      return prefs.getString(key) ?? defaultValue;
    }
    if (defaultValue is List<String>) {
      return prefs.getStringList(key) ?? List<String>.from(defaultValue);
    }
    return defaultValue;
  }

  static Future<void> _writeValue(
    SharedPreferences prefs,
    String key,
    Object? value,
    Object defaultValue,
  ) async {
    if (defaultValue is bool && value is bool) {
      await prefs.setBool(key, value);
      return;
    }
    if (defaultValue is int && value is num) {
      await prefs.setInt(key, value.toInt());
      return;
    }
    if (defaultValue is double && value is num) {
      await prefs.setDouble(key, value.toDouble());
      return;
    }
    if (defaultValue is String && value is String) {
      await prefs.setString(key, value);
      return;
    }
    if (defaultValue is List<String> && value is List) {
      final strings = <String>[];
      for (final item in value) {
        if (item is! String) {
          return;
        }
        strings.add(item);
      }
      await prefs.setStringList(key, strings);
    }
  }
}
