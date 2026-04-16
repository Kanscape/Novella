import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novella/core/navigation/app_route_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novella/core/config/app_build_info.dart';
import 'package:novella/main.dart' show rustLibInitialized, rustLibInitError;
import 'package:novella/features/settings/settings_provider.dart';
import 'package:novella/features/settings/source_code_page.dart';
import 'package:novella/features/settings/log_viewer_page.dart';
import 'package:novella/features/auth/login_page.dart';
import 'package:novella/core/sync/sync_manager.dart';
import 'package:novella/core/services/update_service.dart';

import 'package:novella/features/settings/widgets/settings_header_card.dart';

class AboutSettingsPage extends ConsumerWidget {
  const AboutSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final displayVersion = AppBuildInfo.getDisplayVersion(settings.version);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(),
          const SliverToBoxAdapter(
            child: SettingsHeaderCard(
              icon: Icons.info_outline,
              title: '关于应用',
              subtitle: '查看版本、调试信息，以及深入项目\n喜欢就点个 star 吧~',
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('版本'),
                subtitle: Text(displayVersion),
                onTap:
                    () => UpdateService.checkUpdate(context, ref, manual: true),
                onLongPress:
                    displayVersion.isEmpty
                        ? null
                        : () async {
                          await Clipboard.setData(
                            ClipboardData(text: displayVersion),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('已复制版本号'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          }
                        },
              ),

              SwitchListTile(
                secondary: const Icon(Icons.update),
                title: const Text('检测更新'),
                subtitle: const Text('启动时检查 GitHub 最新版本'),
                value: settings.autoCheckUpdate,
                onChanged: (value) {
                  ref.read(settingsProvider.notifier).setAutoCheckUpdate(value);
                },
              ),

              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('源代码'),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () {
                  AppRouteLauncher.pushDetail(
                    context,
                    (context) => const SourceCodePage(),
                  );
                },
              ),

              // 调试日志
              ListTile(
                leading: const Icon(Icons.bug_report),
                title: const Text('调试日志'),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () {
                  AppRouteLauncher.pushDetail(
                    context,
                    (context) => const LogViewerPage(),
                  );
                },
              ),

              // 调试：RustLib FFI 状态
              ListTile(
                leading: Icon(
                  rustLibInitialized ? Icons.check_circle : Icons.error,
                  color: rustLibInitialized ? Colors.green : colorScheme.error,
                ),
                title: const Text('Rust FFI 状态'),
                subtitle: Text(
                  rustLibInitialized
                      ? '已初始化 (${Platform.isIOS
                          ? "iOS"
                          : Platform.isMacOS
                          ? "macOS"
                          : Platform.isAndroid
                          ? "Android"
                          : "Windows"})'
                      : '初始化失败: ${rustLibInitError ?? "未知错误"}',
                  style: TextStyle(
                    color: rustLibInitialized ? null : colorScheme.error,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // 退出登录按钮
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: OutlinedButton.icon(
                  onPressed: () => _showLogoutDialog(context),
                  icon: const Icon(Icons.logout),
                  label: const Text('退出登录'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    side: BorderSide(color: colorScheme.error),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ]),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final syncManager = SyncManager();
    final isGistConnected = syncManager.isConnected;

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
                  '退出登录',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // 副标题
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  isGistConnected ? '请先断开 GitHub 连接后再退出登录' : '确认退出当前账号？',
                  style: textTheme.bodySmall?.copyWith(
                    color:
                        isGistConnected
                            ? colorScheme.error
                            : colorScheme.onSurfaceVariant,
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
                        onPressed:
                            isGistConnected
                                ? null
                                : () async {
                                  // 先关闭底部弹窗
                                  Navigator.pop(sheetContext);

                                  // 清除 token
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  await prefs.remove('auth_token');
                                  await prefs.remove('refresh_token');

                                  // 跳转到登录页
                                  if (context.mounted) {
                                    Navigator.of(
                                      context,
                                      rootNavigator: true,
                                    ).pushAndRemoveUntil(
                                      MaterialPageRoute(
                                        builder: (_) => const LoginPage(),
                                      ),
                                      (route) => false,
                                    );
                                  }
                                },
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.error,
                          disabledBackgroundColor: colorScheme.error.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        child: const Text('退出'),
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
