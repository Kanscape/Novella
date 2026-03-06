import 'dart:convert';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:novella/features/settings/settings_provider.dart';
import 'dart:developer' as developer;

class UpdateService {
  static const String _releasesUrl =
      'https://api.github.com/repos/Kanscape/Novella/releases/latest';

  /// 检查更新
  ///
  /// [context] 用于显示弹窗
  /// [ref] 用于读取设置（自动检查开关）
  /// [manual] 是否为手动触发。手动触发时，即使开关关闭也会检查，且无更新时会有提示。
  static Future<void> checkUpdate(
    BuildContext context,
    WidgetRef ref, {
    bool manual = false,
  }) async {
    final settings = ref.read(settingsProvider);

    // 1. 检查自动更新开关
    if (!manual) {
      if (!settings.autoCheckUpdate) {
        developer.log('自动更新已关闭，跳过检查', name: 'UpdateService');
        return;
      }
    }

    try {
      if (manual && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('正在检查更新...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      // 2. 获取本地版本
      final packageInfo = await PackageInfo.fromPlatform();
      final localVersion = packageInfo.version;

      // 3. 获取远程版本
      developer.log('正在请求 GitHub Release...', name: 'UpdateService');
      final response = await http.get(Uri.parse(_releasesUrl));

      if (response.statusCode != 200) {
        developer.log(
          '获取更新失败: ${response.statusCode} - ${response.body}',
          name: 'UpdateService',
        );
        if (manual && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('检查更新失败: HTTP ${response.statusCode}')),
          );
        }
        return;
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      String tagName = data['tag_name'] ?? '';
      final String htmlUrl = data['html_url'] ?? '';
      final String body = data['body'] ?? '暂无更新日志';

      // 去除 'v' 前缀
      if (tagName.startsWith('v')) {
        tagName = tagName.substring(1);
      }

      // 4. 版本比较 (Local < Remote ?)
      if (_isVersionLower(localVersion, tagName)) {
        // 检查是否已忽略此版本 (仅自动检查时生效)
        if (!manual && settings.ignoredUpdateVersion == tagName) {
          developer.log('版本 $tagName 已被忽略', name: 'UpdateService');
          return;
        }

        developer.log(
          '发现新版本: $tagName (本地: $localVersion)',
          name: 'UpdateService',
        );
        if (context.mounted) {
          _showUpdateDialog(context, ref, tagName, localVersion, body, htmlUrl);
        }
      } else {
        developer.log(
          '当前已是最新或更高版本 (本地: $localVersion, 远程: $tagName)',
          name: 'UpdateService',
        );
        if (manual && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('当前已是最新版本')));
        }
      }
    } catch (e, s) {
      developer.log('检查更新出错', name: 'UpdateService', error: e, stackTrace: s);
      if (manual && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('检查更新出错: $e')));
      }
    }
  }

  /// 比较版本号
  /// 返回 true 如果 local < remote
  static bool _isVersionLower(String local, String remote) {
    try {
      final localParts = local.split('.').map(int.parse).toList();
      final remoteParts = remote.split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        final l = i < localParts.length ? localParts[i] : 0;
        final r = i < remoteParts.length ? remoteParts[i] : 0;
        if (l < r) return true;
        if (l > r) return false;
      }
      return false; // 相等
    } catch (e) {
      developer.log('版本号解析失败: $local vs $remote', name: 'UpdateService');
      return false; // 解析失败则假设不需要更新
    }
  }

  static void _showUpdateDialog(
    BuildContext context,
    WidgetRef ref,
    String version,
    String currentVersion,
    String log,
    String url,
  ) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题区域
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '发现新版本',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$currentVersion -> $version',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              // markdown内容区域
              Expanded(
                child: Markdown(
                  data: log,
                  styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                    p: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    h1: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    h2: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    h3: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    listBullet: theme.textTheme.bodyMedium,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
              ),
              const Divider(height: 1),
              // 底部按钮
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          // 如果已经忽略过，点击只是暂时忽略（不重复写入）
                          final isIgnored =
                              ref.read(settingsProvider).ignoredUpdateVersion ==
                              version;
                          if (!isIgnored) {
                            ref
                                .read(settingsProvider.notifier)
                                .setIgnoredUpdateVersion(version);
                          }
                          Navigator.pop(context);
                        },
                        child: Text(
                          ref.watch(settingsProvider).ignoredUpdateVersion ==
                                  version
                              ? '我已知晓'
                              : '忽略此版本',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _launchUrl(url);
                        },
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('前往下载'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
