import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppSystemUi {
  const AppSystemUi._();

  static SystemUiOverlayStyle defaultOverlayStyle(Brightness brightness) {
    final iconBrightness =
        brightness == Brightness.dark ? Brightness.light : Brightness.dark;

    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: iconBrightness,
      statusBarBrightness: brightness,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: iconBrightness,
      systemNavigationBarContrastEnforced: false,
    );
  }

  static Future<void> restoreDefault(Brightness brightness) async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(defaultOverlayStyle(brightness));
  }

  static Future<void> applyPagedReader({required bool showSystemStatusBar}) {
    if (showSystemStatusBar) {
      return SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: const [SystemUiOverlay.top],
      );
    }

    return SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
}
