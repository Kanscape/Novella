import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:signalr_netcore/ihub_protocol.dart';

const backendHost = 'api.lightnovel.life';

class BackendUserAgent {
  static String? _cachedValue;

  static Future<String> get value async {
    if (_cachedValue != null) {
      return _cachedValue!;
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final appName = packageInfo.appName.trim();
    final normalizedAppName =
        appName.isEmpty ? 'Novella' : appName.replaceAll(RegExp(r'\s+'), '-');
    final version = packageInfo.version.trim();

    _cachedValue =
        version.isEmpty ? normalizedAppName : '$normalizedAppName/$version';
    return _cachedValue!;
  }

  static void attachToDio(Dio dio) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (_shouldAttach(options.uri)) {
            options.headers['User-Agent'] = await value;
          }
          handler.next(options);
        },
      ),
    );
  }

  static Future<MessageHeaders> signalRHeaders() async {
    final headers = MessageHeaders();
    headers.setHeaderValue('User-Agent', await value);
    return headers;
  }

  static bool _shouldAttach(Uri uri) {
    return uri.host.isEmpty || uri.host == backendHost;
  }
}
