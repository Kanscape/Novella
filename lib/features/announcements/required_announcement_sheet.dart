import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novella/features/announcements/announcement_models.dart';
import 'package:novella/features/announcements/announcement_provider.dart';

Future<AnnouncementCompletionActionType?> showRequiredAnnouncementSheet({
  required BuildContext context,
  required WidgetRef ref,
  required AppAnnouncement announcement,
}) {
  return showModalBottomSheet<AnnouncementCompletionActionType>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    useSafeArea: true,
    builder:
        (_) => RequiredAnnouncementSheet(
          announcement: announcement,
          loadMarkdown:
              () => ref
                  .read(announcementProvider.notifier)
                  .fetchAppMarkdown(announcement),
          markRead:
              () => ref
                  .read(announcementProvider.notifier)
                  .markAppAnnouncementRead(announcement),
        ),
  );
}

class RequiredAnnouncementSheet extends StatefulWidget {
  const RequiredAnnouncementSheet({
    super.key,
    required this.announcement,
    required this.loadMarkdown,
    required this.markRead,
  });

  static const Key readButtonKey = ValueKey<String>(
    'required_announcement_read_button',
  );

  final AppAnnouncement announcement;
  final Future<String> Function() loadMarkdown;
  final Future<void> Function() markRead;

  @override
  State<RequiredAnnouncementSheet> createState() =>
      _RequiredAnnouncementSheetState();
}

class _RequiredAnnouncementSheetState extends State<RequiredAnnouncementSheet> {
  late Future<String> _markdownFuture;
  Timer? _timer;
  late int _remainingSeconds;
  bool _markingRead = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.announcement.requiredReadSeconds;
    _markdownFuture = _loadMarkdownForReading();
  }

  Future<String> _loadMarkdownForReading() async {
    final markdown = await widget.loadMarkdown();
    if (mounted) {
      _startReadTimer();
    }
    return markdown;
  }

  void _startReadTimer() {
    _timer?.cancel();
    if (_remainingSeconds <= 0) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _remainingSeconds <= 0) {
        _timer?.cancel();
        return;
      }
      setState(() {
        _remainingSeconds -= 1;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _retry() {
    _timer?.cancel();
    setState(() {
      _remainingSeconds = widget.announcement.requiredReadSeconds;
      _markdownFuture = _loadMarkdownForReading();
    });
  }

  Future<void> _confirmRead() async {
    setState(() {
      _markingRead = true;
    });

    try {
      await widget.markRead();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(widget.announcement.completionAction.type);
    } finally {
      if (mounted) {
        setState(() {
          _markingRead = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;

    return PopScope(
      canPop: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.announcement.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '请阅读后继续',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<String>(
                future: _markdownFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 40),
                            const SizedBox(height: 12),
                            const Text('公告内容加载失败'),
                            const SizedBox(height: 12),
                            FilledButton.tonalIcon(
                              onPressed: _retry,
                              icon: const Icon(Icons.refresh),
                              label: const Text('重试'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Markdown(
                    data: snapshot.data ?? '',
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                      p: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            FutureBuilder<String>(
              future: _markdownFuture,
              builder: (context, snapshot) {
                final canRead =
                    _remainingSeconds <= 0 && snapshot.hasData && !_markingRead;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: FilledButton(
                    key: RequiredAnnouncementSheet.readButtonKey,
                    onPressed: canRead ? _confirmRead : null,
                    child: Text(
                      _remainingSeconds > 0
                          ? '我已阅读（$_remainingSeconds）'
                          : _markingRead
                          ? '记录中'
                          : '我已阅读',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
