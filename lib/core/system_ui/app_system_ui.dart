import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppSystemUi {
  const AppSystemUi._();

  static const MethodChannel _androidSystemUiChannel = MethodChannel(
    'novella/system_ui',
  );

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
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _androidSystemUiChannel.invokeMethod<void>('restoreDefault', {
        'lightSystemBars': brightness != Brightness.dark,
      });
    }
  }

  static Future<void> applyPagedReader({required bool showSystemStatusBar}) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _androidSystemUiChannel.invokeMethod<void>('applyReader', {
        'showStatusBar': showSystemStatusBar,
      });
    }

    if (showSystemStatusBar) {
      return SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: const [SystemUiOverlay.top],
      );
    }

    return SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
}
