import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:novella/core/utils/cover_url_utils.dart';
import 'package:novella/core/widgets/m3e_loading_indicator.dart';

/// 统一封面图片组件
///
/// 使用 Stack 分层避免 placeholder 切换闪烁：
/// 底层 BlurHash 常驻显示 → 上层图片加载完成后淡入覆盖。
class BookCoverImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final bool showLoading;
  final bool resolveNetworkImage;
  final bool revealedBefore;
  final VoidCallback? onRevealed;
  final bool animateSynchronouslyLoadedImage;
  final Duration fadeInDuration;

  const BookCoverImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.memCacheWidth = 350, // 列表格子的合理极限宽度，足以提供视网膜级清晰度同时节省超大原图内存
    this.memCacheHeight,
    this.showLoading = true,
    this.resolveNetworkImage = true,
    this.revealedBefore = false,
    this.onRevealed,
    this.animateSynchronouslyLoadedImage = false,
    this.fadeInDuration = const Duration(milliseconds: 200),
  });

  @override
  State<BookCoverImage> createState() => _BookCoverImageState();
}

class _BookCoverImageState extends State<BookCoverImage> {
  static const Duration _minimumPlaceholderDuration = Duration(
    milliseconds: 120,
  );

  int _retryCount = 0;
  bool _showResolvedImage = false;
  bool _revealScheduled = false;
  DateTime _imageStartedAt = DateTime.now();
  Timer? _revealTimer;

  @override
  void initState() {
    super.initState();
    _resetImageState();
  }

  @override
  void didUpdateWidget(BookCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.resolveNetworkImage != widget.resolveNetworkImage ||
        oldWidget.revealedBefore != widget.revealedBefore) {
      _retryCount = 0;
      _resetImageState();
    }
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    super.dispose();
  }

  void _retry() {
    if (!mounted) return;
    CachedNetworkImage.evictFromCache(widget.imageUrl).then((_) {
      if (mounted) {
        setState(() {
          _retryCount++;
          _resetImageState();
        });
      }
    });
  }

  void _resetImageState() {
    _revealTimer?.cancel();
    _revealTimer = null;
    _showResolvedImage = widget.revealedBefore;
    _revealScheduled = widget.revealedBefore;
    _imageStartedAt = DateTime.now();
  }

  void _markRevealed() {
    widget.onRevealed?.call();
  }

  void _scheduleImmediateReveal() {
    if (_showResolvedImage || _revealScheduled) {
      return;
    }

    _revealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final needsUpdate = !_showResolvedImage;
      if (needsUpdate) {
        setState(() {
          _showResolvedImage = true;
        });
      }
      _markRevealed();
    });
  }

  void _scheduleReveal() {
    if (_showResolvedImage || _revealScheduled) {
      return;
    }

    _revealScheduled = true;
    final remaining =
        _minimumPlaceholderDuration -
        DateTime.now().difference(_imageStartedAt);

    if (remaining <= Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _showResolvedImage = true;
        });
        _markRevealed();
      });
      return;
    }

    _revealTimer = Timer(remaining, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showResolvedImage = true;
      });
      _markRevealed();
    });
  }

  Widget _buildBasePlaceholder(ColorScheme colorScheme, String? blurHash) {
    if (blurHash != null) {
      return BlurHash(
        hash: blurHash,
        imageFit: widget.fit,
        decodingWidth: 32,
        decodingHeight: 48,
        color: Colors.transparent,
      );
    }

    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.book_outlined, color: colorScheme.onSurfaceVariant),
      ),
    );
  }

  Widget _buildLoadingPlaceholder(ColorScheme colorScheme, String? blurHash) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.showLoading)
          Center(
            child: M3ELoadingIndicator(
              color:
                  blurHash != null
                      ? Colors.white.withValues(alpha: 0.8)
                      : colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // extractBlurHash 内含完整验证，返回 null 表示无效
    final blurHash = CoverUrlUtils.extractBlurHash(widget.imageUrl);
    final cacheKey = ValueKey('${widget.imageUrl}_$_retryCount');

    if (widget.imageUrl.isEmpty) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: _buildBasePlaceholder(colorScheme, blurHash),
      );
    }

    if (!widget.resolveNetworkImage) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildBasePlaceholder(colorScheme, blurHash),
            if (widget.showLoading)
              _buildLoadingPlaceholder(colorScheme, blurHash),
          ],
        ),
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildBasePlaceholder(colorScheme, blurHash),
          Image(
            key: cacheKey,
            image: CachedNetworkImageProvider(
              widget.imageUrl,
              maxWidth: widget.memCacheWidth,
              maxHeight: widget.memCacheHeight,
            ),
            fit: widget.fit,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) {
                if (widget.animateSynchronouslyLoadedImage &&
                    !_showResolvedImage) {
                  _scheduleReveal();
                } else {
                  _scheduleImmediateReveal();
                  return child;
                }
              }

              if (frame != null) {
                _scheduleReveal();
              }

              return Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedOpacity(
                    opacity: _showResolvedImage ? 1 : 0,
                    duration: widget.fadeInDuration,
                    curve: Curves.easeOut,
                    child: child,
                  ),
                  if (!_showResolvedImage)
                    _buildLoadingPlaceholder(colorScheme, blurHash),
                ],
              );
            },
            errorBuilder: (_, __, ___) {
              // 出错时自动重试一次
              if (_retryCount == 0) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _retry();
                });
              }

              return GestureDetector(
                onTap: _retry, // 暴露给用户手动点击的二次机制
                behavior: HitTestBehavior.opaque,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color:
                          blurHash != null
                              ? Colors.black.withValues(alpha: 0.15)
                              : Colors.transparent,
                    ),
                    Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color:
                            blurHash != null
                                ? Colors.white.withValues(alpha: 0.75)
                                : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
