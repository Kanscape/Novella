import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:novella/core/layout/app_window_class.dart';
import 'package:novella/core/navigation/app_route_launcher.dart';
import 'package:novella/features/settings/settings_provider.dart';
import 'package:novella/features/settings/pages/reading_settings_page.dart';
import 'package:novella/features/settings/pages/content_settings_page.dart';
import 'package:novella/features/settings/pages/appearance_settings_page.dart';
import 'package:novella/features/settings/pages/cache_settings_page.dart';
import 'package:novella/features/settings/pages/sync_settings_page.dart';
import 'package:novella/features/settings/widgets/settings_header_card.dart';
import 'package:novella/features/settings/widgets/settings_profile_entry.dart';
import 'package:novella/features/settings/pages/about_settings_page.dart';

export 'package:novella/features/settings/settings_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                    child: SizedBox(
                      height:
                          48.0 + Theme.of(context).visualDensity.vertical * 4.0,
                      child: Stack(
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '设置',
                              style: Theme.of(
                                context,
                              ).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          const Align(
                            alignment: Alignment.centerRight,
                            child: SettingsProfileEntry(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SettingsHeaderCard(
                    icon: Icons.tune,
                    title: '通用项目',
                    subtitle: '应用偏好设置与管理',
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: appBottomContentPadding(
                context,
                useIOS26Style: settings.useIOS26Style,
              ),
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 阅读设置
                ListTile(
                  leading: const Icon(Icons.menu_book),
                  title: const Text('阅读'),
                  subtitle: const Text('简单的阅读页设置'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    AppRouteLauncher.pushDetail(
                      context,
                      (context) => const ReadingSettingsPage(),
                    );
                  },
                ),

                // 内容设置
                ListTile(
                  leading: const Icon(Icons.dashboard_customize),
                  title: const Text('内容'),
                  subtitle: const Text('所见即所得'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    AppRouteLauncher.pushDetail(
                      context,
                      (context) => const ContentSettingsPage(),
                    );
                  },
                ),

                // 外观设置
                ListTile(
                  leading: const Icon(Icons.palette),
                  title: const Text('外观'),
                  subtitle: const Text('搭配颜色，选择界面样式'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    AppRouteLauncher.pushDetail(
                      context,
                      (context) => const AppearanceSettingsPage(),
                    );
                  },
                ),

                // 缓存设置
                ListTile(
                  leading: const Icon(Icons.storage),
                  title: const Text('缓存'),
                  subtitle: const Text('加载策略与存储空间'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    AppRouteLauncher.pushDetail(
                      context,
                      (context) => const CacheSettingsPage(),
                    );
                  },
                ),

                // 同步设置
                ListTile(
                  leading: const Icon(Icons.sync),
                  title: const Text('同步'),
                  subtitle: const Text('数据备份与跨设备'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    AppRouteLauncher.pushDetail(
                      context,
                      (context) => const SyncSettingsPage(),
                    );
                  },
                ),

                // 关于
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('关于'),
                  subtitle: const Text('查看更多信息'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    AppRouteLauncher.pushDetail(
                      context,
                      (context) => const AboutSettingsPage(),
                    );
                  },
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
