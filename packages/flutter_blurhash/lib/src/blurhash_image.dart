import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// BlurHash 解码器签名（宿主注入原生/isolate 实现）。
typedef BlurHashImageDecoder =
    Future<ui.Image> Function(String blurHash, int width, int height);

const _defaultSize = 32;

class BlurHashImage extends ImageProvider<BlurHashImage> {
  /// Creates an object that decodes a [blurHash] as an image.
  ///
  /// The arguments must not be null.
  const BlurHashImage(this.blurHash,
      {this.decodingWidth = _defaultSize,
      this.decodingHeight = _defaultSize,
      this.scale = 1.0});

  /// The bytes to decode into an image.
  final String blurHash;

  /// The scale to place in the [ImageInfo] object of the image.
  final double scale;

  /// 全局解码器。本库不再自带 Dart 解码实现，解码完全由宿主注入的原生
  /// （Rust/FRB worker 线程）实现完成——把解码移出 Dart UI isolate。
  /// 使用前必须由宿主设置（见 App 启动时的 RustLib 初始化）。
  static BlurHashImageDecoder? decoder;

  /// Decoding definition
  final int decodingWidth;

  /// Decoding definition
  final int decodingHeight;

  @override
  Future<BlurHashImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<BlurHashImage>(this);

  @override
  ImageStreamCompleter loadImage(
          BlurHashImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(_loadAsync(key));

  Future<ImageInfo> _loadAsync(BlurHashImage key) async {
    assert(key == this);

    final decoder = BlurHashImage.decoder;
    if (decoder == null) {
      throw StateError(
        'BlurHashImage.decoder is not set. The Dart decoder has been removed; '
        'a native decoder must be injected at startup.',
      );
    }
    final image = await decoder(blurHash, decodingWidth, decodingHeight);
    return ImageInfo(image: image, scale: key.scale);
  }

  @override
  bool operator ==(Object other) => other.runtimeType != runtimeType
      ? false
      : other is BlurHashImage &&
          other.blurHash == blurHash &&
          other.decodingWidth == decodingWidth &&
          other.decodingHeight == decodingHeight &&
          other.scale == scale;

  @override
  int get hashCode =>
      Object.hash(blurHash, decodingWidth, decodingHeight, scale);

  @override
  String toString() =>
      '$runtimeType($blurHash, ${decodingWidth}x$decodingHeight, scale: $scale)';
}
