import 'package:flutter/material.dart';
import 'package:novella/features/settings/sync_settings_section.dart';

import 'package:novella/features/settings/widgets/settings_header_card.dart';

class SyncSettingsPage extends StatelessWidget {
  const SyncSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(),
          const SliverToBoxAdapter(
            child: SettingsHeaderCard(
              icon: Icons.sync,
              title: '同步设置',
              subtitle:
                  '管理增强功能的云端同步\n为书籍标记、阅读时间\n提供进阶同步能力\n轻书架会保存进度和默认书架的数据\n即使禁用本页面的功能，也拥有基础同步能力',
            ),
          ),
          SliverToBoxAdapter(child: SyncSettingsSection()),
        ],
      ),
    );
  }
}
