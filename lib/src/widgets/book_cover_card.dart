import 'package:flutter/material.dart';
import 'package:novella/core/widgets/m3e_loading_indicator.dart';
import 'package:novella/src/widgets/book_cover_image.dart';
import 'package:novella/src/widgets/book_cover_previewer.dart';

class BookCoverCard extends StatelessWidget {
  final String coverUrl;
  final double elevation;
  final Color? shadowColor;
  final double borderRadius;
  final bool enablePreview;
  final bool showLoading;
  final bool resolveNetworkImage;
  final bool revealedBefore;
  final VoidCallback? onRevealed;
  final bool animateSynchronouslyLoadedImage;
  final Widget? placeholder;
  final Widget? cardForeground;
  final List<Widget> overlays;

  const BookCoverCard({
    super.key,
    required this.coverUrl,
    this.elevation = 2,
    this.shadowColor,
    this.borderRadius = 12,
    this.enablePreview = true,
    this.showLoading = true,
    this.resolveNetworkImage = true,
    this.revealedBefore = false,
    this.onRevealed,
    this.animateSynchronouslyLoadedImage = false,
    this.placeholder,
    this.cardForeground,
    this.overlays = const [],
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Card(
          elevation: elevation,
          shadowColor: shadowColor ?? colorScheme.shadow.withValues(alpha: 0.3),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (coverUrl.isNotEmpty)
                _buildCoverImage()
              else
                placeholder ?? _BookCoverCardPlaceholder(colorScheme),
              if (cardForeground != null) cardForeground!,
            ],
          ),
        ),
        ...overlays,
      ],
    );
  }

  Widget _buildCoverImage() {
    final image = BookCoverImage(
      imageUrl: coverUrl,
      width: double.infinity,
      height: double.infinity,
      showLoading: showLoading,
      resolveNetworkImage: resolveNetworkImage,
      revealedBefore: revealedBefore,
      onRevealed: onRevealed,
      animateSynchronouslyLoadedImage: animateSynchronouslyLoadedImage,
    );

    if (!enablePreview) {
      return image;
    }

    return BookCoverPreviewer(coverUrl: coverUrl, child: image);
  }
}

class _BookCoverCardPlaceholder extends StatelessWidget {
  final ColorScheme colorScheme;

  const _BookCoverCardPlaceholder(this.colorScheme);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: M3ELoadingIndicator(size: 28, color: colorScheme.primary),
      ),
    );
  }
}
