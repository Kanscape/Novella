import 'package:flutter/material.dart';
import 'package:novella/data/services/book_mark_service.dart';

Future<void> showReaderTitleSheet(
  BuildContext context, {
  required int bookId,
  String? bookTitle,
  String? chapterTitle,
  ReaderTitleSheetPageProgressData? pageProgress,
}) async {
  final normalizedBookTitle = bookTitle?.trim();
  final normalizedChapterTitle = chapterTitle?.trim();
  final hasBookTitle =
      normalizedBookTitle != null && normalizedBookTitle.isNotEmpty;
  final hasChapterTitle =
      normalizedChapterTitle != null && normalizedChapterTitle.isNotEmpty;
  final hasPageProgress = pageProgress != null && pageProgress.pageCount > 1;

  if (!hasBookTitle && !hasChapterTitle && !hasPageProgress) {
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) {
      return _ReaderTitleSheetContent(
        bookId: bookId,
        bookTitle: normalizedBookTitle,
        chapterTitle: normalizedChapterTitle,
        pageProgress: pageProgress,
      );
    },
  );
}

class ReaderTitleSheetPageProgressData {
  final int currentPage;
  final int pageCount;
  final ValueChanged<int> onPageSelected;

  const ReaderTitleSheetPageProgressData({
    required this.currentPage,
    required this.pageCount,
    required this.onPageSelected,
  });
}

class _ReaderTitleSheetContent extends StatefulWidget {
  final int bookId;
  final String? bookTitle;
  final String? chapterTitle;
  final ReaderTitleSheetPageProgressData? pageProgress;

  const _ReaderTitleSheetContent({
    required this.bookId,
    required this.bookTitle,
    required this.chapterTitle,
    required this.pageProgress,
  });

  @override
  State<_ReaderTitleSheetContent> createState() =>
      _ReaderTitleSheetContentState();
}

class _ReaderTitleSheetContentState extends State<_ReaderTitleSheetContent> {
  final _bookMarkService = BookMarkService();
  BookMarkStatus _currentMark = BookMarkStatus.none;
  bool _loadingMark = true;
  bool _savingMark = false;

  @override
  void initState() {
    super.initState();
    _loadMark();
  }

  Future<void> _loadMark() async {
    final mark = await _bookMarkService.getBookMark(widget.bookId);
    if (!mounted) {
      return;
    }
    setState(() {
      _currentMark = mark;
      _loadingMark = false;
    });
  }

  Future<void> _setMark(BookMarkStatus status) async {
    if (_savingMark || _currentMark == status) {
      return;
    }

    setState(() {
      _savingMark = true;
    });

    try {
      await _bookMarkService.setBookMark(widget.bookId, status);
      if (!mounted) {
        return;
      }
      setState(() {
        _currentMark = status;
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingMark = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final hasBookTitle =
        widget.bookTitle != null && widget.bookTitle!.isNotEmpty;
    final hasChapterTitle =
        widget.chapterTitle != null && widget.chapterTitle!.isNotEmpty;
    final pageProgress = widget.pageProgress;
    final hasPageProgress = pageProgress != null && pageProgress.pageCount > 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                '阅读信息',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '快速切换书籍标记',
            style: textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ReaderMarkChip(
                icon: Icons.schedule,
                label: '待读',
                selected:
                    !_loadingMark && _currentMark == BookMarkStatus.toRead,
                busy: _savingMark,
                onTap: () => _setMark(BookMarkStatus.toRead),
              ),
              _ReaderMarkChip(
                icon: Icons.auto_stories,
                label: '在读',
                selected:
                    !_loadingMark && _currentMark == BookMarkStatus.reading,
                busy: _savingMark,
                onTap: () => _setMark(BookMarkStatus.reading),
              ),
              _ReaderMarkChip(
                icon: Icons.check_circle_outline,
                label: '已读',
                selected:
                    !_loadingMark && _currentMark == BookMarkStatus.finished,
                busy: _savingMark,
                onTap: () => _setMark(BookMarkStatus.finished),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (hasBookTitle)
            _ReaderTitleSheetItem(
              icon: Icons.menu_book_rounded,
              label: '书籍名称',
              value: widget.bookTitle!,
            ),
          if (hasBookTitle && hasChapterTitle) const SizedBox(height: 12),
          if (hasChapterTitle)
            _ReaderTitleSheetItem(
              icon: Icons.article_outlined,
              label: '章节名称',
              value: widget.chapterTitle!,
            ),
          if ((hasBookTitle || hasChapterTitle) && hasPageProgress)
            const SizedBox(height: 18),
          if (hasPageProgress)
            ReaderTitleSheetPageProgress(
              currentPage: pageProgress.currentPage,
              pageCount: pageProgress.pageCount,
              onPageSelected: pageProgress.onPageSelected,
            ),
        ],
      ),
    );
  }
}

class ReaderTitleSheetPageProgress extends StatefulWidget {
  final int currentPage;
  final int pageCount;
  final ValueChanged<int> onPageSelected;

  const ReaderTitleSheetPageProgress({
    super.key,
    required this.currentPage,
    required this.pageCount,
    required this.onPageSelected,
  });

  @override
  State<ReaderTitleSheetPageProgress> createState() =>
      _ReaderTitleSheetPageProgressState();
}

class _ReaderTitleSheetPageProgressState
    extends State<ReaderTitleSheetPageProgress> {
  late double _pageValue;

  int get _clampedCurrentPage =>
      widget.currentPage.clamp(1, widget.pageCount).toInt();

  @override
  void initState() {
    super.initState();
    _pageValue = _clampedCurrentPage.toDouble();
  }

  @override
  void didUpdateWidget(ReaderTitleSheetPageProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPage != widget.currentPage ||
        oldWidget.pageCount != widget.pageCount) {
      _pageValue = _clampedCurrentPage.toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final pageCount = widget.pageCount.clamp(1, 1000000).toInt();
    final displayPage = _pageValue.round().clamp(1, pageCount).toInt();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.linear_scale_rounded,
            color: colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '章节进度',
                        style: textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(
                      '$displayPage / $pageCount',
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderTheme.of(
                    context,
                  ).copyWith(padding: EdgeInsets.zero),
                  child: Slider(
                    min: 1,
                    max: pageCount.toDouble(),
                    divisions: pageCount > 1 ? pageCount - 1 : null,
                    value: _pageValue.clamp(1, pageCount).toDouble(),
                    onChanged:
                        pageCount > 1
                            ? (value) {
                              setState(() {
                                _pageValue = value;
                              });
                            }
                            : null,
                    onChangeEnd:
                        pageCount > 1
                            ? (value) {
                              final selectedPage = value.round().clamp(
                                1,
                                pageCount,
                              );
                              setState(() {
                                _pageValue = selectedPage.toDouble();
                              });
                              widget.onPageSelected(selectedPage);
                            }
                            : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReaderTitleSheetItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ReaderTitleSheetItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReaderMarkChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool busy;
  final VoidCallback onTap;

  const _ReaderMarkChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FilledButton.tonalIcon(
      onPressed: busy ? null : onTap,
      icon:
          busy && selected
              ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              )
              : Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor:
            selected
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        foregroundColor:
            selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }
}
