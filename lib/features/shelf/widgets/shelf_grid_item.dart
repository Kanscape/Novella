import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novella/core/widgets/m3e_loading_indicator.dart';
import 'package:novella/data/models/book.dart';
import 'package:novella/features/settings/settings_provider.dart';
import 'package:novella/src/widgets/book_cover_image.dart';
import 'package:novella/src/widgets/book_cover_previewer.dart';
import 'package:novella/src/widgets/book_type_badge.dart';

class ShelfBookGridItem extends ConsumerWidget {
  final Book? book;
  final String? coverUrlHint;
  final String? shelfTitle;
  final String? titleHint;
  final int bookId;
  final String heroTag;
  final VoidCallback onTap;
  final bool selected;
  final bool sortMode;
  final String badgeContext;
  final bool enableHero;
  final bool enablePreview;
  final bool resolveHintCoverImage;
  final bool coverRevealed;
  final VoidCallback? onCoverRevealed;

  const ShelfBookGridItem({
    super.key,
    required this.book,
    this.coverUrlHint,
    this.shelfTitle,
    this.titleHint,
    required this.bookId,
    required this.heroTag,
    required this.onTap,
    this.selected = false,
    this.sortMode = false,
    this.badgeContext = 'shelf',
    this.enableHero = true,
    this.enablePreview = true,
    this.resolveHintCoverImage = false,
    this.coverRevealed = false,
    this.onCoverRevealed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final displayTitle =
        book?.title ??
        (shelfTitle?.isNotEmpty == true ? shelfTitle! : titleHint ?? '加载中');

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child:
                enableHero
                    ? Hero(tag: heroTag, child: _buildCardContent(context, ref))
                    : _buildCardContent(context, ref),
          ),
          SizedBox(
            height: 36,
            child: Padding(
              padding: const EdgeInsets.only(top: 6, left: 2, right: 2),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final slide = Tween<Offset>(
                    begin: const Offset(0, 0.08),
                    end: Offset.zero,
                  ).animate(animation);

                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
                child: Text(
                  displayTitle,
                  key: ValueKey(displayTitle),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardContent(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedCoverUrl = book?.cover ?? coverUrlHint ?? '';
    final canResolveNetworkImage =
        book != null ||
        (resolveHintCoverImage && coverUrlHint?.isNotEmpty == true);

    return Stack(
      children: [
        Card(
          elevation: sortMode ? 0 : 2,
          shadowColor:
              sortMode
                  ? Colors.transparent
                  : colorScheme.shadow.withValues(alpha: 0.3),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (resolvedCoverUrl.isNotEmpty)
                BookCoverPreviewer(
                  coverUrl: resolvedCoverUrl,
                  child: BookCoverImage(
                    imageUrl: resolvedCoverUrl,
                    width: double.infinity,
                    height: double.infinity,
                    showLoading: !canResolveNetworkImage || enablePreview,
                    resolveNetworkImage: canResolveNetworkImage,
                    revealedBefore: coverRevealed,
                    onRevealed: onCoverRevealed,
                    animateSynchronouslyLoadedImage: book != null,
                  ),
                )
              else
                ColoredBox(
                  color: colorScheme.surfaceContainerHighest,
                  child: Center(
                    child: M3ELoadingIndicator(
                      size: 28,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              _ShelfCardOverlay(selected: selected, sortMode: sortMode),
            ],
          ),
        ),
        if (ref.watch(settingsProvider).isBookTypeBadgeEnabled(badgeContext))
          BookTypeBadge(
            category: book?.category,
            visible: book != null,
            reserveSpaceWhenHidden: true,
          ),
      ],
    );
  }
}

class ShelfFolderGridItem extends ConsumerWidget {
  final String title;
  final int itemCount;
  final VoidCallback onTap;
  final List<int> previewBookIds;
  final Map<int, Book> previewBookDetails;
  final Map<int, String> previewBookHints;
  final Set<String> revealedPreviewKeys;
  final ValueChanged<String>? onPreviewRevealed;
  final bool selected;
  final bool sortMode;
  final String badgeContext;

  const ShelfFolderGridItem({
    super.key,
    required this.title,
    required this.itemCount,
    required this.onTap,
    this.previewBookIds = const [],
    this.previewBookDetails = const {},
    this.previewBookHints = const {},
    this.revealedPreviewKeys = const <String>{},
    this.onPreviewRevealed,
    this.selected = false,
    this.sortMode = false,
    this.badgeContext = 'shelf',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final displayTitle = title.isEmpty ? '未命名文件夹' : title;
    final showBadge = ref
        .watch(settingsProvider)
        .isBookTypeBadgeEnabled(badgeContext);

    return Semantics(
      button: true,
      label: '$displayTitle，文件夹，$itemCount 项',
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Card(
                    elevation: sortMode ? 0 : 2,
                    shadowColor:
                        sortMode
                            ? Colors.transparent
                            : colorScheme.shadow.withValues(alpha: 0.3),
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color:
                                previewBookIds.isEmpty
                                    ? colorScheme.secondaryContainer.withValues(
                                      alpha: 0.6,
                                    )
                                    : colorScheme.surfaceContainerHighest,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child:
                                previewBookIds.isEmpty
                                    ? _EmptyFolderPreview(
                                      color: colorScheme.primary,
                                    )
                                    : _FolderPreviewGrid(
                                      previewBookIds: previewBookIds,
                                      previewBookDetails: previewBookDetails,
                                      previewBookHints: previewBookHints,
                                      revealedPreviewKeys: revealedPreviewKeys,
                                      onPreviewRevealed: onPreviewRevealed,
                                    ),
                          ),
                        ),
                        _ShelfCardOverlay(
                          selected: selected,
                          sortMode: sortMode,
                        ),
                      ],
                    ),
                  ),
                  if (showBadge)
                    _ShelfFolderBadge(
                      backgroundColor: colorScheme.primary,
                      iconColor: colorScheme.onPrimary,
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 36,
              child: Padding(
                padding: const EdgeInsets.only(top: 6, left: 2, right: 2),
                child: Text(
                  displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShelfCardOverlay extends StatelessWidget {
  final bool selected;
  final bool sortMode;

  const _ShelfCardOverlay({required this.selected, required this.sortMode});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (sortMode) {
      return ColoredBox(
        color: colorScheme.scrim.withValues(alpha: 0.42),
        child: Center(
          child: Icon(Icons.drag_indicator, color: Colors.white, size: 30),
        ),
      );
    }

    if (!selected) {
      return const SizedBox.shrink();
    }

    return ColoredBox(
      color: colorScheme.primary.withValues(alpha: 0.45),
      child: Center(
        child: Icon(Icons.check_circle, color: colorScheme.onPrimary, size: 32),
      ),
    );
  }
}

class _FolderPreviewGrid extends StatelessWidget {
  final List<int> previewBookIds;
  final Map<int, Book> previewBookDetails;
  final Map<int, String> previewBookHints;
  final Set<String> revealedPreviewKeys;
  final ValueChanged<String>? onPreviewRevealed;

  const _FolderPreviewGrid({
    required this.previewBookIds,
    required this.previewBookDetails,
    required this.previewBookHints,
    required this.revealedPreviewKeys,
    required this.onPreviewRevealed,
  });

  @override
  Widget build(BuildContext context) {
    final previewIds = previewBookIds.take(4).toList(growable: false);
    final slots = List<int?>.generate(
      4,
      (index) => index < previewIds.length ? previewIds[index] : null,
      growable: false,
    );
    const spacing = 8.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = (constraints.maxWidth - spacing) / 2;

        return Center(
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final bookId in slots)
                SizedBox(
                  width: cellWidth,
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: _FolderPreviewSlot(
                      bookId: bookId,
                      books: previewBookDetails,
                      coverHints: previewBookHints,
                      revealedPreviewKeys: revealedPreviewKeys,
                      onPreviewRevealed: onPreviewRevealed,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _FolderPreviewSlot extends StatelessWidget {
  final int? bookId;
  final Map<int, Book> books;
  final Map<int, String> coverHints;
  final Set<String> revealedPreviewKeys;
  final ValueChanged<String>? onPreviewRevealed;

  const _FolderPreviewSlot({
    required this.bookId,
    required this.books,
    required this.coverHints,
    required this.revealedPreviewKeys,
    required this.onPreviewRevealed,
  });

  @override
  Widget build(BuildContext context) {
    final book = bookId == null ? null : books[bookId];
    final coverUrl =
        book?.cover ?? (bookId == null ? null : coverHints[bookId!]);
    final canResolveNetworkImage = book != null;
    final revealKey = bookId == null ? null : 'shelf_folder_preview_$bookId';

    return ClipRRect(
      key: ValueKey('folder_preview_${bookId ?? 'empty'}'),
      borderRadius: BorderRadius.circular(6),
      child:
          bookId == null
              ? const _FolderPreviewEmptySlot()
              : coverUrl?.isNotEmpty == true
              ? BookCoverImage(
                imageUrl: coverUrl!,
                width: double.infinity,
                height: double.infinity,
                memCacheWidth: 180,
                showLoading: true,
                resolveNetworkImage: canResolveNetworkImage,
                revealedBefore:
                    revealKey != null &&
                    revealedPreviewKeys.contains(revealKey),
                onRevealed:
                    revealKey == null || onPreviewRevealed == null
                        ? null
                        : () => onPreviewRevealed!(revealKey),
                animateSynchronouslyLoadedImage: book != null,
              )
              : const _FolderPreviewPlaceholder(),
    );
  }
}

class _FolderPreviewPlaceholder extends StatelessWidget {
  const _FolderPreviewPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: colorScheme.surfaceContainerHigh,
      child: Center(
        child: Icon(
          Icons.menu_book_outlined,
          size: 16,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _FolderPreviewEmptySlot extends StatelessWidget {
  const _FolderPreviewEmptySlot();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ColoredBox(color: colorScheme.surfaceContainerHigh);
  }
}

class _EmptyFolderPreview extends StatelessWidget {
  final Color color;

  const _EmptyFolderPreview({required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(Icons.folder_copy_rounded, size: 56, color: color),
    );
  }
}

class _ShelfFolderBadge extends StatelessWidget {
  final Color backgroundColor;
  final Color iconColor;

  const _ShelfFolderBadge({
    required this.backgroundColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 4,
      bottom: 4,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.folder_copy_rounded, size: 14, color: iconColor),
      ),
    );
  }
}
