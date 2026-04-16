import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:novella/core/utils/app_ui_font_manager.dart';
import 'package:novella/features/book/book_detail_page.dart'
    show BookDetailPageState;
import 'package:novella/data/services/book_info_cache_service.dart';

enum ReaderViewMode { scroll, paged }

enum ReaderBatteryIndicatorStyle { capsule, capsuleDynamic, text }

/// 设置状态模型
class AppSettings {
  final bool isLoaded;
  final double fontSize;
  final bool readerFirstLineIndent;
  final double readerLineHeight;
  final double readerParagraphSpacing;
  final double readerSidePadding;
  final ReaderViewMode readerViewMode;
  final bool readerPagedNoAnimation;
  final ReaderBatteryIndicatorStyle readerBatteryIndicatorStyle;
  final String theme; // 'system'（系统）, 'light'（浅色）, 'dark'（深色）
  final String appFontFamily;
  final String appFontFileName;
  final String appFontLabel;
  final String version; // App 版本号
  final String convertType; // 'none'（关闭）, 't2s'（繁转简）, 's2t'（简转繁）
  final bool fontCacheEnabled;
  final int fontCacheLimit; // 10-60
  final String homeRankType; // 'daily'（日）, 'weekly'（周）, 'monthly'（月）
  final bool oledBlack;
  final List<String> cleanChapterTitleScopes;
  final bool ignoreJapanese;
  final bool ignoreAI;
  final bool ignoreLevel6;
  final int startupTabIndex;
  final List<String> homeModuleOrder;
  final List<String> enabledHomeModules;
  final bool bookDetailCacheEnabled;
  final List<String> bookTypeBadgeScopes;
  final bool coverColorExtraction; // 封面取色开关
  final int seedColorValue; // 主题种子色 ARGB 值
  final bool useSystemColor; // 是否使用系统动态颜色
  final int dynamicSchemeVariant; // 动态配色方案变体索引 (0: TonalSpot, etc)
  final bool useCustomTheme; // 是否使用自定义主题模式 (Tab 状态)
  // 阅读背景颜色设置
  final bool readerUseThemeBackground; // 是否使用主题色背景（默认 true）
  final int readerBackgroundColor; // 自定义背景色 ARGB
  final int readerTextColor; // 自定义文字色 ARGB
  final int readerPresetIndex; // 预设方案索引 (0-4)
  final bool readerUseCustomColor; // 是否使用自定颜色 Tab (false = 预设)
  // iOS 显示样式（仅 iOS 平台有效）
  // 'md3' = Material Design 3（默认）, 'ios18' = iOS 18, 'ios26' = iOS 26 液态玻璃
  final String iosDisplayStyle;
  final bool autoCheckUpdate;
  final String ignoredUpdateVersion; // 忽略的更新版本号

  static const defaultModuleOrder = [
    'stats',
    'continueReading',
    'ranking',
    'recentlyUpdated',
  ];
  static const defaultEnabledModules = [
    'stats',
    'continueReading',
    'ranking',
    'recentlyUpdated',
  ];
  static const defaultBookTypeBadgeScopes = [
    'ranking',
    'recent',
    'search',
    'shelf',
    'history',
  ];
  static const cleanChapterTitleContinueReadingScope = 'continueReading';
  static const cleanChapterTitleReaderTitleScope = 'readerTitle';
  static const defaultCleanChapterTitleScopes = [
    cleanChapterTitleContinueReadingScope,
    cleanChapterTitleReaderTitleScope,
  ];

  const AppSettings({
    this.isLoaded = false,
    this.fontSize = 18.0,
    this.readerFirstLineIndent = false,
    this.readerLineHeight = 1.6,
    this.readerParagraphSpacing = 0.0,
    this.readerSidePadding = 30.0,
    this.readerViewMode = ReaderViewMode.paged,
    this.readerPagedNoAnimation = false,
    this.readerBatteryIndicatorStyle = ReaderBatteryIndicatorStyle.text,
    this.theme = 'system',
    this.appFontFamily = '',
    this.appFontFileName = '',
    this.appFontLabel = '',
    this.version = '', // 默认空，加载后更新
    this.convertType = 'none',
    this.fontCacheEnabled = true,
    this.fontCacheLimit = 30,
    this.homeRankType = 'weekly',
    this.oledBlack = false,
    this.cleanChapterTitleScopes = defaultCleanChapterTitleScopes,
    this.ignoreJapanese = false,
    this.ignoreAI = false,
    this.ignoreLevel6 = true, // 默认开启 - 隐藏 Level6 书籍
    this.startupTabIndex = 0,
    this.homeModuleOrder = defaultModuleOrder,
    this.enabledHomeModules = defaultEnabledModules,
    this.bookDetailCacheEnabled = true,
    this.bookTypeBadgeScopes = defaultBookTypeBadgeScopes,
    this.coverColorExtraction = false, // 默认关闭
    this.seedColorValue = 0xFFB71C1C, // 勃艮第红
    this.useSystemColor = false,
    this.dynamicSchemeVariant = 0, // 默认: TonalSpot
    this.useCustomTheme = false, // 默认使用预设 Tab
    // 阅读背景颜色默认值
    this.readerUseThemeBackground = true, // 默认使用主题色
    this.readerBackgroundColor = 0xFFFFFFFF, // 默认白色背景
    this.readerTextColor = 0xFF000000, // 默认黑色文字
    this.readerPresetIndex = 0, // 默认第一个预设（白纸）
    this.readerUseCustomColor = false, // 默认使用预设
    this.iosDisplayStyle = 'md3', // 默认使用 MD3 样式
    this.autoCheckUpdate = true, // 默认开启自动检查
    this.ignoredUpdateVersion = '',
  });

  /// 是否使用 iOS 26 液态玻璃样式
  bool get useIOS26Style => iosDisplayStyle == 'ios26' && Platform.isIOS;

  /// 是否使用 iOS 18 样式
  bool get useIOS18Style => iosDisplayStyle == 'ios18' && Platform.isIOS;

  bool get supportsTextBatteryIndicator => !Platform.isIOS;

  ReaderBatteryIndicatorStyle get effectiveReaderBatteryIndicatorStyle =>
      supportsTextBatteryIndicator
          ? readerBatteryIndicatorStyle
          : (readerBatteryIndicatorStyle == ReaderBatteryIndicatorStyle.text
              ? ReaderBatteryIndicatorStyle.capsule
              : readerBatteryIndicatorStyle);

  bool get hasCustomAppFont =>
      appFontFamily.isNotEmpty && appFontFileName.isNotEmpty;

  AppSettings copyWith({
    bool? isLoaded,
    double? fontSize,
    bool? readerFirstLineIndent,
    double? readerLineHeight,
    double? readerParagraphSpacing,
    double? readerSidePadding,
    ReaderViewMode? readerViewMode,
    bool? readerPagedNoAnimation,
    ReaderBatteryIndicatorStyle? readerBatteryIndicatorStyle,
    String? theme,
    String? appFontFamily,
    String? appFontFileName,
    String? appFontLabel,
    String? version,
    String? convertType,
    bool? fontCacheEnabled,
    int? fontCacheLimit,
    String? homeRankType,
    bool? oledBlack,
    bool? cleanChapterTitle,
    List<String>? cleanChapterTitleScopes,
    bool? ignoreJapanese,
    bool? ignoreAI,
    bool? ignoreLevel6,
    int? startupTabIndex,
    List<String>? homeModuleOrder,
    List<String>? enabledHomeModules,
    bool? bookDetailCacheEnabled,
    List<String>? bookTypeBadgeScopes,
    bool? coverColorExtraction,
    int? seedColorValue,
    bool? useSystemColor,
    int? dynamicSchemeVariant,
    bool? useCustomTheme,
    // 阅读背景颜色
    bool? readerUseThemeBackground,
    int? readerBackgroundColor,
    int? readerTextColor,
    int? readerPresetIndex,
    bool? readerUseCustomColor,
    String? iosDisplayStyle,
    bool? autoCheckUpdate,
    String? ignoredUpdateVersion,
  }) {
    return AppSettings(
      isLoaded: isLoaded ?? this.isLoaded,
      fontSize: fontSize ?? this.fontSize,
      readerFirstLineIndent:
          readerFirstLineIndent ?? this.readerFirstLineIndent,
      readerLineHeight: readerLineHeight ?? this.readerLineHeight,
      readerParagraphSpacing:
          readerParagraphSpacing ?? this.readerParagraphSpacing,
      readerSidePadding: readerSidePadding ?? this.readerSidePadding,
      readerViewMode: readerViewMode ?? this.readerViewMode,
      readerPagedNoAnimation:
          readerPagedNoAnimation ?? this.readerPagedNoAnimation,
      readerBatteryIndicatorStyle:
          readerBatteryIndicatorStyle ?? this.readerBatteryIndicatorStyle,
      theme: theme ?? this.theme,
      appFontFamily: appFontFamily ?? this.appFontFamily,
      appFontFileName: appFontFileName ?? this.appFontFileName,
      appFontLabel: appFontLabel ?? this.appFontLabel,
      version: version ?? this.version,
      convertType: convertType ?? this.convertType,
      fontCacheEnabled: fontCacheEnabled ?? this.fontCacheEnabled,
      fontCacheLimit: fontCacheLimit ?? this.fontCacheLimit,
      homeRankType: homeRankType ?? this.homeRankType,
      oledBlack: oledBlack ?? this.oledBlack,
      cleanChapterTitleScopes:
          cleanChapterTitle != null
              ? (cleanChapterTitle
                  ? AppSettings.defaultCleanChapterTitleScopes
                  : const <String>[])
              : (cleanChapterTitleScopes ?? this.cleanChapterTitleScopes),
      ignoreJapanese: ignoreJapanese ?? this.ignoreJapanese,
      ignoreAI: ignoreAI ?? this.ignoreAI,
      ignoreLevel6: ignoreLevel6 ?? this.ignoreLevel6,
      startupTabIndex: startupTabIndex ?? this.startupTabIndex,
      homeModuleOrder: homeModuleOrder ?? this.homeModuleOrder,
      enabledHomeModules: enabledHomeModules ?? this.enabledHomeModules,
      bookDetailCacheEnabled:
          bookDetailCacheEnabled ?? this.bookDetailCacheEnabled,
      bookTypeBadgeScopes: bookTypeBadgeScopes ?? this.bookTypeBadgeScopes,
      coverColorExtraction: coverColorExtraction ?? this.coverColorExtraction,
      seedColorValue: seedColorValue ?? this.seedColorValue,
      useSystemColor: useSystemColor ?? this.useSystemColor,
      dynamicSchemeVariant:
          dynamicSchemeVariant ?? (this.dynamicSchemeVariant as int?) ?? 0,
      useCustomTheme: useCustomTheme ?? (this.useCustomTheme as bool?) ?? false,
      // 阅读背景颜色
      readerUseThemeBackground:
          readerUseThemeBackground ?? this.readerUseThemeBackground,
      readerBackgroundColor:
          readerBackgroundColor ?? this.readerBackgroundColor,
      readerTextColor: readerTextColor ?? this.readerTextColor,
      readerPresetIndex: readerPresetIndex ?? this.readerPresetIndex,
      readerUseCustomColor: readerUseCustomColor ?? this.readerUseCustomColor,
      iosDisplayStyle: iosDisplayStyle ?? this.iosDisplayStyle,
      autoCheckUpdate: autoCheckUpdate ?? this.autoCheckUpdate,
      ignoredUpdateVersion: ignoredUpdateVersion ?? this.ignoredUpdateVersion,
    );
  }

  /// 检查模块是否启用
  bool isModuleEnabled(String moduleId) =>
      enabledHomeModules.contains(moduleId);

  /// 检查指定范围是否启用书籍类型角标
  bool isBookTypeBadgeEnabled(String scope) =>
      bookTypeBadgeScopes.contains(scope);

  bool get cleanChapterTitle => cleanChapterTitleScopes.isNotEmpty;

  bool isCleanChapterTitleEnabled(String scope) =>
      cleanChapterTitleScopes.contains(scope);
}

/// 基于 Riverpod 3.x Notifier API 的设置通知器
class SettingsNotifier extends Notifier<AppSettings> {
  int _normalizeStartupTabIndex(int? index) {
    final safeIndex = index ?? 0;
    if (safeIndex < 0 || safeIndex > 3) {
      return 0;
    }
    return safeIndex;
  }

  @override
  AppSettings build() {
    _loadSettings();
    return AppSettings(
      useSystemColor: Platform.isAndroid || Platform.isWindows,
      readerBatteryIndicatorStyle:
          Platform.isIOS
              ? ReaderBatteryIndicatorStyle.capsule
              : ReaderBatteryIndicatorStyle.text,
    );
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final packageInfo = await PackageInfo.fromPlatform();

    developer.log(
      'Loaded settings: ignoreJapanese=${prefs.getBool('setting_ignoreJapanese')}, ignoreAI=${prefs.getBool('setting_ignoreAI')}',
      name: 'Settings',
    );
    state = AppSettings(
      isLoaded: true,
      fontSize: prefs.getDouble('setting_fontSize') ?? 18.0,
      readerFirstLineIndent:
          prefs.getBool('setting_readerFirstLineIndent') ?? false,
      readerLineHeight: prefs.getDouble('setting_readerLineHeight') ?? 1.6,
      readerParagraphSpacing:
          prefs.getDouble('setting_readerParagraphSpacing') ?? 0.0,
      readerSidePadding: prefs.getDouble('setting_readerSidePadding') ?? 30.0,
      readerViewMode: _parseReaderViewMode(
        prefs.getString('setting_readerViewMode'),
      ),
      readerPagedNoAnimation:
          prefs.getBool('setting_readerPagedNoAnimation') ?? false,
      readerBatteryIndicatorStyle: _parseReaderBatteryIndicatorStyle(
        prefs.getString('setting_readerBatteryIndicatorStyle'),
      ),
      theme: prefs.getString('setting_theme') ?? 'system',
      appFontFamily: prefs.getString('setting_appFontFamily') ?? '',
      appFontFileName: prefs.getString('setting_appFontFileName') ?? '',
      appFontLabel: prefs.getString('setting_appFontLabel') ?? '',
      version: packageInfo.version,
      convertType: prefs.getString('setting_convertType') ?? 'none',
      fontCacheEnabled: prefs.getBool('setting_fontCacheEnabled') ?? true,
      fontCacheLimit: prefs.getInt('setting_fontCacheLimit') ?? 30,
      homeRankType: prefs.getString('setting_homeRankType') ?? 'weekly',
      oledBlack: prefs.getBool('setting_oledBlack') ?? false,
      cleanChapterTitleScopes: _loadCleanChapterTitleScopes(prefs),
      ignoreJapanese: prefs.getBool('setting_ignoreJapanese') ?? false,
      ignoreAI: prefs.getBool('setting_ignoreAI') ?? false,
      ignoreLevel6: prefs.getBool('setting_ignoreLevel6') ?? true, // 默认开启
      startupTabIndex: _normalizeStartupTabIndex(
        prefs.getInt('setting_startupTabIndex'),
      ),
      homeModuleOrder: List<String>.from(
        prefs.getStringList('setting_homeModuleOrder') ??
            AppSettings.defaultModuleOrder,
      ),
      enabledHomeModules: List<String>.from(
        prefs.getStringList('setting_enabledHomeModules') ??
            AppSettings.defaultEnabledModules,
      ),
      bookDetailCacheEnabled:
          prefs.getBool('setting_bookDetailCacheEnabled') ?? true,
      bookTypeBadgeScopes: List<String>.from(
        prefs.getStringList('setting_bookTypeBadgeScopes') ??
            AppSettings.defaultBookTypeBadgeScopes,
      ),
      coverColorExtraction:
          prefs.getBool('setting_coverColorExtraction') ?? false,
      seedColorValue: prefs.getInt('setting_seedColorValue') ?? 0xFFB71C1C,
      // 在 Android 和 Windows 上默认启用系统颜色
      useSystemColor:
          prefs.getBool('setting_useSystemColor') ??
          (Platform.isAndroid || Platform.isWindows),
      dynamicSchemeVariant: prefs.getInt('setting_dynamicSchemeVariant') ?? 0,
      useCustomTheme: prefs.getBool('setting_useCustomTheme') ?? false,
      // 阅读背景颜色
      readerUseThemeBackground:
          prefs.getBool('setting_readerUseThemeBackground') ?? true,
      readerBackgroundColor:
          prefs.getInt('setting_readerBackgroundColor') ?? 0xFFFFFFFF,
      readerTextColor: prefs.getInt('setting_readerTextColor') ?? 0xFF000000,
      readerPresetIndex: prefs.getInt('setting_readerPresetIndex') ?? 0,
      readerUseCustomColor:
          prefs.getBool('setting_readerUseCustomColor') ?? false,
      iosDisplayStyle: prefs.getString('setting_iosDisplayStyle') ?? 'md3',
      autoCheckUpdate: prefs.getBool('setting_autoCheckUpdate') ?? true,
      ignoredUpdateVersion:
          prefs.getString('setting_ignoredUpdateVersion') ?? '',
    );

    // 同步 iOS 显示样式到 PlatformInfo
    if (Platform.isIOS) {
      PlatformInfo.styleOverride = state.iosDisplayStyle;
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('setting_fontSize', state.fontSize);
    await prefs.setBool(
      'setting_readerFirstLineIndent',
      state.readerFirstLineIndent,
    );
    await prefs.setDouble('setting_readerLineHeight', state.readerLineHeight);
    await prefs.setDouble(
      'setting_readerParagraphSpacing',
      state.readerParagraphSpacing,
    );
    await prefs.setDouble('setting_readerSidePadding', state.readerSidePadding);
    await prefs.setString('setting_readerViewMode', state.readerViewMode.name);
    await prefs.setBool(
      'setting_readerPagedNoAnimation',
      state.readerPagedNoAnimation,
    );
    await prefs.setString(
      'setting_readerBatteryIndicatorStyle',
      state.readerBatteryIndicatorStyle.name,
    );
    await prefs.setString('setting_theme', state.theme);
    await prefs.setString('setting_appFontFamily', state.appFontFamily);
    await prefs.setString('setting_appFontFileName', state.appFontFileName);
    await prefs.setString('setting_appFontLabel', state.appFontLabel);
    await prefs.setString('setting_convertType', state.convertType);
    await prefs.setBool('setting_fontCacheEnabled', state.fontCacheEnabled);
    await prefs.setInt('setting_fontCacheLimit', state.fontCacheLimit);
    await prefs.setString('setting_homeRankType', state.homeRankType);
    await prefs.setBool('setting_oledBlack', state.oledBlack);
    await prefs.setBool('setting_cleanChapterTitle', state.cleanChapterTitle);
    await prefs.setStringList(
      'setting_cleanChapterTitleScopes',
      state.cleanChapterTitleScopes,
    );
    await prefs.setBool('setting_ignoreJapanese', state.ignoreJapanese);
    await prefs.setBool('setting_ignoreAI', state.ignoreAI);
    await prefs.setBool('setting_ignoreLevel6', state.ignoreLevel6);
    await prefs.setInt('setting_startupTabIndex', state.startupTabIndex);
    await prefs.setStringList('setting_homeModuleOrder', state.homeModuleOrder);
    await prefs.setStringList(
      'setting_enabledHomeModules',
      state.enabledHomeModules,
    );
    await prefs.setBool(
      'setting_bookDetailCacheEnabled',
      state.bookDetailCacheEnabled,
    );
    await prefs.setStringList(
      'setting_bookTypeBadgeScopes',
      state.bookTypeBadgeScopes,
    );
    await prefs.setBool(
      'setting_coverColorExtraction',
      state.coverColorExtraction,
    );
    await prefs.setInt('setting_seedColorValue', state.seedColorValue);
    await prefs.setBool('setting_useSystemColor', state.useSystemColor);
    await prefs.setInt(
      'setting_dynamicSchemeVariant',
      state.dynamicSchemeVariant,
    );
    await prefs.setBool('setting_useCustomTheme', state.useCustomTheme);
    // 阅读背景颜色
    await prefs.setBool(
      'setting_readerUseThemeBackground',
      state.readerUseThemeBackground,
    );
    await prefs.setInt(
      'setting_readerBackgroundColor',
      state.readerBackgroundColor,
    );
    await prefs.setInt('setting_readerTextColor', state.readerTextColor);
    await prefs.setInt('setting_readerPresetIndex', state.readerPresetIndex);
    await prefs.setBool(
      'setting_readerUseCustomColor',
      state.readerUseCustomColor,
    );
    await prefs.setString('setting_iosDisplayStyle', state.iosDisplayStyle);
    await prefs.setBool('setting_autoCheckUpdate', state.autoCheckUpdate);
    await prefs.setString(
      'setting_ignoredUpdateVersion',
      state.ignoredUpdateVersion,
    );
  }

  void setFontSize(double size) {
    state = state.copyWith(fontSize: size);
    _save();
  }

  void setReaderFirstLineIndent(bool value) {
    state = state.copyWith(readerFirstLineIndent: value);
    _save();
  }

  void setReaderLineHeight(double value) {
    state = state.copyWith(readerLineHeight: value.clamp(1.2, 2.4).toDouble());
    _save();
  }

  void setReaderParagraphSpacing(double value) {
    state = state.copyWith(
      readerParagraphSpacing: value.clamp(0.0, 32.0).toDouble(),
    );
    _save();
  }

  void setReaderSidePadding(double value) {
    state = state.copyWith(
      readerSidePadding: value.clamp(0.0, 48.0).toDouble(),
    );
    _save();
  }

  void setReaderViewMode(ReaderViewMode value) {
    state = state.copyWith(readerViewMode: value);
    _save();
  }

  void setReaderPagedNoAnimation(bool value) {
    state = state.copyWith(readerPagedNoAnimation: value);
    _save();
  }

  void setReaderBatteryIndicatorStyle(ReaderBatteryIndicatorStyle value) {
    state = state.copyWith(
      readerBatteryIndicatorStyle:
          Platform.isIOS && value == ReaderBatteryIndicatorStyle.text
              ? ReaderBatteryIndicatorStyle.capsule
              : value,
    );
    _save();
  }

  void setTheme(String theme) {
    state = state.copyWith(theme: theme);
    _save();
    // 清除书籍详情页缓存以强制重新提取新主题的颜色
    BookDetailPageState.clearColorCache();
    BookInfoCacheService().clear();
  }

  Future<void> setAppUiFont({
    required String fontFamily,
    required String fileName,
    required String label,
  }) async {
    state = state.copyWith(
      appFontFamily: fontFamily,
      appFontFileName: fileName,
      appFontLabel: label,
    );
    await _save();
    await AppUiFontManager().pruneFonts(keepFileNames: <String>{fileName});
  }

  Future<void> clearAppUiFont() async {
    final previousFileName = state.appFontFileName;
    state = state.copyWith(
      appFontFamily: '',
      appFontFileName: '',
      appFontLabel: '',
    );
    await _save();
    await AppUiFontManager().deleteFont(previousFileName);
    await AppUiFontManager().pruneFonts();
  }

  void setConvertType(String type) {
    state = state.copyWith(convertType: type);
    _save();
  }

  void setFontCacheEnabled(bool enabled) {
    state = state.copyWith(fontCacheEnabled: enabled);
    _save();
  }

  void setFontCacheLimit(int limit) {
    state = state.copyWith(fontCacheLimit: limit.clamp(10, 60));
    _save();
  }

  void setHomeRankType(String type) {
    state = state.copyWith(homeRankType: type);
    _save();
  }

  void setOledBlack(bool value) {
    // 只有在禁用封面取色时才允许开启纯黑模式
    // UI 层也应做限制，这里做二次防护
    if (state.coverColorExtraction && value) {
      return;
    }
    state = state.copyWith(oledBlack: value);
    _save();
  }

  void setCoverColorExtraction(bool value) {
    // 开启封面取色时，强制关闭纯黑模式
    if (value) {
      state = state.copyWith(coverColorExtraction: value, oledBlack: false);
    } else {
      state = state.copyWith(coverColorExtraction: value);
    }
    _save();
    // 清除缓存以重新提取（或不再提取）
    BookDetailPageState.clearColorCache();
    BookInfoCacheService().clear();
  }

  void setCleanChapterTitle(bool value) {
    state = state.copyWith(cleanChapterTitle: value);
    _save();
  }

  void setCleanChapterTitleScopes(List<String> scopes) {
    state = state.copyWith(cleanChapterTitleScopes: List<String>.from(scopes));
    _save();
  }

  void setIgnoreJapanese(bool value) {
    state = state.copyWith(ignoreJapanese: value);
    _save();
  }

  void setIgnoreAI(bool value) {
    state = state.copyWith(ignoreAI: value);
    _save();
  }

  void setIgnoreLevel6(bool value) {
    state = state.copyWith(ignoreLevel6: value);
    _save();
  }

  void setStartupTabIndex(int index) {
    state = state.copyWith(startupTabIndex: _normalizeStartupTabIndex(index));
    _save();
  }

  void setHomeModuleOrder(List<String> order) {
    state = state.copyWith(homeModuleOrder: order);
    _save();
  }

  void setEnabledHomeModules(List<String> modules) {
    state = state.copyWith(enabledHomeModules: modules);
    _save();
  }

  void setBookDetailCacheEnabled(bool value) {
    state = state.copyWith(bookDetailCacheEnabled: value);
    _save();
  }

  /// 同时更新排序和启用模块
  void setHomeModuleConfig({
    required List<String> order,
    required List<String> enabled,
  }) {
    state = state.copyWith(homeModuleOrder: order, enabledHomeModules: enabled);
    _save();
  }

  void setBookTypeBadgeScopes(List<String> scopes) {
    state = state.copyWith(bookTypeBadgeScopes: scopes);
    _save();
  }

  void setSeedColor(int colorValue) {
    state = state.copyWith(seedColorValue: colorValue);
    _save();
    // 清除缓存以应用新主题色
    BookDetailPageState.clearColorCache();
    BookInfoCacheService().clear();
  }

  void setUseSystemColor(bool value) {
    state = state.copyWith(useSystemColor: value);
    _save();
    // 清除缓存以应用新主题色
    BookDetailPageState.clearColorCache();
    BookInfoCacheService().clear();
  }

  void setDynamicSchemeVariant(int variantIndex) {
    state = state.copyWith(dynamicSchemeVariant: variantIndex);
    _save();
    // 清除缓存以应用新变体
    BookDetailPageState.clearColorCache();
    BookInfoCacheService().clear();
  }

  void setUseCustomTheme(bool useCustom) {
    state = state.copyWith(useCustomTheme: useCustom);
    _save();
  }

  /// 一次性应用所有主题相关设定，避免多次触发 state 更新和硬盘 IO，导致主存重构卡顿
  void setThemeConfig({
    required String theme,
    required int seedColor,
    required bool useSystemColor,
    required int dynamicSchemeVariant,
    required bool useCustomTheme,
  }) {
    state = state.copyWith(
      theme: theme,
      seedColorValue: seedColor,
      useSystemColor: useSystemColor,
      dynamicSchemeVariant: dynamicSchemeVariant,
      useCustomTheme: useCustomTheme,
    );
    _save();
    BookDetailPageState.clearColorCache();
    BookInfoCacheService().clear();
  }

  // ==================== 阅读背景颜色设置 ====================

  void setReaderUseThemeBackground(bool value) {
    state = state.copyWith(readerUseThemeBackground: value);
    _save();
  }

  void setReaderBackgroundColor(int colorValue) {
    state = state.copyWith(readerBackgroundColor: colorValue);
    _save();
  }

  void setReaderTextColor(int colorValue) {
    state = state.copyWith(readerTextColor: colorValue);
    _save();
  }

  void setReaderPresetIndex(int index) {
    state = state.copyWith(readerPresetIndex: index);
    _save();
  }

  void setReaderUseCustomColor(bool value) {
    state = state.copyWith(readerUseCustomColor: value);
    _save();
  }

  /// 一次性设置所有阅读背景相关参数
  void setReaderBackgroundConfig({
    required bool useThemeBackground,
    required int backgroundColor,
    required int textColor,
    required int presetIndex,
    required bool useCustomColor,
  }) {
    state = state.copyWith(
      readerUseThemeBackground: useThemeBackground,
      readerBackgroundColor: backgroundColor,
      readerTextColor: textColor,
      readerPresetIndex: presetIndex,
      readerUseCustomColor: useCustomColor,
    );
    _save();
  }

  // ==================== iOS 显示样式设置 ====================

  void setIosDisplayStyle(String value) {
    state = state.copyWith(iosDisplayStyle: value);
    _save();
    // 同步到 PlatformInfo
    if (Platform.isIOS) {
      PlatformInfo.styleOverride = value;
    }
  }

  void setAutoCheckUpdate(bool value) {
    state = state.copyWith(autoCheckUpdate: value);
    _save();
  }

  void setIgnoredUpdateVersion(String version) {
    state = state.copyWith(ignoredUpdateVersion: version);
    _save();
  }
}

ReaderViewMode _parseReaderViewMode(String? raw) {
  if (raw == null || raw.isEmpty) {
    return ReaderViewMode.paged;
  }

  for (final mode in ReaderViewMode.values) {
    if (mode.name == raw) {
      return mode;
    }
  }

  return ReaderViewMode.paged;
}

ReaderBatteryIndicatorStyle _parseReaderBatteryIndicatorStyle(String? raw) {
  if (raw != null) {
    for (final style in ReaderBatteryIndicatorStyle.values) {
      if (style.name == raw) {
        if (Platform.isIOS && style == ReaderBatteryIndicatorStyle.text) {
          return ReaderBatteryIndicatorStyle.capsule;
        }
        return style;
      }
    }
  }

  return Platform.isIOS
      ? ReaderBatteryIndicatorStyle.capsule
      : ReaderBatteryIndicatorStyle.text;
}

/// 设置提供者
List<String> _loadCleanChapterTitleScopes(SharedPreferences prefs) {
  if (prefs.containsKey('setting_cleanChapterTitleScopes')) {
    return List<String>.from(
      prefs.getStringList('setting_cleanChapterTitleScopes') ?? const [],
    );
  }

  if (prefs.containsKey('setting_cleanChapterTitle')) {
    final enabled = prefs.getBool('setting_cleanChapterTitle') ?? true;
    return enabled
        ? AppSettings.defaultCleanChapterTitleScopes
        : const <String>[];
  }

  return AppSettings.defaultCleanChapterTitleScopes;
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

final appUiFontFamilyProvider = FutureProvider<String?>((ref) async {
  final (isLoaded, fontFamily, fileName) = ref.watch(
    settingsProvider.select(
      (settings) => (
        settings.isLoaded,
        settings.appFontFamily,
        settings.appFontFileName,
      ),
    ),
  );

  if (!isLoaded || fontFamily.isEmpty || fileName.isEmpty) {
    return null;
  }

  return AppUiFontManager().loadFont(
    fontFamily: fontFamily,
    fileName: fileName,
  );
});
