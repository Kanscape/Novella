import 'dart:developer' as developer;
import 'package:logging/logging.dart';
import 'package:novella/core/network/signalr_service.dart';

class ChapterContent {
  final int id;
  final String title;
  final String content;
  final String? fontUrl;
  final int sortNum;
  // 服务端提供的阅读位置
  final String? serverPosition;

  ChapterContent({
    required this.id,
    required this.title,
    required this.content,
    this.fontUrl,
    required this.sortNum,
    this.serverPosition,
  });

  factory ChapterContent.fromJson(
    Map<dynamic, dynamic> json, {
    String? position,
  }) {
    return ChapterContent(
      id: json['Id'] as int? ?? 0,
      title: json['Title'] as String? ?? 'Unknown Chapter',
      content: json['Content'] as String? ?? '',
      fontUrl: json['Font'] as String?,
      sortNum: json['SortNum'] as int? ?? 0,
      serverPosition: position,
    );
  }
}

class ChapterService {
  static final Logger _logger = Logger('ChapterService');

  /// 是否启用“零宽空格注入”。
  ///
  /// 用途：强制 Flutter 在任意位置断行。
  /// 备注：当前用于排查“字与字之间莫名其妙出现空隙”的问题，先临时禁用。
  static const bool _kEnableZeroWidthSpaceInjection = false;

  final SignalRService _signalRService = SignalRService();

  /// 获取章节内容
  /// 参考 services/chapter/index.ts
  Future<ChapterContent> getNovelContent(
    int bid,
    int sortNum, {
    String? convert,
  }) async {
    try {
      // Web 参考包含 UseGzip
      final result = await _signalRService.invoke<Map<dynamic, dynamic>>(
        'GetNovelContent',
        args: [
          {
            'Bid': bid,
            'SortNum': sortNum,
            if (convert != null) 'Convert': convert,
          },
          // 选项
          {'UseGzip': true},
        ],
      );

      // 调试：打印原始章节数据
      developer.log(
        'Raw result keys: ${result.keys.toList()}',
        name: 'CHAPTER',
      );
      if (result['Chapter'] != null) {
        final chapterJson = result['Chapter'];
        developer.log(
          'Chapter keys: ${chapterJson.keys.toList()}',
          name: 'CHAPTER',
        );
        developer.log('Font value: ${chapterJson['Font']}', name: 'CHAPTER');

        // 提取阅读位置
        String? position;
        final readPos = result['ReadPosition'];
        if (readPos != null && readPos is Map) {
          position = readPos['Position'] as String?;
          developer.log(
            'ReadPosition: ChapterId=${readPos['ChapterId']}, Position=$position',
            name: 'CHAPTER',
          );
        }

        // 处理内容：必要时注入零宽空格以解决换行问题
        String content = chapterJson['Content'] as String? ?? '';
        if (_kEnableZeroWidthSpaceInjection && content.isNotEmpty) {
          content = _injectZeroWidthSpace(content);
          // 更新 JSON 中的 Content
          chapterJson['Content'] = content;
        }

        return ChapterContent.fromJson(chapterJson, position: position);
      }
      throw Exception('Chapter not found in response');
    } catch (e) {
      _logger.severe('Failed to get novel content: $e');
      rethrow;
    }
  }

  // 欺骗 Flutter 渲染引擎允许在任意位置断行
  String _injectZeroWidthSpace(String htmlContent) {
    return htmlContent.replaceAllMapped(RegExp(r'(>)([^<]+)(<)'), (match) {
      final prefix = match.group(1)!; // >
      final text = match.group(2)!; // Content
      final suffix = match.group(3)!; // <
      // 在所有非空白字符后插入 \u200B
      final newText = text.split('').join('\u200B');
      return '$prefix$newText$suffix';
    });
  }
}
