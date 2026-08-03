# NativeBlurHash intentionally invokes expo-image's bundled decoder with its
# cosine cache disabled. Keep this SDK-pinned implementation reachable in
# minified release builds.
-keep class expo.modules.image.blurhash.BlurhashDecoder { *; }
