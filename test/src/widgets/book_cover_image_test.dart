import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novella/src/widgets/book_cover_image.dart';

void main() {
  // Dart 解码已从 flutter_blurhash 移除；生产由 Rust 注入。测试注入桩解码器。
  setUpAll(() {
    BlurHashImage.decoder = (blurHash, width, height) {
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        Uint8List(width * height * 4),
        width,
        height,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );
      return completer.future;
    };
  });

  testWidgets('uses the image cache for BlurHash placeholders', (tester) async {
    const blurHash = 'LEHV6nWB2yk8pyo0adR*.7kCMdnj';
    final imageUrl = Uri.https('example.com', '/cover.jpg', {
      'placeholder': blurHash,
    }).toString();

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 120,
          height: 180,
          child: BookCoverImage(
            imageUrl: imageUrl,
            resolveNetworkImage: false,
            showLoading: false,
          ),
        ),
      ),
    );

    final placeholder = tester.widget<Image>(find.byType(Image));
    expect(placeholder.image, isA<BlurHashImage>());

    const equivalentProvider = BlurHashImage(
      blurHash,
      decodingWidth: 32,
      decodingHeight: 48,
    );
    final cacheStatus = PaintingBinding.instance.imageCache.statusForKey(
      equivalentProvider,
    );
    expect(
      cacheStatus.pending || cacheStatus.live || cacheStatus.keepAlive,
      isTrue,
    );
  });

  test('cache key includes decoding dimensions', () {
    const hash = 'LEHV6nWB2yk8pyo0adR*.7kCMdnj';
    const first = BlurHashImage(hash, decodingWidth: 32, decodingHeight: 48);
    const same = BlurHashImage(hash, decodingWidth: 32, decodingHeight: 48);
    const differentSize = BlurHashImage(
      hash,
      decodingWidth: 64,
      decodingHeight: 96,
    );

    expect(first, same);
    expect(first.hashCode, same.hashCode);
    expect(first, isNot(differentSize));
  });
}
