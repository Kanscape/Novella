import 'package:flutter/material.dart';
import 'package:novella/features/community/community_board_icon.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String communityPostNoticeAcceptedPrefsKey =
    'community_post_notice_accepted_v1';
const Key communityPostNoticeContinueButtonKey = ValueKey(
  'community-post-notice-continue-button',
);
const Key communityPostNoticeCloseButtonKey = ValueKey(
  'community-post-notice-close-button',
);
const Key communityPostNoticePanelKey = ValueKey('community-post-notice-panel');
const Key communityPostNoticeContentKey = ValueKey(
  'community-post-notice-content',
);
const Key communityPostNoticeScrollKey = ValueKey(
  'community-post-notice-scroll',
);

class CommunityPostNoticeStore {
  CommunityPostNoticeStore({Future<SharedPreferences> Function()? prefsLoader})
    : _prefsLoader = prefsLoader ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _prefsLoader;

  Future<bool> hasAccepted() async {
    final prefs = await _prefsLoader();
    return prefs.getBool(communityPostNoticeAcceptedPrefsKey) ?? false;
  }

  Future<void> markAccepted() async {
    final prefs = await _prefsLoader();
    await prefs.setBool(communityPostNoticeAcceptedPrefsKey, true);
  }
}

Future<bool> ensureCommunityPostNoticeAccepted(
  BuildContext context, {
  CommunityPostNoticeStore? store,
}) async {
  final noticeStore = store ?? CommunityPostNoticeStore();
  if (await noticeStore.hasAccepted()) {
    return true;
  }

  if (!context.mounted) {
    return false;
  }

  final colorScheme = Theme.of(context).colorScheme;
  final accepted =
      await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        builder: (sheetContext) => const _CommunityPostNoticeSheet(),
      ) ??
      false;

  if (!accepted) {
    return false;
  }

  await noticeStore.markAccepted();
  return true;
}

class _CommunityPostNoticeSheet extends StatelessWidget {
  const _CommunityPostNoticeSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final bodyStyle = textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
      height: 1.58,
    );

    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            key: communityPostNoticePanelKey,
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    key: communityPostNoticeScrollKey,
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Column(
                      key: communityPostNoticeContentKey,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton.filledTonal(
                            key: communityPostNoticeCloseButtonKey,
                            tooltip: '关闭',
                            style: IconButton.styleFrom(
                              fixedSize: const Size.square(48),
                              minimumSize: const Size.square(48),
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => Navigator.of(context).pop(false),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ),
                        const SizedBox(height: 28),
                        CommunityBoardIconBadge(
                          accent: colorScheme.primary,
                          iconName: 'forum',
                          fallbackText: '社区',
                          size: 68,
                          iconSize: 32,
                          borderRadius: 22,
                        ),
                        const SizedBox(height: 22),
                        Text(
                          '使用须知',
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        RichText(
                          text: TextSpan(
                            style: bodyStyle,
                            children: [
                              const TextSpan(text: '继续操作，即表示你'),
                              TextSpan(
                                text: '已阅读并同意所有公告',
                                style: bodyStyle?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const TextSpan(text: '。'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text('社区相关内容，请着重注意以下事项：', style: bodyStyle),
                        const SizedBox(height: 16),
                        _NoticeBullet(
                          title: '应用相关问题请前往 GitHub 反馈',
                          body: TextSpan(
                            style: bodyStyle,
                            children: [
                              const TextSpan(text: '请不要在社区内反馈应用相关问题，否则可能导致'),
                              TextSpan(
                                text: '账号被封禁',
                                style: bodyStyle?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const TextSpan(text: '。\n详见：设置 - 关于 - 反馈与交流。'),
                            ],
                          ),
                        ),
                        _NoticeBullet(
                          title: '请在合适的版块发帖',
                          body: TextSpan(
                            style: bodyStyle,
                            children: [
                              const TextSpan(
                                text: '发帖前请确认内容与版块主题相符。发布在不合适的版块可能导致',
                              ),
                              TextSpan(
                                text: '账号被封禁',
                                style: bodyStyle?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const TextSpan(text: '。'),
                            ],
                          ),
                        ),
                        _NoticeBullet(
                          title: '请保持友好交流',
                          body: TextSpan(
                            text: '社区成员、开发者和管理员都没有义务必须为你提供服务。请尊重他人，理性沟通。',
                            style: bodyStyle,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '请珍惜你的账号。',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: communityPostNoticeContinueButtonKey,
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('我已阅读，继续发帖'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoticeBullet extends StatelessWidget {
  const _NoticeBullet({required this.title, required this.body});

  final String title;
  final TextSpan body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                RichText(text: body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
