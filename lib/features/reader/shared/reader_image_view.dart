import 'dart:io';
import 'dart:typed_data';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:novella/core/widgets/m3e_loading_indicator.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:share_plus/share_plus.dart';

const int _readerImagePreviewMaxZoomPercent = 600;
const double _readerImagePreviewGroupWidth = 44;
const double _readerImagePreviewGroupSpacing = 6;
const double _readerImagePreviewGroupHeight = 48;
const double _readerImagePreviewGroupButtonHeight = 40;
const double _readerImagePreviewGroupIconSize = 20;
const String _novellaAlbumName = 'Novella';
const String _shareImageTitle = '分享图片';
const String _galleryAccessDeniedMessage = '未获得相册访问权限';
const String _imageSavedMessage = '图片已保存到相册';
const String _saveImageFailedMessage = '保存图片失败';
const String _shareImageFailedMessage = '分享图片失败';
const String _shareWindowsFallbackMessage = '当前 Windows 版本不支持文件分享，已改为分享图片链接';
const String _notEnoughSpaceMessage = '设备剩余空间不足';
const String _unsupportedFormatMessage = '图片格式暂不支持保存';

class _DownloadedImageFile {
  final String filePath;
  final String fileName;
  final String mimeType;
  final Uint8List bytes;

  const _DownloadedImageFile({
    required this.filePath,
    required this.fileName,
    required this.mimeType,
    required this.bytes,
  });
}

Future<void> showReaderImagePreview(
  BuildContext context, {
  required String imageUrl,
  String? alt,
}) async {
  final trimmedUrl = imageUrl.trim();
  if (trimmedUrl.isEmpty) {
    return;
  }

  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'reader_image_preview',
    barrierColor: Colors.black.withValues(alpha: 0.96),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialogContext, _, __) {
      return _ReaderImagePreviewDialog(imageUrl: trimmedUrl, alt: alt?.trim());
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _ReaderImagePreviewDialog extends StatefulWidget {
  final String imageUrl;
  final String? alt;

  const _ReaderImagePreviewDialog({required this.imageUrl, this.alt});

  @override
  State<_ReaderImagePreviewDialog> createState() =>
      _ReaderImagePreviewDialogState();
}

class _ReaderImagePreviewDialogState extends State<_ReaderImagePreviewDialog> {
  bool _isSaving = false;
  bool _isSharing = false;

  @override
  Widget build(BuildContext context) {
    final imageProvider = CachedNetworkImageProvider(widget.imageUrl);

    return Material(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: PhotoView(
              imageProvider: imageProvider,
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              initialScale: PhotoViewComputedScale.contained,
              minScale: PhotoViewComputedScale.contained,
              maxScale:
                  PhotoViewComputedScale.contained *
                  (_readerImagePreviewMaxZoomPercent / 100),
              basePosition: Alignment.center,
              tightMode: true,
              filterQuality: FilterQuality.medium,
              heroAttributes: PhotoViewHeroAttributes(tag: widget.imageUrl),
              loadingBuilder:
                  (context, event) =>
                      const Center(child: M3ELoadingIndicator(size: 26)),
              errorBuilder:
                  (context, error, stackTrace) => Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white.withValues(alpha: 0.85),
                    size: 44,
                  ),
              semanticLabel: widget.alt?.isNotEmpty == true ? widget.alt : null,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Center(
                  child: AdaptiveActionGroup(
                    foregroundColor:
                        PlatformInfo.isIOS26OrHigher()
                            ? null
                            : Colors.white.withValues(alpha: 0.96),
                    height: _readerImagePreviewGroupHeight,
                    buttonHeight: _readerImagePreviewGroupButtonHeight,
                    iconButtonWidth: _readerImagePreviewGroupWidth,
                    itemSpacing: _readerImagePreviewGroupSpacing,
                    iconSize: _readerImagePreviewGroupIconSize,
                    showDividers: false,
                    horizontalPadding: 0,
                    loadingBuilder:
                        (context) =>
                            PlatformInfo.isIOS
                                ? const CupertinoActivityIndicator()
                                : const M3ELoadingIndicator(size: 18),
                    items: _buildActionItems(context),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<AdaptiveActionGroupItem> _buildActionItems(BuildContext context) {
    return [
      AdaptiveActionGroupItem(
        iosSymbol: 'square.and.arrow.up',
        icon:
            PlatformInfo.isIOS
                ? CupertinoIcons.square_arrow_up
                : Icons.share_rounded,
        onPressed: _isSharing ? null : () => _shareImage(context),
        enabled: !_isSharing,
        loading: _isSharing,
      ),
      AdaptiveActionGroupItem(
        iosSymbol: 'xmark',
        icon: PlatformInfo.isIOS ? CupertinoIcons.xmark : Icons.close_rounded,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      AdaptiveActionGroupItem(
        iosSymbol: 'square.and.arrow.down',
        icon:
            PlatformInfo.isIOS
                ? CupertinoIcons.arrow_down_to_line
                : Icons.download_rounded,
        onPressed: _isSaving ? null : () => _saveImage(context),
        enabled: !_isSaving,
        loading: _isSaving,
      ),
    ];
  }

  Future<void> _saveImage(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);

    setState(() {
      _isSaving = true;
    });

    try {
      if (!PlatformInfo.isWindows) {
        var hasAccess = await Gal.hasAccess(toAlbum: true);
        if (!hasAccess) {
          await Gal.requestAccess(toAlbum: true);
          hasAccess = await Gal.hasAccess(toAlbum: true);
        }

        if (!hasAccess) {
          _showMessage(messenger, _galleryAccessDeniedMessage);
          return;
        }
      }

      final downloadedImage = await _downloadImageToTempFile();
      if (PlatformInfo.isIOS) {
        await Gal.putImageBytes(
          downloadedImage.bytes,
          album: _novellaAlbumName,
          name: downloadedImage.fileName,
        );
      } else {
        await Gal.putImage(downloadedImage.filePath, album: _novellaAlbumName);
      }

      _showMessage(messenger, _imageSavedMessage);
    } on GalException catch (error) {
      _showMessage(messenger, _mapGalError(error));
    } catch (_) {
      _showMessage(messenger, _saveImageFailedMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _shareImage(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final box = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;

    setState(() {
      _isSharing = true;
    });

    try {
      final downloadedImage = await _downloadImageToTempFile();

      try {
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile(
                downloadedImage.filePath,
                name: downloadedImage.fileName,
                mimeType: downloadedImage.mimeType,
              ),
            ],
            title: _shareImageTitle,
            sharePositionOrigin: sharePositionOrigin,
          ),
        );
      } on UnimplementedError {
        if (!PlatformInfo.isWindows) {
          rethrow;
        }

        await _shareImageUrlFallback(sharePositionOrigin);
        _showMessage(messenger, _shareWindowsFallbackMessage);
      }
    } catch (_) {
      _showMessage(messenger, _shareImageFailedMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  Future<void> _shareImageUrlFallback(Rect? sharePositionOrigin) async {
    final uri = Uri.tryParse(widget.imageUrl);
    if (uri != null) {
      await SharePlus.instance.share(
        ShareParams(
          uri: uri,
          title: _shareImageTitle,
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
      return;
    }

    await SharePlus.instance.share(
      ShareParams(
        text: widget.imageUrl,
        title: _shareImageTitle,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  Future<_DownloadedImageFile> _downloadImageToTempFile() async {
    final tempDir = await getTemporaryDirectory();
    final uri = Uri.tryParse(widget.imageUrl);
    final response = await Dio().get<List<int>>(
      widget.imageUrl,
      options: Options(
        responseType: ResponseType.bytes,
        headers: const {'Accept': 'image/*'},
      ),
    );
    final responseData = response.data;
    if (responseData == null || responseData.isEmpty) {
      throw StateError('Image download returned empty bytes.');
    }

    final bytes = Uint8List.fromList(responseData);
    final mimeType = _resolveMimeType(
      _resolveImageExtension(
        uri,
        contentType: response.headers.value(Headers.contentTypeHeader),
      ),
    );
    final extension = _resolveImageExtension(
      uri,
      contentType: response.headers.value(Headers.contentTypeHeader),
    );
    final fileName =
        'novella_image_${DateTime.now().microsecondsSinceEpoch}$extension';
    final filePath = p.join(tempDir.path, fileName);

    await File(filePath).writeAsBytes(bytes, flush: true);

    return _DownloadedImageFile(
      filePath: filePath,
      fileName: fileName,
      mimeType: mimeType,
      bytes: bytes,
    );
  }

  String _resolveImageExtension(Uri? uri, {String? contentType}) {
    final extensionFromContentType = _resolveExtensionFromContentType(
      contentType,
    );
    if (extensionFromContentType != null) {
      return extensionFromContentType;
    }

    final rawExtension = uri == null ? '' : p.extension(uri.path);
    if (rawExtension.isEmpty) {
      return '.jpg';
    }

    final normalized = rawExtension.toLowerCase();
    const supportedExtensions = {
      '.jpg',
      '.jpeg',
      '.png',
      '.webp',
      '.gif',
      '.bmp',
      '.heic',
      '.heif',
    };
    return supportedExtensions.contains(normalized) ? normalized : '.jpg';
  }

  String? _resolveExtensionFromContentType(String? contentType) {
    if (contentType == null || contentType.isEmpty) {
      return null;
    }

    final normalized = contentType.split(';').first.trim().toLowerCase();
    switch (normalized) {
      case 'image/png':
        return '.png';
      case 'image/gif':
        return '.gif';
      case 'image/bmp':
        return '.bmp';
      case 'image/webp':
        return '.webp';
      case 'image/heic':
        return '.heic';
      case 'image/heif':
        return '.heif';
      case 'image/jpg':
      case 'image/jpeg':
        return '.jpg';
      default:
        return null;
    }
  }

  String _resolveMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.bmp':
        return 'image/bmp';
      case '.webp':
        return 'image/webp';
      case '.heic':
        return 'image/heic';
      case '.heif':
        return 'image/heif';
      case '.jpg':
      case '.jpeg':
      default:
        return 'image/jpeg';
    }
  }

  String _mapGalError(GalException error) {
    switch (error.type) {
      case GalExceptionType.accessDenied:
        return _galleryAccessDeniedMessage;
      case GalExceptionType.notEnoughSpace:
        return _notEnoughSpaceMessage;
      case GalExceptionType.notSupportedFormat:
        return _unsupportedFormatMessage;
      case GalExceptionType.unexpected:
        return _saveImageFailedMessage;
    }
  }

  void _showMessage(ScaffoldMessengerState? messenger, String message) {
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }
}

class ReaderRoundedNetworkImage extends StatelessWidget {
  final String imageUrl;
  final String? alt;
  final double borderRadius;
  final double? width;
  final double? height;
  final double? maxWidth;
  final BoxFit fit;
  final int memCacheWidth;
  final Color errorColor;
  final bool previewable;
  final bool openPreviewOnLongPress;
  final EdgeInsetsGeometry padding;

  const ReaderRoundedNetworkImage({
    super.key,
    required this.imageUrl,
    required this.errorColor,
    this.alt,
    this.borderRadius = 4,
    this.width,
    this.height,
    this.maxWidth,
    this.fit = BoxFit.contain,
    this.memCacheWidth = 1080,
    this.previewable = true,
    this.openPreviewOnLongPress = false,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = imageUrl.trim();
    if (trimmedUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    Widget child = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      clipBehavior: Clip.antiAlias,
      child: CachedNetworkImage(
        imageUrl: trimmedUrl,
        memCacheWidth: memCacheWidth,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) => _buildError(),
      ),
    );

    if (maxWidth != null) {
      child = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth!),
        child: child,
      );
    }

    if (padding != EdgeInsets.zero) {
      child = Padding(padding: padding, child: child);
    }

    if (previewable) {
      child = ReaderImagePreviewGesture(
        imageUrl: trimmedUrl,
        alt: alt,
        openOnLongPress: openPreviewOnLongPress,
        behavior: HitTestBehavior.opaque,
        child: child,
      );
    }

    return child;
  }

  Widget _buildPlaceholder() {
    final placeholderWidth = _finiteOrNull(width);
    final placeholderHeight = _finiteOrNull(height);
    if (placeholderWidth != null || placeholderHeight != null) {
      return SizedBox(
        width: placeholderWidth ?? 40,
        height: placeholderHeight ?? 40,
        child: const Center(child: M3ELoadingIndicator(size: 16)),
      );
    }
    return const Center(child: M3ELoadingIndicator(size: 20));
  }

  Widget _buildError() {
    final errorWidth = _finiteOrNull(width);
    final errorHeight = _finiteOrNull(height);
    final icon = Icon(
      Icons.broken_image_outlined,
      color: errorColor.withValues(alpha: 0.4),
      size: 28,
    );
    if (errorWidth != null || errorHeight != null) {
      return SizedBox(
        width: errorWidth ?? 40,
        height: errorHeight ?? 40,
        child: Center(child: icon),
      );
    }
    return Center(child: icon);
  }

  double? _finiteOrNull(double? value) {
    if (value == null || !value.isFinite) {
      return null;
    }
    return value;
  }
}

class ReaderImagePreviewGesture extends StatelessWidget {
  final String imageUrl;
  final String? alt;
  final bool openOnLongPress;
  final HitTestBehavior behavior;
  final Widget child;

  const ReaderImagePreviewGesture({
    super.key,
    required this.imageUrl,
    required this.child,
    this.alt,
    this.openOnLongPress = false,
    this.behavior = HitTestBehavior.deferToChild,
  });

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = imageUrl.trim();
    if (trimmedUrl.isEmpty) {
      return child;
    }

    void openPreview() {
      showReaderImagePreview(context, imageUrl: trimmedUrl, alt: alt);
    }

    return GestureDetector(
      behavior: behavior,
      onTap: openOnLongPress ? null : openPreview,
      onLongPress: openOnLongPress ? openPreview : null,
      child: child,
    );
  }
}
