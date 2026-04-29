import 'package:flutter/material.dart';

class AppColorProfiles {
  static const String light = 'light';
  static const String dark = 'dark';
  static const String oledBlack = 'oledBlack';

  static String profileFor({
    required bool isDark,
    required bool oledBlackEnabled,
  }) {
    if (!isDark) return light;
    return oledBlackEnabled ? oledBlack : dark;
  }

  static ColorScheme oledBlackScheme(ColorScheme source) {
    return source.copyWith(
      brightness: Brightness.dark,
      surface: Colors.black,
      surfaceDim: Colors.black,
      surfaceBright: const Color(0xFF141414),
      surfaceContainerLowest: Colors.black,
      surfaceContainerLow: const Color(0xFF050505),
      surfaceContainer: const Color(0xFF0A0A0A),
      surfaceContainerHigh: const Color(0xFF121212),
      surfaceContainerHighest: const Color(0xFF1A1A1A),
      onSurface: const Color(0xFFEFEFEF),
      onSurfaceVariant: const Color(0xFFC7C7C7),
      outline: const Color(0xFF666666),
      outlineVariant: const Color(0xFF252525),
      shadow: Colors.black,
      scrim: Colors.black,
    );
  }

  static Color coverSeedForProfile(Color seedColor, String profile) {
    final hsl = HSLColor.fromColor(seedColor);
    switch (profile) {
      case oledBlack:
        return hsl
            .withLightness((hsl.lightness * 0.22).clamp(0.035, 0.12))
            .withSaturation((hsl.saturation * 0.9).clamp(0.0, 0.9))
            .toColor();
      case dark:
        return hsl
            .withLightness((hsl.lightness * 0.4).clamp(0.05, 0.25))
            .withSaturation((hsl.saturation * 1.1).clamp(0.0, 1.0))
            .toColor();
      default:
        return hsl
            .withLightness((hsl.lightness * 0.8 + 0.3).clamp(0.5, 0.85))
            .withSaturation((hsl.saturation * 0.7).clamp(0.0, 0.8))
            .toColor();
    }
  }

  static List<Color> coverGradientColors(Color seedColor, String profile) {
    final firstColor = coverSeedForProfile(seedColor, profile);
    final targetColor = profile == light ? Colors.white : Colors.black;
    final blendAmount = profile == oledBlack ? 0.72 : 0.4;
    final lastColor = coverSeedForProfile(
      Color.lerp(seedColor, targetColor, blendAmount)!,
      profile,
    );
    final middleColor = Color.lerp(firstColor, lastColor, 0.5)!;

    if (profile == oledBlack) {
      return [
        Color.lerp(firstColor, Colors.black, 0.18)!,
        middleColor,
        Color.lerp(lastColor, Colors.black, 0.35)!,
      ];
    }

    return [firstColor, middleColor, lastColor];
  }

  static ColorScheme colorSchemeFromCoverSeed(
    Color seedColor, {
    required String profile,
  }) {
    final brightness = profile == light ? Brightness.light : Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: coverSeedForProfile(seedColor, profile),
      brightness: brightness,
    );
    return profile == oledBlack ? oledBlackScheme(scheme) : scheme;
  }
}
