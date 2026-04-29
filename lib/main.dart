import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show File, Platform;

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:novella/core/sync/sync_manager.dart';
import 'package:novella/core/logging/log_buffer_service.dart';
import 'package:novella/core/auth/auth_service.dart';
import 'package:novella/core/network/signalr_service.dart';
import 'package:novella/core/storage/secret_storage_service.dart';
import 'package:novella/core/widgets/m3e_loading_indicator.dart';
import 'package:novella/features/auth/login_page.dart';
import 'package:novella/features/settings/settings_page.dart';
import 'package:novella/src/rust/frb_generated.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// 全局导航观察者，用于页面返回时触发刷新
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

/// System UI 调试与签名去重（仅在 debug 下输出）
class _SystemUiDebug {
  static String? _lastSig;

  static void logOverlayStyle(
    SystemUiOverlayStyle style, {
    required String source,
  }) {
    final sig = <String>[
      'src=$source',
      'statusColor=${style.statusBarColor}',
      'statusIcon=${style.statusBarIconBrightness}',
      'navColor=${style.systemNavigationBarColor}',
      'navDivider=${style.systemNavigationBarDividerColor}',
      'navIcon=${style.systemNavigationBarIconBrightness}',
      'navContrast=${style.systemNavigationBarContrastEnforced}',
    ].join(';');

    if (sig == _lastSig) return;
    _lastSig = sig;
    developer.log(sig, name: 'SYSTEM_UI');
  }
}

String _macOSRustLibraryPath() {
  final executableDir = File(Platform.resolvedExecutable).parent.uri;
  return executableDir
      .resolve('../Frameworks/libnovella_native.dylib')
      .toFilePath();
}

// === 加载 Native 库 ===
// iOS: 静态链接 (process)
// macOS/Windows/Android/Linux: 动态库 (open)
ExternalLibrary _loadLibrary() {
  if (Platform.isIOS) {
    return ExternalLibrary.process(iKnowHowToUseIt: true);
  } else if (Platform.isMacOS) {
    return ExternalLibrary.open(_macOSRustLibraryPath());
  } else if (Platform.isWindows) {
    return ExternalLibrary.open('novella_native.dll');
  } else {
    return ExternalLibrary.open('libnovella_native.so');
  }
}

// === RustLib 全局状态 ===
bool rustLibInitialized = false;
String? rustLibInitError;
const double _macOSTitleBarFallbackInset = 28;
double _initialDesktopWindowTopInset = 0;

int? _parseAppleMajorVersion(String version) {
  final versionMatch = RegExp(r'Version\s+(\d+)').firstMatch(version);
  if (versionMatch != null) {
    return int.tryParse(versionMatch.group(1)!);
  }

  final firstNumber = RegExp(r'\d+').firstMatch(version);
  if (firstNumber == null) {
    return null;
  }
  return int.tryParse(firstNumber.group(0)!);
}

bool get _isIOS26OrLater {
  if (!Platform.isIOS) {
    return false;
  }

  final majorVersion = _parseAppleMajorVersion(Platform.operatingSystemVersion);
  return majorVersion != null && majorVersion >= 26;
}

class _IOS26HomeIndicatorMediaQuery extends StatelessWidget {
  const _IOS26HomeIndicatorMediaQuery({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!_isIOS26OrLater) {
      return child;
    }

    final mediaQuery = MediaQuery.of(context);
    if (mediaQuery.padding.bottom == 0 && mediaQuery.viewPadding.bottom == 0) {
      return child;
    }

    return MediaQuery(
      data: mediaQuery.copyWith(
        padding: mediaQuery.padding.copyWith(bottom: 0),
        viewPadding: mediaQuery.viewPadding.copyWith(bottom: 0),
      ),
      child: child,
    );
  }
}

class _DesktopWindowTopInset extends StatefulWidget {
  const _DesktopWindowTopInset({required this.child});

  final Widget child;

  @override
  State<_DesktopWindowTopInset> createState() => _DesktopWindowTopInsetState();
}

class _DesktopWindowTopInsetState extends State<_DesktopWindowTopInset>
    with WindowListener {
  double _topInset = _initialDesktopWindowTopInset;

  bool get _isEnabled => Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    if (_isEnabled) {
      windowManager.addListener(this);
      unawaited(_refreshTopInset());
    }
  }

  @override
  void dispose() {
    if (_isEnabled) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  Future<void> _refreshTopInset() async {
    if (!_isEnabled) return;

    try {
      final isFullScreen = await windowManager.isFullScreen();
      final titleBarHeight =
          isFullScreen
              ? 0.0
              : (await windowManager.getTitleBarHeight()).toDouble();
      final resolvedInset =
          isFullScreen
              ? 0.0
              : (titleBarHeight > 0
                  ? titleBarHeight
                  : _macOSTitleBarFallbackInset);

      if (!mounted || resolvedInset == _topInset) return;
      setState(() {
        _topInset = resolvedInset;
      });
    } catch (e, stack) {
      developer.log(
        'Failed to refresh macOS title bar inset: $e',
        name: 'Flutter',
      );
      developer.log('$stack', name: 'Flutter');
      if (!mounted || _topInset == _macOSTitleBarFallbackInset) return;
      setState(() {
        _topInset = _macOSTitleBarFallbackInset;
      });
    }
  }

  @override
  void onWindowMaximize() {
    unawaited(_refreshTopInset());
  }

  @override
  void onWindowUnmaximize() {
    unawaited(_refreshTopInset());
  }

  @override
  void onWindowRestore() {
    unawaited(_refreshTopInset());
  }

  @override
  void onWindowResized() {
    unawaited(_refreshTopInset());
  }

  @override
  void onWindowEnterFullScreen() {
    unawaited(_refreshTopInset());
  }

  @override
  void onWindowLeaveFullScreen() {
    unawaited(_refreshTopInset());
  }

  @override
  Widget build(BuildContext context) {
    if (!_isEnabled || _topInset <= 0) {
      return widget.child;
    }

    final mediaQuery = MediaQuery.of(context);
    final topPadding =
        mediaQuery.padding.top > _topInset ? mediaQuery.padding.top : _topInset;
    final topViewPadding =
        mediaQuery.viewPadding.top > _topInset
            ? mediaQuery.viewPadding.top
            : _topInset;

    return MediaQuery(
      data: mediaQuery.copyWith(
        padding: EdgeInsets.fromLTRB(
          mediaQuery.padding.left,
          topPadding,
          mediaQuery.padding.right,
          mediaQuery.padding.bottom,
        ),
        viewPadding: EdgeInsets.fromLTRB(
          mediaQuery.viewPadding.left,
          topViewPadding,
          mediaQuery.viewPadding.right,
          mediaQuery.viewPadding.bottom,
        ),
      ),
      child: widget.child,
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 配置边到边显示（Android 小白条沉浸）
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  assert(() {
    _SystemUiDebug.logOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
      source: 'main()',
    );
    return true;
  }());

  // 初始化日志缓冲服务（尽早启动以捕获所有日志）
  LogBufferService.init();

  developer.log('WidgetsInitialized', name: 'Flutter');
  developer.log(
    'Platform.isIOS=${Platform.isIOS}, Platform.isMacOS=${Platform.isMacOS}',
    name: 'Flutter',
  );

  try {
    // 初始化 Rust FFI (字体转换)
    developer.log('Initializing RustLib...', name: 'Flutter');

    // 手动加载库
    await RustLib.init(externalLibrary: _loadLibrary());

    rustLibInitialized = true;
    developer.log('RustLib Initialized Successfully!', name: 'Flutter');
  } catch (e, stack) {
    rustLibInitialized = false;
    rustLibInitError = e.toString();
    developer.log('*** FAILED to initialize RustLib: $e', name: 'Flutter');
    developer.log('Stack trace: $stack', name: 'Flutter');
  }

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    try {
      developer.log('Initializing WindowManager...', name: 'Flutter');
      await windowManager.ensureInitialized();
      developer.log('WindowManager Initialized', name: 'Flutter');

      final WindowOptions windowOptions = WindowOptions(
        size: const Size(1180, 860),
        minimumSize: const Size(420, 760),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle:
            Platform.isMacOS ? TitleBarStyle.hidden : TitleBarStyle.normal,
        title: 'Novella',
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        developer.log('Window Ready to Show', name: 'Flutter');
        if (Platform.isMacOS) {
          final titleBarHeight =
              (await windowManager.getTitleBarHeight()).toDouble();
          _initialDesktopWindowTopInset =
              titleBarHeight > 0 ? titleBarHeight : _macOSTitleBarFallbackInset;
        }
        await windowManager.show();
        await windowManager.focus();
        developer.log('Window Should be Visible', name: 'Flutter');
      });
    } catch (e, stack) {
      developer.log('Failed to initialize WindowManager: $e', name: 'Flutter');
      developer.log('$stack', name: 'Flutter');
    }
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  bool _agreed = false;
  bool _loading = true;

  // 在顶层创建一次 Auth/SignalR 实例：
  // 1) 早注入 tokenProvider；
  // 2) 便于在 app resumed 时做预热 refresh + 重连。
  final AuthService _authService = AuthService();
  final SignalRService _signalRService = SignalRService();
  final SecretStorageService _secretStorage = SecretStorageService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkDisclaimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    developer.log('AppLifecycleState=$state', name: 'LIFECYCLE');

    // iOS 上锁屏/后台后，SignalR/WebSocket 常被系统挂起或断开，但连接状态可能不可靠。
    // 策略：退后台主动 stop，回前台预热 refresh_token -> session token，并重建 SignalR。
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(
        _signalRService.stop().catchError((e) {
          developer.log('SignalR stop error: $e', name: 'LIFECYCLE');
        }),
      );
      return;
    }

    if (state == AppLifecycleState.resumed) {
      unawaited(_prewarmAuthAndSignalR());
    }
  }

  Future<void> _prewarmAuthAndSignalR() async {
    // 阻塞用户触发的网络操作，直到预热完成
    _signalRService.beginForegroundRecovery();
    try {
      final refreshToken = await _secretStorage.read(
        SecretStorageKeys.refreshToken,
      );
      if (refreshToken == null || refreshToken.isEmpty) {
        developer.log('No refresh_token, skip prewarm', name: 'LIFECYCLE');
        return;
      }

      // 给系统一点时间恢复网络栈（iOS 切回前台瞬间常出现首个请求失败）
      await Future.delayed(const Duration(milliseconds: 300));

      // 按需求：检查 expireTime，若已过期或即将过期则阻塞并立刻刷新。
      // 这里使用 JWT exp（若可解析）或本地 TTL 作为近似。
      final expireAt = _authService.sessionTokenExpireTime;
      developer.log('Token expireAt=$expireAt', name: 'LIFECYCLE');

      final newToken = await _authService.ensureFreshSessionToken();
      developer.log(
        'Prewarm ensureFreshSessionToken ok=${newToken.isNotEmpty}',
        name: 'LIFECYCLE',
      );

      await _signalRService.init();
      developer.log('Prewarm SignalR init done', name: 'LIFECYCLE');
    } catch (e) {
      developer.log('Prewarm failed: $e', name: 'LIFECYCLE');
    } finally {
      _signalRService.endForegroundRecovery();
    }
  }

  Future<void> _checkDisclaimer() async {
    // 1. 并行加载核心数据与连接 Gist
    final results = await Future.wait([
      SharedPreferences.getInstance(),
      SyncManager().init(),
    ]);

    final prefs = results[0] as SharedPreferences;
    final agreed = prefs.getBool('disclaimer_agreed') ?? false;

    // 2. 如果 Gist 已连接，异步触发同步，不阻塞 UI 渲染
    final syncManager = SyncManager();
    if (syncManager.isConnected) {
      // 在微任务中触发，确保 setState 立即执行
      Future.microtask(() => syncManager.triggerSync(immediate: true));
    }

    if (mounted) {
      setState(() {
        _agreed = agreed;
        _loading = false;
      });
    }
  }

  Future<void> _agree() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('disclaimer_agreed', true);
    setState(() {
      _agreed = true;
    });
  }

  ThemeMode _getThemeMode(String theme) {
    switch (theme) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final appUiFontAsync = ref.watch(appUiFontFamilyProvider);
    final appUiFontFamily =
        appUiFontAsync.asData?.value ??
        (Platform.isWindows ? 'Microsoft YaHei' : null);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme lightScheme;
        ColorScheme darkScheme;

        if (settings.useSystemColor &&
            lightDynamic != null &&
            darkDynamic != null) {
          // 仅使用系统主色作为 seed，再本地生成完整 ColorScheme，
          // 让 secondary / tertiary / neutral 的表现更稳定。
          lightScheme = ColorScheme.fromSeed(
            seedColor: lightDynamic.primary,
            brightness: Brightness.light,
          );
          darkScheme = ColorScheme.fromSeed(
            seedColor: darkDynamic.primary,
            brightness: Brightness.dark,
          );
        } else {
          // 使用自定义种子色或回退逻辑
          final seedColor = Color(settings.seedColorValue);
          final variantIndex = settings.dynamicSchemeVariant;
          final variant =
              variantIndex >= 0 &&
                      variantIndex < DynamicSchemeVariant.values.length
                  ? DynamicSchemeVariant.values[variantIndex]
                  : DynamicSchemeVariant.tonalSpot;

          lightScheme = ColorScheme.fromSeed(
            seedColor: seedColor,
            brightness: Brightness.light,
            dynamicSchemeVariant: variant,
          );
          darkScheme = ColorScheme.fromSeed(
            seedColor: seedColor,
            brightness: Brightness.dark,
            dynamicSchemeVariant: variant,
          );
        }

        // 应用 OLED 黑优化
        if (settings.oledBlack) {
          darkScheme = darkScheme.copyWith(
            surface: Colors.black,
            surfaceContainer: const Color(0xFF121212),
            surfaceContainerHigh: const Color(0xFF1E1E1E),
          );
        }

        return MaterialApp(
          title: 'Novella',
          debugShowCheckedModeBanner: false,
          // 全局兜底：确保无 AppBar/无 AnnotatedRegion 的页面也能持续下发透明导航栏样式。
          // 解决“二次启动自动登录 loading -> 主页首次不沉浸；进详情页后恢复并沿用”的样式被覆盖问题。
          builder: (context, child) {
            final brightness = Theme.of(context).brightness;
            final systemIconsBrightness =
                brightness == Brightness.dark
                    ? Brightness.light
                    : Brightness.dark;

            final style = SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: systemIconsBrightness,
              // iOS 会用到；Android 可忽略，但设置不会有副作用。
              statusBarBrightness: brightness,

              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarDividerColor: Colors.transparent,
              systemNavigationBarIconBrightness: systemIconsBrightness,
              systemNavigationBarContrastEnforced: false,
            );

            assert(() {
              _SystemUiDebug.logOverlayStyle(
                style,
                source: 'MaterialApp.builder',
              );
              return true;
            }());

            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: style,
              child: _IOS26HomeIndicatorMediaQuery(
                child: _DesktopWindowTopInset(
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            );
          },
          // 本地化配置（含简体/繁体中文支持）
          localizationsDelegates: const [
            FlutterQuillLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('zh', 'CN'), // 简体中文
            Locale('zh', 'TW'), // 繁体中文
            Locale('en', ''), // English
          ],
          theme: ThemeData(
            fontFamily: appUiFontFamily,
            colorScheme: lightScheme,
            useMaterial3: true,
            textTheme: const TextTheme(
              displayLarge: TextStyle(letterSpacing: -1.0),
              displayMedium: TextStyle(letterSpacing: -0.5),
            ),
            appBarTheme: const AppBarTheme(
              systemOverlayStyle: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarDividerColor: Colors.transparent,
                systemNavigationBarContrastEnforced: false,
              ),
            ),
          ),
          darkTheme: ThemeData(
            fontFamily: appUiFontFamily,
            colorScheme: darkScheme,
            scaffoldBackgroundColor: settings.oledBlack ? Colors.black : null,
            useMaterial3: true,
            appBarTheme: const AppBarTheme(
              systemOverlayStyle: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarDividerColor: Colors.transparent,
                systemNavigationBarContrastEnforced: false,
              ),
            ),
          ),
          themeMode: _getThemeMode(settings.theme),
          navigatorObservers: [routeObserver],
          home:
              _loading
                  ? const Scaffold(body: Center(child: M3ELoadingIndicator()))
                  : _agreed
                  ? const LoginPage()
                  : DisclaimerPage(onAgree: _agree),
        );
      },
    );
  }
}

class DisclaimerPage extends StatelessWidget {
  final VoidCallback onAgree;

  const DisclaimerPage({super.key, required this.onAgree});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('使用须知')),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 64,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '免责声明',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '本软件仅供学习交流。请勿高频操作，风险自负。',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: onAgree,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                    child: const Text('同意并继续'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
