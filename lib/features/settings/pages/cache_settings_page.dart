import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novella/core/widgets/m3e_loading_indicator.dart';
import 'package:novella/core/utils/font_manager.dart';
import 'package:novella/data/services/local_cover_service.dart';
import 'package:novella/features/settings/settings_provider.dart';

import 'package:novella/features/settings/widgets/settings_header_card.dart';

class CacheSettingsPage extends ConsumerWidget {
  const CacheSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(),
          const SliverToBoxAdapter(
            child: SettingsHeaderCard(
              icon: Icons.storage,
              title: '缓存设置',
              subtitle: '管理应用缓存与数据，并控制应用加载策略',
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              // 书籍详情页缓存
              SwitchListTile(
                secondary: const Icon(Icons.menu_book),
                title: const Text('详情页缓存'),
                subtitle: const Text('暂时缓存访问过的书籍详情'),
                value: settings.bookDetailCacheEnabled,
                onChanged: (value) => notifier.setBookDetailCacheEnabled(value),
              ),

              // 字体缓存开关
              SwitchListTile(
                secondary: const Icon(Icons.cached),
                title: const Text('字体缓存'),
                subtitle: Text(settings.fontCacheEnabled ? '启用' : '禁用'),
                value: settings.fontCacheEnabled,
                onChanged: (value) => notifier.setFontCacheEnabled(value),
              ),

              // 字体缓存限制滑块（仅在启用缓存时显示）
              if (settings.fontCacheEnabled)
                ListTile(
                  leading: const Icon(Icons.storage),
                  title: const Text('缓存容量'),
                  subtitle: Text('保留 ${settings.fontCacheLimit} 本'),
                  trailing: SizedBox(
                    width: 180,
                    child: Slider(
                      value: settings.fontCacheLimit.toDouble(),
                      min: 10,
                      max: 60,
                      divisions: 10,
                      label: '${settings.fontCacheLimit}',
                      onChanged:
                          (value) => notifier.setFontCacheLimit(value.toInt()),
                    ),
                  ),
                ),

              // 清除所有缓存按钮
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  '清除所有缓存',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () => _showClearCacheDialog(context),
              ),
              const SizedBox(height: 32),
            ]),
          ),
        ],
      ),
    );
  }

  /// 清除图片缓存：本地封面文件 + cached_network_image 磁盘缓存 + 内存 imageCache
  /// （后者含 BlurHash 占位图缓存）。返回删除的本地封面数。
  Future<int> _clearImageCaches() async {
    final count = await LocalCoverService().clearAll();
    await DefaultCacheManager().emptyCache();
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    return count;
  }

  void _showClearCacheDialog(BuildContext context) {
    showModalBottomSheet(
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
              // 标题
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Text(
                  '清除缓存',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // 副标题
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  '将删除缓存的字体与封面图片，需要时重新加载',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 底部按钮
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          Navigator.pop(sheetContext);

                          // 显示加载指示器
                          final scaffold = ScaffoldMessenger.of(context);
                          scaffold.showSnackBar(
                            const SnackBar(
                              content: Row(
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: M3ELoadingIndicator(
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Text('清除中'),
                                ],
                              ),
                              duration: Duration(seconds: 1),
                            ),
                          );

                          // 清除缓存（字体 + 图片）
                          final deletedCount =
                              await FontManager().clearAllCaches() +
                              await _clearImageCaches();

                          // 显示结果
                          scaffold.hideCurrentSnackBar();
                          scaffold.showSnackBar(
                            SnackBar(
                              content: Text('已清除 $deletedCount 项'),
                              behavior: SnackBarBehavior.floating,
                              action: SnackBarAction(
                                label: '确定',
                                onPressed: () => scaffold.hideCurrentSnackBar(),
                              ),
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.error,
                        ),
                        child: const Text('清除'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
