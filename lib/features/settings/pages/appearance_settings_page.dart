import 'dart:io';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novella/core/navigation/app_route_launcher.dart';
import 'package:novella/core/utils/app_ui_font_manager.dart';
import 'package:novella/features/settings/settings_provider.dart';
import 'package:novella/features/settings/theme_selection_page.dart';
import 'package:novella/features/settings/widgets/settings_header_card.dart';
import 'package:novella/features/settings/widgets/settings_ui_helper.dart';

class AppearanceSettingsPage extends ConsumerWidget {
  const AppearanceSettingsPage({super.key});

  String _appFontLabel(AppSettings settings, AsyncValue<String?> fontAsync) {
    if (!settings.hasCustomAppFont) {
      return '跟随系统';
    }
    if (fontAsync.isLoading) {
      return '加载中';
    }
    if (fontAsync.hasError) {
      return '加载失败';
    }
    return settings.appFontLabel.isEmpty ? '自定义字体' : settings.appFontLabel;
  }

  String _appFontSubtitle(AppSettings settings, AsyncValue<String?> fontAsync) {
    if (fontAsync.hasError) {
      return '字体加载失败，可重新导入或恢复默认';
    }
    if (settings.hasCustomAppFont) {
      return '已导入自定字体';
    }
    return '当前为系统字体';
  }

  Future<void> _pickAndImportAppFont(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      allowedExtensions: const <String>['ttf', 'otf'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final pickedFile = result.files.single;

    try {
      final importedFont = await AppUiFontManager().importFont(
        originalFileName: pickedFile.name,
        sourcePath: pickedFile.path,
        bytes: pickedFile.bytes,
      );

      await ref
          .read(settingsProvider.notifier)
          .setAppUiFont(
            fontFamily: importedFont.fontFamily,
            fileName: importedFont.fileName,
            label: importedFont.displayName,
          );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已应用 ${importedFont.displayName}')),
      );
    } on UnsupportedError {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('仅支持导入 TTF / OTF 字体文件')));
    } on Object {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('字体导入失败')));
    }
  }

  Future<void> _resetAppUiFont(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(settingsProvider);
    if (!settings.hasCustomAppFont) {
      return;
    }

    await ref.read(settingsProvider.notifier).clearAppUiFont();

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已恢复默认字体')));
  }

  Future<void> _showAppFontSheet(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(settingsProvider);

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        final textTheme = Theme.of(sheetContext).textTheme;

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Text(
                  '应用字体',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  '仅对除阅读正文以外的界面生效',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.text_format_rounded,
                  color: colorScheme.primary,
                ),
                title: Text(
                  settings.hasCustomAppFont ? settings.appFontLabel : '系统字体',
                ),
                subtitle: const Text('使用中的字体'),
                trailing: Icon(Icons.check, color: colorScheme.primary),
              ),
              ListTile(
                leading: const Icon(Icons.upload_file_rounded),
                title: const Text('导入字体文件'),
                subtitle: const Text('支持 TTF / OTF，请选择包含中文字符的字体'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _pickAndImportAppFont(context, ref);
                },
              ),
              if (settings.hasCustomAppFont)
                ListTile(
                  leading: const Icon(Icons.restart_alt_rounded),
                  title: const Text('恢复默认字体'),
                  subtitle: const Text('移除当前应用字体设置'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _resetAppUiFont(context, ref);
                  },
                ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;
    final appFontAsync = ref.watch(appUiFontFamilyProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(),
          const SliverToBoxAdapter(
            child: SettingsHeaderCard(
              icon: Icons.palette,
              title: '外观设置',
              subtitle: '管理主题颜色、深浅模式与界面样式',
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('主题与配色'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, size: 20),
                  ],
                ),
                onTap: () {
                  AppRouteLauncher.pushDetail(
                    context,
                    (context) => const ThemeSelectionPage(),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.text_format_rounded),
                title: const Text('应用字体'),
                subtitle: Text(_appFontSubtitle(settings, appFontAsync)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Text(
                        _appFontLabel(settings, appFontAsync),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, size: 20),
                  ],
                ),
                onTap: () => _showAppFontSheet(context, ref),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.colorize),
                title: const Text('封面取色'),
                subtitle: const Text('从封面提取颜色作为详情页主题'),
                value: settings.coverColorExtraction,
                onChanged: (value) => notifier.setCoverColorExtraction(value),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.contrast),
                title: const Text('纯黑模式'),
                subtitle: const Text('在深色模式下使用更纯的黑色背景'),
                value: settings.oledBlack,
                onChanged:
                    colorScheme.brightness == Brightness.dark
                        ? (value) => notifier.setOledBlack(value)
                        : null,
              ),
              if (Platform.isIOS && PlatformInfo.isNativeIOS26OrHigher())
                ListTile(
                  leading: const Icon(Icons.phone_iphone),
                  title: const Text('iOS 显示样式'),
                  subtitle: const Text('实验性功能'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        const {
                              'md3': 'Material',
                              'ios26': 'Liquid Glass',
                            }[settings.iosDisplayStyle] ??
                            'Material',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, size: 20),
                    ],
                  ),
                  onTap: () {
                    final options = {
                      'md3': 'Material Design 3',
                      'ios26': 'Liquid Glass',
                    };
                    final icons = {'md3': Icons.android, 'ios26': Icons.apple};

                    SettingsUIHelper.showSelectionSheet<String>(
                      context: context,
                      title: 'iOS 显示样式',
                      subtitle: '选择界面控件风格（实验性功能）',
                      currentValue: settings.iosDisplayStyle,
                      options: options,
                      icons: icons,
                      onSelected: (value) => notifier.setIosDisplayStyle(value),
                    );
                  },
                ),
              const SizedBox(height: 32),
            ]),
          ),
        ],
      ),
    );
  }
}
