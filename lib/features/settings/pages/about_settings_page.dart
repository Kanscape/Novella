import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novella/core/auth/auth_service.dart';
import 'package:novella/core/navigation/app_route_launcher.dart';
import 'package:novella/core/config/app_build_info.dart';
import 'package:novella/core/telemetry/telemetry_events.dart';
import 'package:novella/core/telemetry/telemetry_service.dart';
import 'package:novella/main.dart' show rustLibInitialized, rustLibInitError;
import 'package:novella/features/settings/settings_provider.dart';
import 'package:novella/features/settings/source_code_page.dart';
import 'package:novella/features/settings/log_viewer_page.dart';
import 'package:novella/features/auth/login_page.dart';
import 'package:novella/core/sync/sync_manager.dart';
import 'package:novella/core/services/update_service.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:novella/features/settings/widgets/settings_header_card.dart';

class AboutSettingsPage extends ConsumerWidget {
  const AboutSettingsPage({super.key});

  static const _feedbackLinks = <_FeedbackLink>[
    _FeedbackLink(
      title: '项目站点',
      subtitle: 'novella.celia.sh',
      url: 'https://novella.celia.sh',
      icon: Icons.language,
      telemetryItem: TelemetryExternalLinkItems.projectSite,
    ),
    _FeedbackLink(
      title: 'GitHub Repository',
      subtitle: '点亮仓库的小星星',
      url: 'https://github.com/Kanscape/Novella',
      icon: Icons.star_border,
      telemetryItem: TelemetryExternalLinkItems.githubRepository,
    ),
    _FeedbackLink(
      title: 'GitHub Discussions',
      subtitle: '功能建议与使用讨论',
      url: 'https://github.com/Kanscape/Novella/discussions',
      icon: Icons.forum_outlined,
      telemetryItem: TelemetryExternalLinkItems.githubDiscussions,
    ),
    _FeedbackLink(
      title: 'GitHub Issues',
      subtitle: '问题反馈与进度追踪',
      url: 'https://github.com/Kanscape/Novella/issues',
      icon: Icons.bug_report_outlined,
      telemetryItem: TelemetryExternalLinkItems.githubIssues,
    ),
    _FeedbackLink(
      title: '轻书架留学生',
      subtitle: '轻书架官方群组，严禁讨论软件相关',
      url: 'https://t.me/+J5xdTWVGOJMyOWRl',
      icon: Icons.telegram,
      telemetryItem: TelemetryExternalLinkItems.lightnovelGroup,
    ),
    _FeedbackLink(
      title: '白毛是对的',
      subtitle: '客户端开发群组，更新动态与软件反馈',
      url: 'https://t.me/+rZYx8H_TvUpmZjJh',
      icon: Icons.telegram,
      telemetryItem: TelemetryExternalLinkItems.developerGroup,
    ),
  ];

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

              SwitchListTile(
                secondary: const Icon(Icons.local_fire_department_outlined),
                title: const Text('协助改进'),
                subtitle: const Text('发送错误报告与诊断上下文'),
                value: settings.telemetryDiagnosticsEnabled,
                onChanged: (value) {
                  ref
                      .read(settingsProvider.notifier)
                      .setTelemetryDiagnosticsEnabled(value);
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

              ListTile(
                leading: const Icon(Icons.forum_outlined),
                title: const Text('外部链接'),
                subtitle: const Text('反馈与交流'),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => _showFeedbackSheet(context),
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

  Future<void> _launchFeedbackUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched || !context.mounted) {
        return;
      }
    } catch (_) {
      if (!context.mounted) {
        return;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('无法打开链接'), duration: Duration(seconds: 2)),
    );
  }

  void _showFeedbackSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
                  '反馈与交流',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  '选择一个适合的渠道',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ..._feedbackLinks.map(
                (link) => ListTile(
                  leading: Icon(link.icon, color: colorScheme.onSurfaceVariant),
                  title: Text(link.title),
                  subtitle: Text(link.subtitle),
                  trailing: Icon(
                    Icons.open_in_new,
                    size: 16,
                    color: colorScheme.outline,
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    TelemetryService.instance.track(
                      TelemetryEvents.externalLinkClicked,
                      properties: {
                        TelemetryProperties.item: link.telemetryItem,
                      },
                    );
                    await _launchFeedbackUrl(context, link.url);
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
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
                                  await AuthService().logout();

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

class _FeedbackLink {
  const _FeedbackLink({
    required this.title,
    required this.subtitle,
    required this.url,
    required this.icon,
    required this.telemetryItem,
  });

  final String title;
  final String subtitle;
  final String url;
  final IconData icon;
  final String telemetryItem;
}
