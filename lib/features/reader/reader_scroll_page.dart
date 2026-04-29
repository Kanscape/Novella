import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novella/core/utils/cover_url_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:logging/logging.dart';
import 'package:novella/core/utils/font_manager.dart';
import 'package:novella/core/utils/time_utils.dart';
import 'package:novella/data/services/chapter_service.dart';
import 'package:novella/data/services/reading_progress_service.dart';
import 'package:novella/data/services/reading_time_service.dart';
import 'package:novella/data/services/book_service.dart';
import 'package:novella/features/settings/settings_page.dart';
import 'package:novella/features/book/book_detail_page.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:novella/features/reader/reader_background_page.dart';
import 'package:novella/features/reader/shared/reader_battery_indicator.dart';
import 'package:novella/features/reader/shared/reader_chapter_sheet.dart';
import 'package:novella/features/reader/shared/reader_image_view.dart';
import 'package:novella/features/reader/shared/reader_text_sanitizer.dart';
import 'package:novella/features/reader/shared/reader_title_sheet.dart';
import 'package:novella/features/reader/shared/reader_title_utils.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:novella/core/widgets/m3e_loading_indicator.dart';
import 'package:novella/core/widgets/universal_glass_panel.dart';
import 'package:novella/core/utils/xpath_utils.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

enum _ReaderLayoutMode { standard, immersive, center }

enum _ReaderChapterOpenPosition { saved, start, end }

class _FootnoteProcessingResult {
  final String html;
  final Map<String, String> notesById;

  const _FootnoteProcessingResult({
    required this.html,
    required this.notesById,
  });
}

class _ReaderLayoutInfo {
  final _ReaderLayoutMode mode;
  final bool startsWithImage;
  final bool endsWithImage;

  const _ReaderLayoutInfo(
    this.mode, {
    this.startsWithImage = false,
    this.endsWithImage = false,
  });
}

class _ReaderBlock {
  /// 用于渲染的 HTML（通常为某个块级节点的 outerHtml，必要时带 wrapper）。
  final String html;

  /// 该 block 对应的“逻辑定位”XPath（保留 `//*/` 前缀，便于与服务端协议一致）。
  final String xPath;

  /// 清洗后的 XPath（去掉根前缀），便于匹配与索引。
  final String cleanXPath;

  /// 该 block 的纯文本长度（剔除 \u200B 等注入字符）。
  final int textLength;

  /// block 内图片数量（用于加权进度）。
  final int imageCount;

  /// block 权重（用于加权进度）。
  final double weight;

  const _ReaderBlock({
    required this.html,
    required this.xPath,
    required this.cleanXPath,
    required this.textLength,
    required this.imageCount,
    required this.weight,
  });
}

class _ReaderBlocksBuildResult {
  final List<_ReaderBlock> blocks;
  final Map<String, int> indexByCleanXPath;
  final List<double> prefixWeights;
  final double totalWeight;

  const _ReaderBlocksBuildResult({
    required this.blocks,
    required this.indexByCleanXPath,
    required this.prefixWeights,
    required this.totalWeight,
  });
}

// Route B：阅读定位改为基于 block 虚拟化（ScrollablePositionedList + ItemPositionsListener）。
// 原先的 _XPathWidgetFactory + VisibilityDetector（对每个节点包裹）在长章下会产生巨量 detector，
// 导致滚动期间回调密集与额外的 build/layout 压力，因此移除。

class ReaderScrollPage extends ConsumerStatefulWidget {
  final int bid;
  final int sortNum;
  final int totalChapters;
  final String? coverUrl; // 封面 URL（用于动态取色）
  final String? bookTitle; // 新增：书籍标题
  // 是否允许在“进入阅读器”这一刻用服务端进度覆盖章节号并重定向。
  // 仅适用于继续阅读/恢复阅读等场景；用户从详情页主动点选章节进入时必须为 false。
  final bool allowServerOverrideOnOpen;

  const ReaderScrollPage({
    super.key,
    required this.bid,
    required this.sortNum,
    required this.totalChapters,
    this.coverUrl,
    this.bookTitle,
    this.allowServerOverrideOnOpen = false,
  });

  @override
  ConsumerState<ReaderScrollPage> createState() => _ReaderScrollPageState();
}

class _ReaderScrollPageState extends ConsumerState<ReaderScrollPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _logger = Logger('ReaderPage');
  final _chapterService = ChapterService();
  final _bookService = BookService();
  final _fontManager = FontManager();
  final _progressService = ReadingProgressService();
  final _readingTimeService = ReadingTimeService();
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  late AnimationController _barsAnimController;

  ChapterContent? _chapter;
  String? _fontFamily;
  bool _loading = true;
  String? _error;
  bool _initialScrollDone = false;
  bool _barsVisible = true;

  // 物理滚动边界检测：首次达到最大/最小范围时拉出菜单栏
  bool _atTopEdge = true; // 默认由于尚未加载或处于章节开头，先算作处于顶部，避免一进来就触发
  bool _atBottomEdge = false;

  // 基于封面的动态配色
  ColorScheme? _dynamicColorScheme;

  // 滚动保存防抖计时器
  Timer? _savePositionTimer;

  // ========== 逻辑进度（Route B） ==========
  // 逻辑进度 0..1（加权，避免依赖像素滚动）
  final ValueNotifier<double> _readProgressNotifier = ValueNotifier<double>(
    0.0,
  );

  // 当前顶端可见 block index
  int _topVisibleBlockIndex = 0;

  // 当前顶端可见 block 的 XPath（保留 //*/ 前缀，用于同步/恢复）
  String _lastTopVisibleXPath = '//*';

  // 本章 blocks 缓存（虚拟化渲染 + 逻辑进度）
  _ReaderBlocksBuildResult? _blocksResult;

  // 布局信息缓存（避免 build 期间反复 parse）
  _ReaderLayoutInfo _layoutInfo = const _ReaderLayoutInfo(
    _ReaderLayoutMode.standard,
  );

  // 图片宽高比缓存，key: srcUrl, value: 宽高比 (width/height)
  // 用于懒加载中维持插画的绝对原比例高度占位
  final Map<String, double> _imageAspectRatioCache = {};

  // 图片懒加载记录：记录某个 url 是否曾经进入过视口
  final Set<String> _shownImages = {};
  final Map<String, String> _indentedBlockHtmlCache = {};

  SharedPreferences? _prefs;

  // 脚注/注释内容映射：id -> innerHtml
  Map<String, String> _footnoteNotesById = const {};

  // ColorScheme 静态缓存
  static final Map<String, ColorScheme> _schemeCache = {};

  // 顶部信息栏状态（使用 ValueNotifier 隔离定时刷新，避免整页 setState 触发正文重建）
  final Battery _battery = Battery();
  final ValueNotifier<int> _batteryLevelNotifier = ValueNotifier<int>(100);
  final ValueNotifier<BatteryState> _batteryStateNotifier =
      ValueNotifier<BatteryState>(BatteryState.unknown);
  final ValueNotifier<String> _timeStringNotifier = ValueNotifier<String>('');
  Timer? _infoTimer;
  StreamSubscription<BatteryState>? _batteryStateSubscription;

  // 章节加载版本号（用于打断旧请求）
  int _loadVersion = 0;
  // 目标章节号（用于连续点击时追踪最终目标）
  late int _targetSortNum;

  // Route B 采用 ScrollablePositionedList，不再需要 visibility_detector。

  bool _exitInProgress = false;
  double? _stableAndroidBottomPadding;

  /// 退出阅读器前保存进度。
  ///
  /// 目标：保证“本地 read_pos_*”已落盘，避免返回详情页/立刻再次进入时读到旧值；
  /// 服务端回传（SaveReadPosition）不阻塞退出。
  Future<void> _saveProgressForExit() async {
    if (_exitInProgress) return;
    _exitInProgress = true;

    final chapter = _chapter;
    if (chapter == null || _blocksResult == null) return;

    final currentXPath = _getTopVisibleXPath();

    // 1) 本地必须先落盘（await）
    await _progressService.saveLocalPosition(
      bookId: widget.bid,
      chapterId: chapter.id,
      sortNum: chapter.sortNum,
      xPath: currentXPath,
      title: widget.bookTitle,
      cover: widget.coverUrl,
      chapterTitle: chapter.title,
      immediate: true, // 退出时尽量立即触发同步（若启用）
    );

    // 2) 服务端回传不阻塞 UI
    // ignore: unawaited_futures
    _progressService.saveReadPosition(
      bookId: widget.bid,
      chapterId: chapter.id,
      xPath: currentXPath,
    );
  }

  Future<void> _exitReaderPage() async {
    // 避免用户连点返回导致“未等待本地落盘”就 pop
    if (_exitInProgress) return;
    await _saveProgressForExit();
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<bool> _onWillPop() async {
    await _saveProgressForExit();
    return true;
  }

  /// 获取当前阅读背景色
  Color _getReaderBackgroundColor(AppSettings settings) {
    if (settings.readerUseThemeBackground) {
      // 使用主题色
      return (_dynamicColorScheme ?? Theme.of(context).colorScheme).surface;
    }
    if (settings.readerUseCustomColor) {
      // 自定义颜色
      return Color(settings.readerBackgroundColor);
    }
    // 预设颜色
    return kReaderPresets[settings.readerPresetIndex.clamp(
          0,
          kReaderPresets.length - 1,
        )]
        .backgroundColor;
  }

  String _getTopVisibleXPath() {
    return _lastTopVisibleXPath;
  }

  /// 获取当前阅读文字色
  Color _getReaderTextColor(AppSettings settings) {
    if (settings.readerUseThemeBackground) {
      // 使用主题色
      return (_dynamicColorScheme ?? Theme.of(context).colorScheme).onSurface;
    }
    if (settings.readerUseCustomColor) {
      // 自定义颜色
      return Color(settings.readerTextColor);
    }
    // 预设颜色
    return kReaderPresets[settings.readerPresetIndex.clamp(
          0,
          kReaderPresets.length - 1,
        )]
        .textColor;
  }

  // ==================== Route B：block 构建/定位/进度 ====================

  String _getRenderedBlockHtml(_ReaderBlock block, AppSettings settings) {
    if (!settings.readerFirstLineIndent) {
      return block.html;
    }

    final cacheKey = '${_chapter?.id ?? 0}:${block.xPath}';
    return _indentedBlockHtmlCache.putIfAbsent(
      cacheKey,
      () => _applyFirstLineIndent(block.html),
    );
  }

  String _applyFirstLineIndent(String html) {
    if (html.isEmpty) {
      return html;
    }

    try {
      final fragment = html_parser.parseFragment(html);
      if (fragment.nodes.isEmpty) {
        return html;
      }

      final root = fragment.nodes.firstWhere(
        (node) => node is dom.Element,
        orElse: () => fragment.nodes.first,
      );
      if (root is! dom.Element || !_canApplyFirstLineIndent(root)) {
        return html;
      }

      final firstTextNode = _findFirstIndentableTextNode(root);
      if (firstTextNode == null) {
        return html;
      }

      firstTextNode.text = _prependFirstLineIndent(firstTextNode.text);
      return _serializeFragmentNodes(fragment.nodes);
    } catch (_) {
      return html;
    }
  }

  String _serializeFragmentNodes(List<dom.Node> nodes) {
    final buffer = StringBuffer();
    for (final node in nodes) {
      if (node is dom.Element) {
        buffer.write(node.outerHtml);
      } else if (node is dom.Text) {
        buffer.write(node.text);
      }
    }
    return buffer.toString();
  }

  String _stripInvisiblePlaceholderCodepoints(
    String html,
    Set<int> invisibleCodepoints,
  ) {
    return sanitizeReaderHtmlTextNodes(html, invisibleCodepoints);
  }

  String _normalizeReaderText(String text) {
    return normalizeReaderText(text);
  }

  bool _shouldPreserveExplicitBlankLine(dom.Element element) {
    final hasText = _normalizeReaderText(element.text).isNotEmpty;
    if (hasText) {
      return false;
    }

    final hasImage = element.getElementsByTagName('img').isNotEmpty;
    if (hasImage) {
      return false;
    }

    return element.getElementsByTagName('br').isNotEmpty;
  }

  static const Set<String> _kNoFirstLineIndentClasses = {
    'author',
    'center',
    'cut-line',
    'left',
    'meg',
    'message',
    'right',
    'zin',
  };

  bool _canApplyFirstLineIndent(dom.Element element) {
    const indentableTags = {'p', 'div', 'blockquote'};
    if (!indentableTags.contains(element.localName)) {
      return false;
    }
    if (element.getElementsByTagName('img').isNotEmpty) {
      return false;
    }

    final rawText = _normalizeReaderText(element.text);
    if (rawText.isEmpty) {
      return false;
    }

    final align = (element.attributes['align'] ?? '').toLowerCase();
    final style = (element.attributes['style'] ?? '').toLowerCase();
    if (element.classes.any(_kNoFirstLineIndentClasses.contains)) {
      return false;
    }
    if (align == 'center' || align == 'right') {
      return false;
    }
    if (style.contains('text-align:center') ||
        style.contains('text-align: center') ||
        style.contains('text-align:right') ||
        style.contains('text-align: right') ||
        style.contains('text-indent:0') ||
        style.contains('text-indent: 0')) {
      return false;
    }

    return true;
  }

  dom.Text? _findFirstIndentableTextNode(dom.Node node) {
    if (node is dom.Text) {
      return node.text.replaceAll('\u200B', '').trim().isEmpty ? null : node;
    }
    if (node is! dom.Element) {
      return null;
    }
    if (node.localName == 'img' || node.localName == 'hr') {
      return null;
    }

    for (final child in node.nodes) {
      final textNode = _findFirstIndentableTextNode(child);
      if (textNode != null) {
        return textNode;
      }
    }

    return null;
  }

  String _prependFirstLineIndent(String text) {
    final trimmedLeft = text.trimLeft();
    if (trimmedLeft.isEmpty || trimmedLeft.startsWith('\u3000\u3000')) {
      return text;
    }

    final leadingLength = text.length - trimmedLeft.length;
    final leadingWhitespace =
        leadingLength > 0 ? text.substring(0, leadingLength) : '';
    return '$leadingWhitespace\u3000\u3000$trimmedLeft';
  }

  static const double _kImageWeight = 280.0;
  static const double _kMinBlockWeight = 1.0;

  static const Set<String> _kStructuralBlockTags = {
    'p',
    'div',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'li',
    'blockquote',
    'table',
    'pre',
    'center',
  };

  static const Set<String> _kBlockTags = {
    ..._kStructuralBlockTags,
    'img',
    'hr',
  };

  bool _isElementHidden(dom.Element el) {
    final style = (el.attributes['style'] ?? '').toLowerCase();
    return RegExp(r'display\s*:\s*none').hasMatch(style);
  }

  bool _shouldTreatDivAsBlock(dom.Element el) {
    // div 作为 block：必须是“叶子”div（没有直接的结构性 block 子元素）。
    if (_isStandaloneIllustrationContainer(el)) {
      return true;
    }

    final hasDirectStructuralChild = el.nodes.any(
      (n) => n is dom.Element && _kStructuralBlockTags.contains(n.localName),
    );
    if (hasDirectStructuralChild) return false;

    final text = _normalizeReaderText(el.text);
    final hasImg = el.getElementsByTagName('img').isNotEmpty;
    return text.isNotEmpty || hasImg || _shouldPreserveExplicitBlankLine(el);
  }

  bool _shouldTreatElementAsBlock(dom.Element el) {
    final tag = el.localName ?? '';
    if (!_kBlockTags.contains(tag)) return false;
    if (_isElementHidden(el)) return false;

    if (tag == 'div') {
      return _shouldTreatDivAsBlock(el);
    }

    if (tag == 'hr') return true;
    if (tag == 'img') return true;

    final text = _normalizeReaderText(el.text);
    final hasImg = el.getElementsByTagName('img').isNotEmpty;
    return text.isNotEmpty || hasImg || _shouldPreserveExplicitBlankLine(el);
  }

  double _computeBlockWeight({
    required int textLength,
    required int imageCount,
  }) {
    final raw = textLength.toDouble() + (imageCount * _kImageWeight);
    return raw < _kMinBlockWeight ? _kMinBlockWeight : raw;
  }

  _ReaderBlocksBuildResult _buildBlocksFromHtml(String html) {
    final fragment = html_parser.parseFragment(html);

    final blocks = <_ReaderBlock>[];
    final indexByCleanXPath = <String, int>{};
    final prefixWeights = <double>[];
    double totalWeight = 0.0;

    void addBlock(dom.Element el, String rawXPath) {
      final renderable = _buildRenderableBlockContent(el);

      final weight = _computeBlockWeight(
        textLength: renderable.textLength,
        imageCount: renderable.imageCount,
      );

      final clean = XPathUtils.cleanXPath(rawXPath);

      final block = _ReaderBlock(
        html: renderable.html,
        xPath: rawXPath,
        cleanXPath: clean,
        textLength: renderable.textLength,
        imageCount: renderable.imageCount,
        weight: weight,
      );

      indexByCleanXPath.putIfAbsent(clean, () => blocks.length);
      blocks.add(block);

      totalWeight += weight;
      prefixWeights.add(totalWeight);
    }

    void walk(dom.Node node, String currentPath) {
      if (node is dom.Element) {
        final tag = node.localName ?? '';

        // 构建当前层级 XPath 片段（与 XPathUtils._traverseAndInject 同构）
        int index = 1;
        final parent = node.parentNode;
        if (parent != null) {
          for (final sibling in parent.nodes) {
            if (sibling == node) break;
            if (sibling is dom.Element && sibling.localName == tag) {
              index++;
            }
          }
        }

        String myPath = '$currentPath/$tag[$index]';
        if (currentPath.isEmpty) {
          myPath = '//*/$tag[$index]';
        }

        // display:none 的注释节点：不进入 block 列表，也不下钻（保持 DOM 结构用于 XPath index）。
        if (_isElementHidden(node)) {
          return;
        }

        if (_shouldTreatElementAsBlock(node)) {
          addBlock(node, myPath);
          return; // block 叶子：不再下钻，避免重复拆分
        }

        // 非 block：继续下钻
        for (final child in node.nodes) {
          walk(child, myPath);
        }
      }
    }

    for (final node in fragment.nodes) {
      walk(node, '');
    }

    // 兜底：若完全无法拆分，则退化为单 block（避免空白页）
    if (blocks.isEmpty) {
      final wrapper = dom.Element.tag('div')..innerHtml = html;
      addBlock(wrapper, '//*');
    }

    return _ReaderBlocksBuildResult(
      blocks: blocks,
      indexByCleanXPath: indexByCleanXPath,
      prefixWeights: prefixWeights,
      totalWeight: totalWeight <= 0 ? 1.0 : totalWeight,
    );
  }

  ({String html, int textLength, int imageCount}) _buildRenderableBlockContent(
    dom.Element element,
  ) {
    final originalHtml = element.outerHtml;
    final originalTextLength = _normalizeReaderText(element.text).length;
    final originalImageCount =
        element.localName == 'img'
            ? 1
            : element.getElementsByTagName('img').length;

    if (!_hasHiddenDescendant(element)) {
      return (
        html: originalHtml,
        textLength: originalTextLength,
        imageCount: originalImageCount,
      );
    }

    try {
      final fragment = html_parser.parseFragment(originalHtml);
      for (final root in fragment.nodes.whereType<dom.Element>()) {
        _removeHiddenElements(root);
      }

      final roots = fragment.nodes.whereType<dom.Element>().toList();
      if (roots.isEmpty) {
        return (
          html: originalHtml,
          textLength: originalTextLength,
          imageCount: originalImageCount,
        );
      }

      final root = roots.first;
      return (
        html: _serializeFragmentNodes(fragment.nodes),
        textLength: _normalizeReaderText(root.text).length,
        imageCount:
            root.localName == 'img'
                ? 1
                : root.getElementsByTagName('img').length,
      );
    } catch (_) {
      return (
        html: originalHtml,
        textLength: originalTextLength,
        imageCount: originalImageCount,
      );
    }
  }

  bool _hasHiddenDescendant(dom.Element element) {
    for (final child in element.nodes) {
      if (child is! dom.Element) {
        continue;
      }
      if (_isElementHidden(child) || _hasHiddenDescendant(child)) {
        return true;
      }
    }
    return false;
  }

  void _removeHiddenElements(dom.Element element) {
    final hiddenChildren = <dom.Element>[];
    for (final child in element.nodes) {
      if (child is! dom.Element) {
        continue;
      }
      if (_isElementHidden(child)) {
        hiddenChildren.add(child);
        continue;
      }
      _removeHiddenElements(child);
    }
    for (final child in hiddenChildren) {
      child.remove();
    }
  }

  _ReaderLayoutInfo _analyzeLayoutFromBlocks(List<_ReaderBlock> blocks) {
    if (blocks.isEmpty) {
      return const _ReaderLayoutInfo(_ReaderLayoutMode.standard);
    }

    final totalImages = blocks.fold<int>(0, (sum, b) => sum + b.imageCount);
    final totalText = blocks.fold<int>(0, (sum, b) => sum + b.textLength);

    // 居中：仅一张图且无文本
    if (totalImages == 1 && totalText == 0 && blocks.length == 1) {
      return const _ReaderLayoutInfo(_ReaderLayoutMode.center);
    }

    bool isImageOnly(_ReaderBlock b) => b.imageCount > 0 && b.textLength == 0;

    final startsWithImage = isImageOnly(blocks.first);
    final endsWithImage = isImageOnly(blocks.last);

    int leadingImageBlocks = 0;
    for (final b in blocks) {
      if (isImageOnly(b)) {
        leadingImageBlocks++;
      } else {
        break;
      }
    }

    if (leadingImageBlocks >= 2 && totalImages > 2) {
      return _ReaderLayoutInfo(
        _ReaderLayoutMode.immersive,
        startsWithImage: true,
        endsWithImage: endsWithImage,
      );
    }

    return _ReaderLayoutInfo(
      _ReaderLayoutMode.standard,
      startsWithImage: startsWithImage,
      endsWithImage: endsWithImage,
    );
  }

  String _formatEmValue(double value) {
    final rounded = value.toStringAsFixed(1);
    return rounded.endsWith('.0') ? '${value.toInt()}em' : '${rounded}em';
  }

  String? _fontSizeFromPresetClass(Iterable<String> classes) {
    final emClassPattern = RegExp(r'^em(\d{2})$');
    for (final className in classes) {
      final match = emClassPattern.firstMatch(className);
      if (match == null) {
        continue;
      }

      final rawValue = int.tryParse(match.group(1)!);
      if (rawValue == null || rawValue < 5 || rawValue > 30) {
        continue;
      }

      return _formatEmValue(rawValue / 10);
    }

    return null;
  }

  bool _isFootnoteMarkerImage(dom.Element img) {
    if (img.classes.contains('footnote')) {
      return true;
    }

    dom.Element? current = img.parent;
    while (current != null) {
      if (current.localName == 'a' &&
          current.classes.contains('duokan-footnote')) {
        return true;
      }
      current = current.parent;
    }

    return false;
  }

  bool _isIllustrationContainer(dom.Element element) {
    return element.classes.contains('illus') ||
        element.classes.contains('illu') ||
        element.classes.contains('duokan-image-single');
  }

  static const Set<String> _kPreviewImageContainerClasses = {
    'duokan-image-single',
    'image-preview',
    'illus',
  };

  bool _isPreviewImageContainer(dom.Element? element) {
    if (element == null) {
      return false;
    }
    return element.classes.any(_kPreviewImageContainerClasses.contains);
  }

  bool _hasNonFootnoteImage(dom.Element element) {
    return element
        .getElementsByTagName('img')
        .any((img) => !_isFootnoteMarkerImage(img));
  }

  bool _isImageOnlyBlockContainer(dom.Element element) {
    return _hasNonFootnoteImage(element) &&
        _normalizeReaderText(element.text).isEmpty;
  }

  bool _isStandaloneIllustrationContainer(dom.Element element) {
    if (element.localName != 'div') {
      return false;
    }
    if (!_isIllustrationContainer(element) &&
        !_isPreviewImageContainer(element)) {
      return false;
    }
    if (_normalizeReaderText(element.text).isNotEmpty) {
      return false;
    }

    final images =
        element
            .getElementsByTagName('img')
            .where((img) => !_isFootnoteMarkerImage(img))
            .toList();
    return images.length == 1;
  }

  bool _shouldRenderAsIllustrationBlock(dom.Element element) {
    return _isIllustrationContainer(element) ||
        _isPreviewImageContainer(element) ||
        _isImageOnlyBlockContainer(element);
  }

  bool _isPreviewableReaderImage(dom.Element element) {
    if (element.localName != 'img' || element.classes.contains('no-preview')) {
      return false;
    }
    return _isPreviewImageContainer(element.parent);
  }

  bool _hasFullWidthStyle(dom.Element element) {
    final style = (element.attributes['style'] ?? '').toLowerCase().replaceAll(
      ' ',
      '',
    );
    return style.contains('width:100%') || style.contains('width:100%;');
  }

  double? _parseImageDimension(String? rawValue) {
    if (rawValue == null) {
      return null;
    }
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(trimmed);
    if (match == null) {
      return null;
    }
    return double.tryParse(match.group(1)!);
  }

  double? _imageAspectRatio(double? width, double? height) {
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return width / height;
  }

  Widget? _buildIllustrationContainerWidget(
    dom.Element element,
    Color textColor,
    double readerSidePadding,
    bool openImagePreviewOnLongPress,
  ) {
    if (!_isStandaloneIllustrationContainer(element)) {
      return null;
    }

    final images =
        element
            .getElementsByTagName('img')
            .where((img) => !_isFootnoteMarkerImage(img))
            .toList();
    if (images.length != 1) {
      return null;
    }

    final image = images.first;
    final src = image.attributes['src']?.trim();
    if (src == null || src.isEmpty) {
      return null;
    }

    final aspectRatio = _imageAspectRatio(
      _parseImageDimension(image.attributes['width']),
      _parseImageDimension(image.attributes['height']),
    );
    final fullWidth = _hasFullWidthStyle(element) || _hasFullWidthStyle(image);
    final previewable = _isPreviewableReaderImage(image);
    final alt = image.attributes['alt'];

    return Builder(
      builder: (context) {
        final maxWidth = (MediaQuery.sizeOf(context).width -
                readerSidePadding * 2)
            .clamp(48.0, double.infinity);
        Widget child = ReaderRoundedNetworkImage(
          imageUrl: src,
          alt: alt,
          errorColor: textColor,
          borderRadius: 3,
          previewable: previewable,
          openPreviewOnLongPress: openImagePreviewOnLongPress,
        );

        if (aspectRatio != null) {
          child = AspectRatio(aspectRatio: aspectRatio, child: child);
        }

        child =
            fullWidth
                ? SizedBox(width: maxWidth, child: child)
                : ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: child,
                );

        return Align(alignment: Alignment.center, child: child);
      },
    );
  }

  static const Set<String> _kTableRelatedTags = {
    'table',
    'thead',
    'tbody',
    'tfoot',
    'tr',
    'td',
    'th',
    'caption',
  };

  bool _hasAncestorTag(
    dom.Element element,
    Set<String> tags, {
    int maxDepth = 8,
  }) {
    dom.Element? current = element.parent;
    int depth = 0;
    while (current != null && depth < maxDepth) {
      if (tags.contains(current.localName)) {
        return true;
      }
      current = current.parent;
      depth++;
    }
    return false;
  }

  bool _isInsideTableStructure(dom.Element element) {
    return _hasAncestorTag(element, _kTableRelatedTags);
  }

  bool _isInsideIllustrationContainer(dom.Element element) {
    dom.Element? current = element.parent;
    int depth = 0;
    while (current != null && depth < 3) {
      if (_isIllustrationContainer(current) ||
          _isPreviewImageContainer(current)) {
        return true;
      }
      current = current.parent;
      depth++;
    }
    return false;
  }

  bool _usesReaderParagraphSpacing(String? tag) {
    return tag == 'p' || tag == 'div' || tag == 'blockquote' || tag == 'center';
  }

  String _formatReaderPixelValue(double value) {
    final normalized = value.clamp(0.0, 999.0);
    if ((normalized - normalized.roundToDouble()).abs() < 0.01) {
      return '${normalized.toInt()}px';
    }
    return '${normalized.toStringAsFixed(1)}px';
  }

  bool _blockUsesReaderParagraphSpacing(_ReaderBlock block) {
    try {
      final fragment = html_parser.parseFragment(block.html);
      dom.Element? root;
      for (final node in fragment.nodes) {
        if (node is dom.Element) {
          root = node;
          break;
        }
      }
      if (root == null) {
        return false;
      }

      final tag = root.localName;
      if (!_usesReaderParagraphSpacing(tag) ||
          _shouldRenderAsIllustrationBlock(root)) {
        return false;
      }

      final hasText = _normalizeReaderText(root.text).isNotEmpty;
      if (hasText) {
        return true;
      }

      final hasNonFootnoteImage = root
          .getElementsByTagName('img')
          .any((img) => !_isFootnoteMarkerImage(img));
      return !hasNonFootnoteImage && _shouldPreserveExplicitBlankLine(root);
    } catch (_) {
      return false;
    }
  }

  Map<String, String>? _buildReaderBlockTagStyles(
    dom.Element element,
    double readerLineHeight,
    double readerSidePadding,
  ) {
    final tag = element.localName;
    if (tag == null) {
      return null;
    }

    if (tag == 'body') {
      return {
        'margin': '0',
        'padding': '0',
        'line-height': readerLineHeight.toStringAsFixed(1),
      };
    }

    final textTags = {
      'p',
      'div',
      'blockquote',
      'h1',
      'h2',
      'h3',
      'h4',
      'h5',
      'h6',
      'center',
    };
    if (!textTags.contains(tag)) {
      return null;
    }

    if (_shouldRenderAsIllustrationBlock(element)) {
      return {
        'margin': '0',
        'padding': '0',
        'line-height': '0',
        'text-align': 'center',
      };
    }

    switch (tag) {
      case 'h1':
        return {
          'padding-left': _formatReaderPixelValue(readerSidePadding),
          'padding-right': _formatReaderPixelValue(readerSidePadding),
          'font-size': '1.65em',
          'line-height': '120%',
          'text-align': 'center',
          'font-weight': 'bold',
          'margin-top': '0.1em',
          'margin-bottom': '0.4em',
        };
      case 'h2':
        return {
          'padding-left': _formatReaderPixelValue(readerSidePadding),
          'padding-right': _formatReaderPixelValue(readerSidePadding),
          'font-size': '1.25em',
          'line-height': '120%',
          'text-align': 'center',
          'font-weight': 'bold',
          'margin-top': '0.3em',
          'margin-bottom': '0.5em',
        };
      case 'h3':
        return {
          'padding-left': _formatReaderPixelValue(readerSidePadding),
          'padding-right': _formatReaderPixelValue(readerSidePadding),
          'font-size': '0.95em',
          'line-height': '120%',
          'text-align': 'center',
          'font-weight': 'bold',
          'text-indent': '0',
          'margin-top': '0.2em',
          'margin-bottom': '0.2em',
        };
      case 'h4':
        return {
          'padding-left': _formatReaderPixelValue(readerSidePadding),
          'padding-right': _formatReaderPixelValue(readerSidePadding),
          'font-size': '1.5em',
          'font-weight': 'bold',
          'text-indent': '1.333em',
          'margin-top': '0.5em',
          'margin-bottom': '1em',
        };
      case 'center':
        return {
          'padding-left': _formatReaderPixelValue(readerSidePadding),
          'padding-right': _formatReaderPixelValue(readerSidePadding),
          'line-height': readerLineHeight.toStringAsFixed(1),
          'text-align': 'center',
          'text-indent': '0',
        };
      default:
        return {
          'padding-left': _formatReaderPixelValue(readerSidePadding),
          'padding-right': _formatReaderPixelValue(readerSidePadding),
          'line-height': readerLineHeight.toStringAsFixed(1),
        };
    }
  }

  Map<String, String>? _buildReaderPresetClassStyles(dom.Element element) {
    final classes = element.classes;
    if (classes.isEmpty) {
      return null;
    }

    final style = <String, String>{};
    final presetFontSize = _fontSizeFromPresetClass(classes);
    if (presetFontSize != null) {
      style['font-size'] = presetFontSize;
    }

    if (classes.contains('pius1') ||
        classes.contains('pius2') ||
        classes.contains('ph4')) {
      style.addAll({
        'font-size': '1.5em',
        'font-weight': 'bold',
        'text-indent': '1.333em',
        'margin-top': '0.5em',
        'margin-bottom': '1em',
      });
    }

    if (classes.contains('right')) {
      style.addAll({'text-indent': '0', 'text-align': 'right'});
    }
    if (classes.contains('left')) {
      style.addAll({'text-indent': '0', 'text-align': 'left'});
    }
    if (classes.contains('center')) {
      style.addAll({'text-indent': '0', 'text-align': 'center'});
    }
    if (classes.contains('zin')) {
      style['text-indent'] = '0';
    }

    if (classes.contains('bold')) {
      style['font-weight'] = 'bold';
    }
    if (classes.contains('ita')) {
      style['font-style'] = 'italic';
    }
    if (classes.contains('stress')) {
      style.addAll({
        'font-weight': 'bold',
        'font-size': '1.1em',
        'margin-top': '0.3em',
        'margin-bottom': '0.3em',
      });
    }
    if (classes.contains('author')) {
      style.addAll({
        'font-size': '1.2em',
        'text-align': 'right',
        'font-weight': 'bold',
        'font-style': 'italic',
        'margin-right': '1em',
        'text-indent': '0',
      });
    }
    if (classes.contains('message') || classes.contains('cut-line')) {
      style.addAll({
        'text-indent': '0',
        'line-height': '1.2em',
        'margin-top': '0.2em',
        'margin-bottom': '0.2em',
      });
    }
    if (classes.contains('meg')) {
      style.addAll({
        'font-size': '1.3em',
        'line-height': '1.3em',
        'margin-top': '0.5em',
        'margin-bottom': '0',
        'text-indent': '0',
      });
    }
    if (classes.contains('lh')) {
      style['line-height'] = '1em';
    }
    if (classes.contains('m0')) {
      style['margin'] = '0';
    }
    if (classes.contains('p0')) {
      style['padding'] = '0';
    }

    if (classes.contains('red')) {
      style['color'] = '#ff0000';
    }
    if (classes.contains('green')) {
      style['color'] = '#00ff00';
    }
    if (classes.contains('blue')) {
      style['color'] = '#0000ff';
    }
    if (classes.contains('black')) {
      style['color'] = '#000000';
    }
    if (classes.contains('white')) {
      style['color'] = '#ffffff';
    }

    if (classes.contains('fl')) {
      style.addAll({'float': 'left', 'margin-right': '0.5em', 'padding': '0'});
    }
    if (classes.contains('fr')) {
      style.addAll({'float': 'right', 'margin-left': '0.5em', 'padding': '0'});
    }
    if (classes.contains('cl')) {
      style['clear'] = 'left';
    }
    if (classes.contains('cr')) {
      style['clear'] = 'right';
    }
    if (classes.contains('cb')) {
      style['clear'] = 'both';
    }

    if (classes.contains('vt')) {
      style['vertical-align'] = 'top';
    }
    if (classes.contains('vb')) {
      style['vertical-align'] = 'bottom';
    }
    if (classes.contains('vm')) {
      style['vertical-align'] = 'middle';
    }

    if (classes.contains('no-d')) {
      style['text-decoration'] = 'none';
    }
    if (classes.contains('bc')) {
      style['border-collapse'] = 'collapse';
    }
    if (classes.contains('dash-break')) {
      style['word-break'] = 'break-all';
      style['word-wrap'] = 'break-word';
    }
    if (classes.contains('dot') || classes.contains('em-dot')) {
      style['text-decoration-line'] = 'underline';
      style['text-decoration-style'] = 'dotted';
    }

    if (_isIllustrationContainer(element) ||
        _isPreviewImageContainer(element)) {
      style.addAll({
        'text-align': 'center',
        'padding-top': '2px',
        'padding-bottom': '2px',
      });
    }

    return style.isEmpty ? null : style;
  }

  int _lowerBoundPrefixWeight(List<double> prefixWeights, double target) {
    if (prefixWeights.isEmpty) return 0;
    int lo = 0;
    int hi = prefixWeights.length - 1;
    while (lo < hi) {
      final mid = lo + ((hi - lo) >> 1);
      if (prefixWeights[mid] >= target) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    return lo;
  }

  int _resolveBlockIndexForProgress(double progress01) {
    final result = _blocksResult;
    if (result == null || result.blocks.isEmpty) return 0;
    final p = progress01.clamp(0.0, 1.0);
    final target = p * result.totalWeight;
    if (target <= 0) return 0;
    if (target >= result.totalWeight) return result.blocks.length - 1;
    return _lowerBoundPrefixWeight(result.prefixWeights, target);
  }

  int _resolveBlockIndexForXPath(String rawXPath) {
    final result = _blocksResult;
    if (result == null || result.blocks.isEmpty) return 0;

    var clean = XPathUtils.cleanXPath(rawXPath);
    if (clean.isEmpty) return 0;

    while (true) {
      final idx = result.indexByCleanXPath[clean];
      if (idx != null) return idx;

      final slash = clean.lastIndexOf('/');
      if (slash <= 0) break;
      clean = clean.substring(0, slash);
    }

    return 0;
  }

  Future<void> _waitForListAttachment() async {
    const maxFrames = 60;
    int frames = 0;
    while (mounted && !_itemScrollController.isAttached && frames < maxFrames) {
      final completer = Completer<void>();
      WidgetsBinding.instance.addPostFrameCallback((_) => completer.complete());
      await completer.future;
      frames++;
    }
  }

  Future<void> _jumpToBlockIndex(int index, {double alignment = 0.0}) async {
    final result = _blocksResult;
    if (result == null || result.blocks.isEmpty) return;

    final clamped = index.clamp(0, result.blocks.length - 1);
    await _waitForListAttachment();
    if (!mounted || !_itemScrollController.isAttached) return;

    _itemScrollController.jumpTo(index: clamped, alignment: alignment);
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification ||
        notification is OverscrollNotification) {
      final metrics = notification.metrics;

      // 触顶检测：滚动位置 <= 最小值
      final atTop = metrics.pixels <= metrics.minScrollExtent;
      // 触底检测：滚动位置 >= 最大值 (这里是精准的物理位置，不受元素内容或 padding 等逻辑算错干扰)
      final atBottom = metrics.pixels >= metrics.maxScrollExtent;

      if (atTop && !_atTopEdge) {
        if (!_barsVisible) _toggleBars();
      }
      if (atBottom && !_atBottomEdge) {
        if (!_barsVisible) _toggleBars();
      }

      _atTopEdge = atTop;
      _atBottomEdge = atBottom;
    }
    // 不要拦截，让系统继续向上传递滚动事件
    return false;
  }

  void _onItemPositionsChanged() {
    final result = _blocksResult;
    if (result == null || result.blocks.isEmpty) return;

    // 滚动时关闭注释 Popover，避免悬浮层与内容位置脱节
    _FootnoteAnchor.dismissCurrent();

    final positions = _itemPositionsListener.itemPositions.value;
    ItemPosition? top;
    for (final p in positions) {
      final isVisible = p.itemTrailingEdge > 0 && p.itemLeadingEdge < 1;
      if (!isVisible) continue;
      if (top == null || p.index < top.index) {
        top = p;
      }
    }
    if (top == null) return;

    final topIndex = top.index.clamp(0, result.blocks.length - 1);

    if (topIndex != _topVisibleBlockIndex) {
      _topVisibleBlockIndex = topIndex;
      _lastTopVisibleXPath = result.blocks[topIndex].xPath;
    }

    // 进度：prefixWeight + block 内部比例（基于 leadingEdge）
    final total = result.totalWeight;
    final before = topIndex > 0 ? result.prefixWeights[topIndex - 1] : 0.0;
    final blockWeight = result.blocks[topIndex].weight;

    final extent = (top.itemTrailingEdge - top.itemLeadingEdge).abs();
    final fractionPast =
        extent > 0 ? (-top.itemLeadingEdge / extent).clamp(0.0, 1.0) : 0.0;

    double progress =
        total > 0 ? ((before + (fractionPast * blockWeight)) / total) : 0.0;

    _readProgressNotifier.value = progress.clamp(0.0, 1.0);

    // 防抖保存（闲置 2 秒）
    _savePositionTimer?.cancel();
    _savePositionTimer = Timer(const Duration(seconds: 2), () {
      _saveCurrentPosition();
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 初始化 SharedPreferences 及图片比例缓存
    SharedPreferences.getInstance().then((prefs) {
      _prefs = prefs;
      if (mounted) setState(() {});
    });

    // 初始化动画控制器，默认展开状态 (value: 1.0)
    _barsAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0,
    );

    _itemPositionsListener.itemPositions.addListener(_onItemPositionsChanged);
    _targetSortNum = widget.sortNum; // 初始化目标章节号
    // 首次进入阅读器：允许用服务端进度进行一次“极速对齐”（避免详情页缓存/多端阅读导致初始章节不准）
    // 之后的手动切章必须绝对尊重用户意图，因此后续调用默认禁用该对齐逻辑。
    _loadChapter(
      widget.bid,
      widget.sortNum,
      allowServerOverride: widget.allowServerOverrideOnOpen,
      openPosition: _ReaderChapterOpenPosition.saved,
    );
    // 开始记录阅读时长
    _readingTimeService.startSession();

    // 初始化全屏和信息栏
    _applyReaderSystemUiMode();
    _initInfoBar();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 首次进入时提取封面颜色（Theme.of 需在 didChangeDependencies 中调用）
    if (_dynamicColorScheme == null) {
      _extractColors();
    }
  }

  void _initInfoBar() {
    _updateTime();
    _updateBattery();

    // 监听电量状态变化
    _batteryStateSubscription = _battery.onBatteryStateChanged.listen((state) {
      if (!mounted) return;
      _batteryStateNotifier.value = state;
      _updateBattery();
    });

    // 每30秒同步更新时间与电量
    _infoTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateTime();
      _updateBattery();
    });
  }

  void _updateTime() {
    final now = DateTime.now();

    if (!mounted) return;
    _timeStringNotifier.value = TimeUtils.formatChineseDayPeriodTime(now);
  }

  Future<void> _updateBattery() async {
    try {
      final level = await _battery.batteryLevel;
      if (!mounted) return;
      _batteryLevelNotifier.value = level;
    } catch (e) {
      _logger.warning('Failed to get battery level: $e');
    }
  }

  /// 从封面 BlurHash 提取颜色生成动态配色
  void _extractColors() {
    if (widget.coverUrl == null || widget.coverUrl!.isEmpty) return;

    // 检查是否开启了封面取色功能
    final settings = ref.read(settingsProvider);
    if (!settings.coverColorExtraction) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cacheKey = '${widget.bid}_${isDark ? 'dark' : 'light'}';

    // 优先检查缓存
    if (_schemeCache.containsKey(cacheKey)) {
      if (mounted) {
        setState(() {
          _dynamicColorScheme = _schemeCache[cacheKey]!;
        });
      }
      return;
    }

    // 从 BlurHash DC 分量同步提取主色
    final seedColor = CoverUrlUtils.extractSeedColor(widget.coverUrl);
    if (seedColor != null && mounted) {
      final scheme = ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: isDark ? Brightness.dark : Brightness.light,
      );
      _schemeCache[cacheKey] = scheme;
      setState(() {
        _dynamicColorScheme = scheme;
      });
    }
  }

  @override
  void dispose() {
    // 关闭可能残留的注释 Popover
    _FootnoteAnchor.dismissCurrent();

    _barsAnimController.dispose();
    _savePositionTimer?.cancel();
    _batteryStateSubscription?.cancel();
    // 结束阅读时长记录
    _readingTimeService.endSession();
    // 销毁前同步保存位置
    if (_chapter != null) {
      final finalXPath = _getTopVisibleXPath();
      developer.log(
        'DISPOSE: Saving cached position $finalXPath',
        name: 'POSITION',
      );
      _progressService.saveLocalPosition(
        bookId: widget.bid,
        chapterId: _chapter!.id,
        sortNum: _chapter!.sortNum,
        xPath: finalXPath,
        title: widget.bookTitle,
        cover: widget.coverUrl,
        chapterTitle: _chapter?.title,
        immediate: true, // 退出阅读器时立即同步
      );
    }
    WidgetsBinding.instance.removeObserver(this);
    _itemPositionsListener.itemPositions.removeListener(
      _onItemPositionsChanged,
    );
    _readProgressNotifier.dispose();
    _infoTimer?.cancel();
    _batteryLevelNotifier.dispose();
    _batteryStateNotifier.dispose();
    _timeStringNotifier.dispose();
    // 退出阅读页时恢复系统栏显示
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 后台时保存位置和时长
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _saveCurrentPosition();
      _readingTimeService.endSession();
    }
    // 前台恢复记录时长
    if (state == AppLifecycleState.resumed) {
      _applyReaderSystemUiMode();
      _readingTimeService.startSession();
    }
  }

  void _applyReaderSystemUiMode() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  double _readerBottomPadding(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 0;
    }
    if (defaultTargetPlatform != TargetPlatform.android) {
      return bottomPadding;
    }

    final stablePadding = _stableAndroidBottomPadding;
    if (stablePadding == null || bottomPadding < stablePadding) {
      _stableAndroidBottomPadding = bottomPadding;
      return bottomPadding;
    }

    return stablePadding;
  }

  void _toggleBars() {
    setState(() {
      _barsVisible = !_barsVisible;
      if (_barsVisible) {
        _barsAnimController.forward();
      } else {
        _barsAnimController.reverse();
      }
    });
  }

  Future<void> _openReaderBackgroundPage() async {
    final settings = ref.read(settingsProvider);
    final navigator = Navigator.of(context);
    final shouldHideNativeButtons =
        Platform.isIOS && settings.useIOS26Style && _barsVisible;

    if (shouldHideNativeButtons && mounted) {
      setState(() {
        _barsVisible = false;
        _barsAnimController.reverse();
      });
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }

    try {
      final route =
          Platform.isIOS
              ? CupertinoPageRoute<void>(
                builder: (context) => const ReaderBackgroundPage(),
              )
              : MaterialPageRoute<void>(
                builder: (context) => const ReaderBackgroundPage(),
              );
      await navigator.push(route);
    } finally {
      if (shouldHideNativeButtons && mounted) {
        setState(() {
          _barsVisible = true;
          _barsAnimController.forward();
        });
      }
    }
  }

  /// 保存滚动进度（本地+服务端）
  Future<void> _saveCurrentPosition() async {
    if (_chapter == null || _blocksResult == null) return;

    final currentXPath = _getTopVisibleXPath();

    // 本地保存以便快速恢复
    await _progressService.saveLocalPosition(
      bookId: widget.bid,
      chapterId: _chapter!.id,
      sortNum: _chapter!.sortNum,
      xPath: currentXPath,
      title: widget.bookTitle,
      cover: widget.coverUrl,
      chapterTitle: _chapter?.title,
    );

    // 记录用户所在章节（基于 XPath 的确切定位）
    await _progressService.saveReadPosition(
      bookId: widget.bid,
      chapterId: _chapter!.id,
      xPath: currentXPath,
    );

    _logger.info('Saved position: ch${_chapter!.sortNum} @ $currentXPath');
  }

  /// 内容加载后恢复进度
  Future<void> _restoreScrollPosition(
    _ReaderChapterOpenPosition openPosition,
  ) async {
    if (_initialScrollDone) return;
    _initialScrollDone = true;

    final result = _blocksResult;
    if (result == null || result.blocks.isEmpty) return;

    if (openPosition == _ReaderChapterOpenPosition.start) {
      _topVisibleBlockIndex = 0;
      _lastTopVisibleXPath = result.blocks.first.xPath;
      await _jumpToBlockIndex(0);
      return;
    }

    if (openPosition == _ReaderChapterOpenPosition.end) {
      final lastIndex = result.blocks.length - 1;
      _topVisibleBlockIndex = lastIndex;
      _lastTopVisibleXPath = result.blocks[lastIndex].xPath;
      await _jumpToBlockIndex(lastIndex, alignment: 1.0);
      return;
    }

    final position = await _progressService.getLocalPosition(widget.bid);

    _logger.info(
      'Restoring position check: saved=${position?.sortNum}, current=${_chapter?.sortNum}, '
      'xPath=${position?.xPath}, blocks=${result.blocks.length}',
    );

    if (position != null && position.sortNum == _chapter?.sortNum) {
      if (position.xPath.startsWith('scroll:')) {
        final targetPos =
            double.tryParse(position.xPath.replaceAll('scroll:', '')) ?? 0.0;
        final index = _resolveBlockIndexForProgress(targetPos);

        _topVisibleBlockIndex = index;
        _lastTopVisibleXPath = result.blocks[index].xPath;
        await _jumpToBlockIndex(index);
      } else {
        final index = _resolveBlockIndexForXPath(position.xPath);
        _topVisibleBlockIndex = index;
        _lastTopVisibleXPath = result.blocks[index].xPath;
        await _jumpToBlockIndex(index);
      }
    } else if (position != null) {
      _logger.info(
        'Position NOT restored: sortNum mismatch or no scroll clients. '
        'Saved chapter=${position.sortNum}, Current chapter=${_chapter?.sortNum}',
      );
    }
  }

  Future<void> _loadChapter(
    int bid,
    int sortNum, {
    bool allowServerOverride = false,
    _ReaderChapterOpenPosition openPosition = _ReaderChapterOpenPosition.start,
  }) async {
    _logger.info('Requesting chapter with SortNum: $sortNum...');

    // 版本号递增，用于打断旧请求
    final currentVersion = ++_loadVersion;

    // 加载新章前保存当前进度（不阻塞新请求）
    if (_chapter != null) {
      _saveCurrentPosition(); // 不 await，允许打断
    }

    setState(() {
      _loading = true;
      _error = null;
      _initialScrollDone = false;

      // 重置边界状态：新章节首次到边界时可自动展示一次菜单栏
      _atTopEdge = true;
      _atBottomEdge = false;

      // 重置渲染内容与脚注缓存，避免短暂显示上一章的注释映射
      _footnoteNotesById = const {};

      _blocksResult = null;
      _layoutInfo = const _ReaderLayoutInfo(_ReaderLayoutMode.standard);
      _topVisibleBlockIndex = 0;
      _lastTopVisibleXPath = '//*';
      _readProgressNotifier.value = 0.0;
    });

    try {
      final settings = ref.read(settingsProvider);

      // 1. 获取内容 & 同步校验最新云端进度（双管齐下）
      // 由于用户可能在详情页刷新完前极速点击，这里做最后一道防线
      final contentFuture = _chapterService.getNovelContent(
        bid,
        sortNum,
        convert: settings.convertType == 'none' ? null : settings.convertType,
      );

      // 仅在允许服务端覆盖时才请求 BookInfo（避免手动切章时被云端进度强制重定向回当前章）
      final bookInfoFuture =
          allowServerOverride
              ? _bookService
                  .getBookInfo(bid)
                  .then<BookInfo?>((v) => v)
                  .catchError((_) => null)
              : Future.value(null);

      final results = await Future.wait([contentFuture, bookInfoFuture]);
      final chapter = results[0] as ChapterContent;
      final info = results[1] as BookInfo?;

      // 打断检查：如果有新请求，放弃当前结果
      if (currentVersion != _loadVersion) {
        _logger.info(
          'Load interrupted, version $currentVersion != $_loadVersion',
        );
        return;
      }

      // 进度极速防伪核对：仅允许在“首次进入阅读器/恢复阅读”的场景覆盖章节号。
      // 手动切章（上一章/下一章/章节列表）必须禁用 override/redirect，否则会出现永远回到同一章的现象。
      if (allowServerOverride &&
          info != null &&
          info.serverReadPosition != null &&
          info.serverReadPosition!.chapterId != null) {
        final serverChapterId = info.serverReadPosition!.chapterId!;
        int? serverSortNum;
        for (int i = 0; i < info.chapters.length; i++) {
          if (info.chapters[i].id == serverChapterId) {
            serverSortNum = i + 1;
            break;
          }
        }

        final serverXPath = info.serverReadPosition!.position ?? '//*';

        if (serverSortNum != null) {
          final localPos = await _progressService.getLocalPosition(bid);
          bool shouldUseServer = false;

          if (localPos != null && localPos.sortNum == serverSortNum) {
            if (serverXPath != '//*') shouldUseServer = true;
          } else {
            shouldUseServer = true;
          }

          if (shouldUseServer) {
            _logger.info(
              'ReaderPage Speed Check: overriding with server pos: $serverSortNum @ $serverXPath',
            );
            await _progressService.saveLocalPosition(
              bookId: bid,
              chapterId: serverChapterId,
              sortNum: serverSortNum,
              xPath: serverXPath,
            );

            // 如果连章节号都变了，立刻重定向并终止本次旧章加载
            if (serverSortNum != sortNum) {
              _logger.info(
                'ReaderPage Speed Check: chapter changed to $serverSortNum, redirecting...',
              );
              if (mounted) {
                setState(() {
                  _targetSortNum = serverSortNum!;
                });
                // 只允许对齐一次，避免递归重定向/覆盖用户后续意图
                _loadChapter(
                  bid,
                  serverSortNum,
                  allowServerOverride: false,
                  openPosition: _ReaderChapterOpenPosition.saved,
                );
              }
              return;
            }
          }
        }
      }

      _logger.info('Chapter loaded: ${chapter.title}');

      // 2. 加载混淆字体（带缓存控制）
      String? family;
      if (chapter.fontUrl != null) {
        final settings = ref.read(settingsProvider);
        family = await _fontManager.loadFont(
          chapter.fontUrl,
          cacheEnabled: settings.fontCacheEnabled,
          cacheLimit: settings.fontCacheLimit,
        );

        // 再次打断检查
        if (currentVersion != _loadVersion) {
          _logger.info(
            'Load interrupted after font, version $currentVersion != $_loadVersion',
          );
          return;
        }

        _logger.info(
          'Font loaded: $family (cache: ${settings.fontCacheEnabled}, limit: ${settings.fontCacheLimit})',
        );
      }

      if (mounted && currentVersion == _loadVersion) {
        // 3. 预处理脚注/注释（对标 Web：隐藏原注释节点 + 记录内容 + 禁用默认跳转）
        final invisibleCodepoints = _fontManager.getInvisibleCodepoints(family);
        final sanitizedContent = _stripInvisiblePlaceholderCodepoints(
          chapter.content,
          invisibleCodepoints,
        );
        final processed = _processFootnotes(sanitizedContent);
        // 4. 构建可虚拟化 blocks（Route B：用于性能优化与逻辑进度）
        final blocksResult = _buildBlocksFromHtml(processed.html);
        final layoutInfo = _analyzeLayoutFromBlocks(blocksResult.blocks);

        setState(() {
          _chapter = chapter;
          // 确保目标章节号与实际加载章节一致（使用请求的 sortNum，而非返回的）
          _targetSortNum = sortNum;
          _fontFamily = family; // 字体加载逻辑
          _footnoteNotesById = processed.notesById;
          _blocksResult = blocksResult;
          _layoutInfo = layoutInfo;
          _loading = false;
          _shownImages.clear(); // 新层清空曾经看过的图
          _indentedBlockHtmlCache.clear();
          _topVisibleBlockIndex = 0;
          _lastTopVisibleXPath =
              blocksResult.blocks.isNotEmpty
                  ? blocksResult.blocks.first.xPath
                  : '//*';
          _readProgressNotifier.value = 0.0;
        });

        // 构建后恢复进度
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          // 最终打断检查
          if (currentVersion != _loadVersion) return;

          await _restoreScrollPosition(openPosition);

          // 无论是否恢复进度，都保存当前章节到服务端
          // 确保点击章节进入后即使不滑动也能同步
          if (mounted && _chapter != null && currentVersion == _loadVersion) {
            await _saveCurrentPosition();
            _logger.info('Chapter loaded, saved position to sync with server');
          }
        });
      }
    } catch (e) {
      // 打断时不处理错误
      if (currentVersion != _loadVersion) return;

      _logger.severe('Error loading chapter: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _onPrev() {
    if (_targetSortNum > 1) {
      setState(() {
        _targetSortNum--;
      });
      // 手动切章：必须禁用服务端章节覆盖/重定向
      _loadChapter(
        widget.bid,
        _targetSortNum,
        openPosition: _ReaderChapterOpenPosition.end,
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已是第一章')));
    }
  }

  void _onNext() {
    if (_targetSortNum < widget.totalChapters) {
      setState(() {
        _targetSortNum++;
      });
      // 手动切章：必须禁用服务端章节覆盖/重定向
      _loadChapter(
        widget.bid,
        _targetSortNum,
        openPosition: _ReaderChapterOpenPosition.start,
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已是最后一章')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    // 计算当前应用的 Theme
    final currentTheme = Theme.of(context).copyWith(
      colorScheme:
          (settings.coverColorExtraction ? _dynamicColorScheme : null) ??
          Theme.of(context).colorScheme,
    );

    // 用 AnimatedTheme 包裹最外层，确保内部所有组件都能拿到正确的 currentTheme
    return AnimatedTheme(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      data: currentTheme,
      child: Builder(
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          // ignore: deprecated_member_use
          return WillPopScope(
            onWillPop: _onWillPop,
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(
                statusBarColor:
                    Colors.transparent, // 顶部状态栏透明（由 SoftEdgeBlur 接管视觉）
                statusBarIconBrightness:
                    isDark ? Brightness.light : Brightness.dark,
                // 底部导航条透明沉浸
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarDividerColor: Colors.transparent,
                systemNavigationBarIconBrightness:
                    isDark ? Brightness.light : Brightness.dark,
              ),
              child: Scaffold(
                body: Stack(
                  children: [
                    // 主要内容层
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: _toggleBars,
                        child:
                            _loading
                                ? const Center(child: M3ELoadingIndicator())
                                : _error != null
                                ? _buildErrorView()
                                : _buildWebContent(context, settings),
                      ),
                    ),

                    // 悬浮功能区
                    _buildFloatingTopBar(context),
                    _buildFloatingBottomControls(context),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // _analyzeLayout 已由基于 blocks 的 _analyzeLayoutFromBlocks 替代（见上方）。

  Widget _buildWebContent(BuildContext context, AppSettings settings) {
    final double topPadding = MediaQuery.of(context).padding.top;
    final double bottomPadding = _readerBottomPadding(context);

    // 获取阅读背景色和文字色
    final readerBackgroundColor = _getReaderBackgroundColor(settings);
    final readerTextColor = _getReaderTextColor(settings);
    final readerLineHeight = settings.readerLineHeight;
    final readerParagraphSpacing = settings.readerParagraphSpacing;
    final readerSidePadding = settings.readerSidePadding;
    final openImagePreviewOnLongPress =
        settings.readerImagePreviewOpenOnLongPress;

    // Route B：布局信息在加载章节时基于 blocks 预计算并缓存，避免 build 时反复 parse。
    final layoutInfo = _layoutInfo;

    // 基础 padding 计算
    final EdgeInsets padding =
        layoutInfo.mode == _ReaderLayoutMode.center
            ? EdgeInsets.zero
            : EdgeInsets.fromLTRB(
              0,
              (layoutInfo.mode == _ReaderLayoutMode.immersive ||
                      layoutInfo.startsWithImage)
                  ? 0
                  : topPadding + 20,
              0,
              layoutInfo.endsWithImage ? 0 : 56.0 + bottomPadding,
            );

    // 自定义样式构建器
    // 自定义样式构建器
    // ignore: unused_element
    Map<String, String>? customStylesBuilder(dom.Element element) {
      // 1. 处理浮动类名 (Common in Web novels)
      if (element.classes.contains('fr')) {
        return {'float': 'right', 'margin-left': '0.5em', 'padding': '0'};
      }
      if (element.classes.contains('fl')) {
        return {'float': 'left', 'margin-right': '0.5em', 'padding': '0'};
      }

      // 2. 图片本身样式
      if (element.localName == 'img') {
        // 检查自身或父级是否有浮动属性
        final parent = element.parent;
        // 如果图片自身有浮动属性，或者父级有 fr/fl 类，则不进行全宽处理
        if (element.attributes['align']?.isNotEmpty == true ||
            element.attributes['style']?.contains('float') == true ||
            element.classes.contains('fr') ||
            element.classes.contains('fl') ||
            (parent != null &&
                (parent.classes.contains('fr') ||
                    parent.classes.contains('fl')))) {
          return null;
        }

        // 普通插图：强制满宽
        return {
          'width': '100%',
          'height': 'auto',
          'margin': '0',
          'padding': '0',
          'display': 'block',
        };
      }

      // 3. 容器样式 (p, div, h1-h6, center 等)
      final textTags = {
        'p',
        'div',
        'h1',
        'h2',
        'h3',
        'h4',
        'h5',
        'h6',
        'center',
      };
      if (textTags.contains(element.localName)) {
        bool isFootnoteMarkerImage(dom.Element img) {
          // 多看脚注的小图标通常为 <img class="footnote" .../>
          if (img.classes.contains('footnote')) return true;

          // 常见结构：<a.duokan-footnote><sup><img .../></sup></a>
          // 若该 img 位于 a.duokan-footnote 内，则视为脚注 marker，不应触发“插图段落”样式。
          dom.Element? p = img.parent;
          while (p != null) {
            if (p.localName == 'a' && p.classes.contains('duokan-footnote')) {
              return true;
            }
            p = p.parent;
          }
          return false;
        }

        final hasIllustrationImage = element
            .getElementsByTagName('img')
            .any((img) => !isFootnoteMarkerImage(img));

        // 如果包含插图图片，则认为是插图容器，取消默认 padding
        if (hasIllustrationImage) {
          return {
            'margin': '0',
            'padding': '0',
            'line-height': '0',
            'text-align': 'center', // 图片居中
          };
        }

        // 纯文本容器：添加两侧 padding
        final style = {
          'padding-left': _formatReaderPixelValue(readerSidePadding),
          'padding-right': _formatReaderPixelValue(readerSidePadding),
          'margin-bottom': '1em',
          'line-height': readerLineHeight.toStringAsFixed(1),
          'text-align': 'left', // 强制左对齐
        };

        // 处理特殊类名
        if (element.classes.contains('center')) {
          // 如果本身带 center 类，我们依然维持逻辑，但给予边距
        }

        return style;
      }

      if (element.localName == 'body') {
        return {
          'margin': '0',
          'padding': '0',
          'line-height': readerLineHeight.toStringAsFixed(1),
        };
      }
      return null;
    }

    // 通用 Widget 构建器 (图片缓存)
    Map<String, String>? readerCustomStylesBuilder(dom.Element element) {
      void mergeStyle(
        Map<String, String> target,
        Map<String, String>? incoming,
      ) {
        if (incoming != null && incoming.isNotEmpty) {
          target.addAll(incoming);
        }
      }

      if (element.localName == 'img') {
        final style = <String, String>{};
        mergeStyle(style, _buildReaderPresetClassStyles(element));
        style['border-radius'] = '3px';
        final isInsideTable = _isInsideTableStructure(element);
        final isInsideIllustration = _isInsideIllustrationContainer(element);

        final parent = element.parent;
        final parentTag = parent?.localName;
        final inlineStyle = (element.attributes['style'] ?? '').toLowerCase();
        final isFloating =
            element.attributes['align']?.isNotEmpty == true ||
            inlineStyle.contains('float') ||
            element.classes.contains('fr') ||
            element.classes.contains('fl') ||
            (parent != null &&
                (parent.classes.contains('fr') ||
                    parent.classes.contains('fl')));
        if (isFloating) {
          return style.isEmpty ? null : style;
        }

        if (isInsideIllustration) {
          style.addAll({
            'width': 'auto',
            'height': 'auto',
            'max-width': '100%',
            'display': 'inline-block',
            'margin': '0',
            'padding': '0',
          });
          return style;
        }

        if (isInsideTable) {
          style.addAll({
            'width': 'auto',
            'height': 'auto',
            'display': 'inline-block',
            'margin': '0',
            'padding': '0',
          });
          return style;
        }

        style.addAll({
          'width': 'auto',
          'height': 'auto',
          'max-width': '100%',
          'margin':
              parentTag == 'p' ||
                      parentTag == 'div' ||
                      parentTag == 'blockquote'
                  ? '0 5px'
                  : '0',
          'padding': '0',
          'display': 'inline-block',
        });
        return style;
      }

      final style = <String, String>{};
      mergeStyle(
        style,
        _buildReaderBlockTagStyles(
          element,
          readerLineHeight,
          readerSidePadding,
        ),
      );
      mergeStyle(style, _buildReaderPresetClassStyles(element));
      return style.isEmpty ? null : style;
    }

    Widget? customWidgetBuilder(dom.Element element) {
      // 0) 脚注/注释触发点（对标 Web: a.duokan-footnote）
      // Web 用 <a.duokan-footnote href="#noteX"><sup><img class="footnote" .../></sup></a>
      // App 直接拦截 <a.duokan-footnote>，替换为 Flutter 原生图标 + Popover，避免 img 加载失败。
      if (element.localName == 'a' &&
          element.classes.contains('duokan-footnote')) {
        final rawId =
            element.attributes['data-footnote-id'] ??
            (element.attributes['href']?.startsWith('#') == true
                ? element.attributes['href']!.substring(1)
                : null);

        final footnoteId = (rawId ?? '').trim();
        final noteHtml =
            footnoteId.isNotEmpty ? _footnoteNotesById[footnoteId] : null;

        return _FootnoteAnchor(
          key: ValueKey('footnote_${footnoteId}_${_chapter?.id ?? 0}'),
          footnoteId: footnoteId,
          noteHtml: noteHtml,
          baseFontSize: settings.fontSize,
          lineHeight: readerLineHeight,
          fontFamily: _fontFamily,
          readerBackgroundColor: readerBackgroundColor,
          readerTextColor: readerTextColor,
        );
      }

      final illustrationWidget = _buildIllustrationContainerWidget(
        element,
        readerTextColor,
        readerSidePadding,
        openImagePreviewOnLongPress,
      );
      if (illustrationWidget != null) {
        return illustrationWidget;
      }

      if (element.localName == 'img') {
        final src = element.attributes['src'];

        // 脚注图标已由上面的 a.duokan-footnote 拦截；这里不再单独处理 img.footnote。

        if (src != null && src.isNotEmpty) {
          // 检查是否在浮动容器中 (向上查找 3 层)
          bool isFloating = false;
          bool isFloatRight = false;
          final isInsideTable = _isInsideTableStructure(element);
          final isInsideIllustration = _isInsideIllustrationContainer(element);
          final isPreviewable = _isPreviewableReaderImage(element);
          final parentTag = element.parent?.localName;
          dom.Element? current = element;
          for (int i = 0; i < 3; i++) {
            if (current == null) break;

            final style = current.attributes['style'] ?? '';
            final align = current.attributes['align'] ?? '';
            final classes = current.classes;

            if (style.contains('float: right') ||
                align == 'right' ||
                classes.contains('fr')) {
              isFloating = true;
              isFloatRight = true;
              break;
            }

            if (style.contains('float: left') ||
                align == 'left' ||
                classes.contains('fl')) {
              isFloating = true;
              isFloatRight = false;
              break;
            }
            current = current.parent;
          }

          if (!isFloating && !isInsideTable && !isInsideIllustration) {
            double? parseDimension(String? rawValue) {
              if (rawValue == null) {
                return null;
              }
              final trimmed = rawValue.trim();
              if (trimmed.isEmpty) {
                return null;
              }
              return double.tryParse(trimmed);
            }

            final width = parseDimension(element.attributes['width']);
            final height = parseDimension(element.attributes['height']);
            final horizontalMargin =
                parentTag == 'p' ||
                        parentTag == 'div' ||
                        parentTag == 'blockquote'
                    ? 5.0
                    : 0.0;

            return InlineCustomWidget(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: Builder(
                builder: (context) {
                  final maxWidth =
                      MediaQuery.sizeOf(context).width - readerSidePadding * 2;
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalMargin),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        clipBehavior: Clip.antiAlias,
                        child: CachedNetworkImage(
                          imageUrl: src,
                          memCacheWidth: 1080,
                          width: width,
                          height: height,
                          fit: BoxFit.contain,
                          placeholder:
                              (context, url) => SizedBox(
                                width: width ?? 40,
                                height: height ?? 40,
                                child: const Center(
                                  child: M3ELoadingIndicator(size: 16),
                                ),
                              ),
                          errorWidget:
                              (context, url, error) => SizedBox(
                                width: width ?? 40,
                                height: height ?? 40,
                                child: Icon(
                                  Icons.broken_image,
                                  color: readerTextColor.withValues(alpha: 0.3),
                                  size: 18,
                                ),
                              ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          }

          final cachedRatio =
              _prefs?.getDouble('image_ratio_$src') ??
              _imageAspectRatioCache[src];

          // 为了保持无缝图片加载而不丢失懒加载特性
          // 如果还没有此图片的缓存比例，用 Image 监听其加载，并在获得宽高后回填
          if (cachedRatio == null) {
            final imageProvider = CachedNetworkImageProvider(src);
            imageProvider
                .resolve(const ImageConfiguration())
                .addListener(
                  ImageStreamListener((info, _) {
                    if (!mounted) return;
                    final width = info.image.width.toDouble();
                    final height = info.image.height.toDouble();
                    if (height > 0) {
                      final ratio = width / height;
                      _imageAspectRatioCache[src] = ratio;
                      _prefs?.setDouble('image_ratio_$src', ratio);
                      // 只有没被包裹 AspectRatio 的时候才抛出刷新，以让占位即刻拥有真实高度
                      if (mounted) setState(() {});
                    }
                  }),
                );
          }

          Widget buildPlaceholder({required bool isError}) {
            if (isFloating) {
              // 浮动小图（头像/角标等）不使用大占位，避免挤占过多空间
              final height = isError ? 56.0 : 72.0;
              return Container(
                height: height,
                width: height,
                color: readerTextColor.withValues(alpha: 0.05),
                alignment: Alignment.center,
                child:
                    isError
                        ? Icon(
                          Icons.broken_image,
                          color: readerTextColor.withValues(alpha: 0.3),
                          size: 22,
                        )
                        : const M3ELoadingIndicator(size: 18),
              );
            }

            // 如果已经有了真实比例缓存，我们就用真实比例
            // 如果尚无真实比例，则暂时不使用外包裹高度防止拉伸（因为 ImageStream 正在后台加载并会在不久后触发 setState）
            if (isInsideTable) {
              return SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child:
                      isError
                          ? Icon(
                            Icons.broken_image,
                            color: readerTextColor.withValues(alpha: 0.3),
                            size: 20,
                          )
                          : const M3ELoadingIndicator(size: 18),
                ),
              );
            }

            Widget indicator = Center(
              child:
                  isError
                      ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            color: readerTextColor.withValues(alpha: 0.3),
                            size: 40,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '加载失败',
                            style: TextStyle(
                              color: readerTextColor.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      )
                      : const M3ELoadingIndicator(size: 20),
            );

            if (cachedRatio != null) {
              return AspectRatio(aspectRatio: cachedRatio, child: indicator);
            }
            // 返回一个较为中庸的通用保底
            return AspectRatio(aspectRatio: 1 / 1.6, child: indicator);
          }

          Widget imageWidget = StatefulBuilder(
            builder: (context, setState) {
              final isShown = _shownImages.contains(src);

              // Route B：正文已虚拟化（仅构建视口附近 blocks），此处不再需要额外的 VisibilityDetector。
              // 直接展示图片（CachedNetworkImage 自带异步加载与占位），同时保留比例占位以稳定布局。
              if (!isShown) {
                _shownImages.add(src);
              }

              // 显示之后，返回原本的网络图片容器
              return CachedNetworkImage(
                imageUrl: src,
                memCacheWidth: 1080, // 阅读页插画限定在主流屏幕物理宽度，防止解析4K竖屏超长图导致 OOM
                placeholder: (context, url) => buildPlaceholder(isError: false),
                errorWidget:
                    (context, url, error) => buildPlaceholder(isError: true),
                fit: BoxFit.contain,
                // 如果是浮动元素，强制限制宽度 (避免过大)
                width: (isFloating || isInsideTable) ? null : double.infinity,
              );
            },
          );

          // 核心方案：如果在缓存中取到了真实比例，用 AspectRatio 死死地锁住图片
          // 这能保证即便这部分并未进入视图而被懒加载剔除骨架，SliverList 的估算也能精准无比！
          imageWidget = ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: imageWidget,
          );

          if (cachedRatio != null && !isFloating && !isInsideTable) {
            imageWidget = AspectRatio(
              aspectRatio: cachedRatio,
              child: imageWidget,
            );
          }

          if (isFloating) {
            // 针对浮动图片的专门处理：
            // 1. 强制对齐 (Align)
            // 2. 限制最大宽度 (ConstrainedBox)，防止原图过大撑满屏幕
            return Align(
              alignment:
                  isFloatRight ? Alignment.centerRight : Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 160, // 限制最大宽度，不管是头像还是角标，160dp 足够了
                ),
                child: imageWidget,
              ),
            );
          }

          if (isInsideTable) {
            return Builder(
              builder: (context) {
                final maxWidth = (MediaQuery.sizeOf(context).width -
                        readerSidePadding * 2)
                    .clamp(48.0, double.infinity);
                return ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: imageWidget,
                );
              },
            );
          }

          if (isPreviewable) {
            final alt = element.attributes['alt'];
            return Builder(
              builder: (context) {
                return ReaderImagePreviewGesture(
                  imageUrl: src,
                  alt: alt,
                  openOnLongPress: openImagePreviewOnLongPress,
                  child: imageWidget,
                );
              },
            );
          }

          return imageWidget;
        }
      }
      return null;
    }

    Widget content;

    content = LayoutBuilder(
      builder: (context, constraints) {
        final result = _blocksResult;
        final blocks = result?.blocks ?? const <_ReaderBlock>[];

        if (blocks.isEmpty) {
          return const Center(child: M3ELoadingIndicator());
        }

        // 单张图居中模式：不走 ScrollablePositionedList（无界高度下 Align 无法垂直居中），
        // 直接用视口高度 + Center 实现真正的垂直居中。
        if (layoutInfo.mode == _ReaderLayoutMode.center && blocks.length == 1) {
          final blockHtml = _getRenderedBlockHtml(blocks.first, settings);
          return SizedBox(
            height: constraints.maxHeight,
            child: Center(
              child: HtmlWidget(
                blockHtml,
                textStyle: TextStyle(
                  fontFamily: _fontFamily,
                  fontSize: settings.fontSize,
                  height: readerLineHeight,
                  color: readerTextColor,
                ),
                customStylesBuilder: readerCustomStylesBuilder,
                customWidgetBuilder: customWidgetBuilder,
              ),
            ),
          );
        }

        return NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: ScrollablePositionedList.builder(
            itemScrollController: _itemScrollController,
            itemPositionsListener: _itemPositionsListener,
            itemCount: blocks.length,
            padding: padding,
            itemBuilder: (context, index) {
              final block = blocks[index];
              final blockHtml = _getRenderedBlockHtml(block, settings);
              final topSpacing =
                  index > 0 &&
                          _blockUsesReaderParagraphSpacing(blocks[index - 1])
                      ? readerParagraphSpacing
                      : 0.0;

              return Padding(
                padding: EdgeInsets.only(top: topSpacing),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: HtmlWidget(
                    blockHtml,
                    textStyle: TextStyle(
                      fontFamily: _fontFamily,
                      fontSize: settings.fontSize,
                      height: readerLineHeight,
                      color: readerTextColor,
                    ),
                    customStylesBuilder: readerCustomStylesBuilder,
                    customWidgetBuilder: customWidgetBuilder,
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    // 包裹背景色容器
    return Container(
      color: readerBackgroundColor, // 应用阅读背景色
      child: content,
    );
  }

  /// 预处理章节 HTML：抽离脚注/注释内容并从正文中移除，避免注释直接跟在文字后面。
  ///
  /// 对标 Web 端：
  /// - 遍历 `.duokan-footnote` 获取 href 的 id
  /// - 从 DOM 中找到对应 id 的注释节点并隐藏/移除，同时缓存其 innerHTML
  /// - 禁用默认跳转（移除 href），后续由 Flutter 的 Popover 交互接管
  _FootnoteProcessingResult _processFootnotes(String html) {
    if (html.isEmpty) {
      return const _FootnoteProcessingResult(html: '', notesById: {});
    }

    try {
      final doc = html_parser.parse(html);

      final Map<String, String> notesById = {};

      String shortenForLog(String input, {int max = 420}) {
        final normalized =
            input
                .replaceAll('\u200B', '')
                .replaceAll('\r', '')
                .replaceAll('\n', ' ')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim();
        if (normalized.length <= max) return normalized;
        return '${normalized.substring(0, max)}…';
      }

      String? findSnippet(String raw, String token, {int radius = 140}) {
        final idx = raw.indexOf(token);
        if (idx < 0) return null;
        final start = (idx - radius).clamp(0, raw.length).toInt();
        final end = (idx + token.length + radius).clamp(0, raw.length).toInt();
        return raw.substring(start, end);
      }

      // 说明（对标 Web）：
      // Web 直接用 `document.getElementById(id)` 获取注释节点并读取 `innerHTML`。
      // 但服务端内容偶尔会出现“重复 id / 嵌套 id”（例如：
      // <li id="x"><a id="x">到</a>译注：日本的高龄驾驶标志</li>）。
      // 浏览器在重复 id 情况下会返回文档序中更靠前（通常是外层 li）的元素；
      // 而 `package:html` 的 `getElementById` 在重复 id 时可能返回内层 a，导致只取到“到”。
      //
      // 为了对齐 Web 行为，这里手动遍历 DOM（文档序）建立 id/name 索引，并优先选择“文本最多”的元素。

      String normalizeText(String text) {
        // 去掉我们注入的零宽空格，避免干扰长度判断
        return text.replaceAll('\u200B', '').trim();
      }

      int textScore(dom.Element el) {
        return normalizeText(el.text).length;
      }

      bool isPreferredNoteContainerTag(String? tag) {
        const preferredTags = {
          'li',
          'p',
          'div',
          'section',
          'aside',
          'blockquote',
          'dd',
        };
        return preferredTags.contains(tag);
      }

      dom.Element promoteNoteContainer(dom.Element element) {
        var container = element;
        while (true) {
          final parent = container.parent;
          if (parent is! dom.Element) {
            break;
          }

          final parentTag = parent.localName;
          final containerTag = container.localName;
          final containerScore = textScore(container);
          final parentScore = textScore(parent);
          final shouldPromote =
              (!isPreferredNoteContainerTag(containerTag) ||
                  containerScore <= 2) &&
              isPreferredNoteContainerTag(parentTag) &&
              parentScore > containerScore;
          if (!shouldPromote) {
            break;
          }
          container = parent;
        }
        return container;
      }

      int noteContainerPriority(dom.Element element) {
        if (isPreferredNoteContainerTag(element.localName)) {
          return 0;
        }
        const inlineAnchorTags = {'a', 'span', 'sup', 'sub'};
        if (inlineAnchorTags.contains(element.localName)) {
          return 2;
        }
        return 1;
      }

      String? attrValue(dom.Element el, String nameLower) {
        for (final entry in el.attributes.entries) {
          final keyLower = entry.key.toString().toLowerCase();
          if (keyLower == nameLower) return entry.value;
        }
        return null;
      }

      Iterable<dom.Element> walkElements(dom.Node node) sync* {
        if (node is dom.Element) {
          yield node;
        }
        for (final child in node.nodes) {
          yield* walkElements(child);
        }
      }

      // 文档序索引 id/name（不依赖 selector 引擎，避免大小写/重复 id 解析差异）
      final Map<String, List<dom.Element>> idIndex = {};
      final Map<String, List<dom.Element>> nameIndex = {};
      final root = doc.documentElement ?? doc;
      for (final el in walkElements(root)) {
        final idValue = attrValue(el, 'id');
        if (idValue != null && idValue.isNotEmpty) {
          (idIndex[idValue] ??= []).add(el);
        }
        final nameValue = attrValue(el, 'name');
        if (nameValue != null && nameValue.isNotEmpty) {
          (nameIndex[nameValue] ??= []).add(el);
        }
      }

      dom.Element? findBestNoteContainer(String id) {
        final candidates = <dom.Element>[
          ...(idIndex[id] ?? const []),
          ...(nameIndex[id] ?? const []),
        ];

        if (candidates.isEmpty) {
          // 最后兜底：保留原 getElementById 行为
          final fallback = doc.getElementById(id);
          return fallback == null ? null : promoteNoteContainer(fallback);
        }

        dom.Element? best;
        var bestScore = -1;
        var bestPriority = 1 << 30;
        var bestSize = 1 << 30;
        final seen = <dom.Element>{};
        for (final candidate in candidates) {
          final container = promoteNoteContainer(candidate);
          if (!seen.add(container)) {
            continue;
          }

          final score = textScore(container);
          final priority = noteContainerPriority(container);
          final size = container.outerHtml.length;
          final shouldUse =
              best == null ||
              score > bestScore ||
              (score == bestScore && priority < bestPriority) ||
              (score == bestScore &&
                  priority == bestPriority &&
                  size < bestSize);
          if (shouldUse) {
            best = container;
            bestScore = score;
            bestPriority = priority;
            bestSize = size;
          }
        }

        // Return the promoted container with the most visible note text.
        return best;
      }

      for (final a in doc.querySelectorAll('a.duokan-footnote')) {
        final href = a.attributes['href'];
        if (href == null || !href.startsWith('#') || href.length <= 1) {
          continue;
        }

        final id = href.substring(1);
        if (id.isEmpty) continue;

        final noteElement = findBestNoteContainer(id);
        if (noteElement != null) {
          // Web: content = noteElement.innerHTML
          // App：直接对齐 Web 行为，不做“按 id 移除子节点”的清理。
          // 说明：真实内容可能就在 <li id="noteX">...</li> 里，如果清理会把内容删光。
          final extractedHtml = noteElement.innerHtml.trim();
          final noteOuterHtmlForLog = shortenForLog(noteElement.outerHtml);

          notesById.putIfAbsent(id, () => extractedHtml);

          final extractedPreview = normalizeText(extractedHtml);
          if (extractedPreview.length <= 2) {
            final raw = html.replaceAll('\u200B', '');
            final snippetHref = findSnippet(raw, 'href="#$id"');
            final snippetId1 = findSnippet(raw, 'id="$id"');
            final snippetId2 = findSnippet(raw, "id='$id'");
            final snippetName1 = findSnippet(raw, 'name="$id"');
            final snippetName2 = findSnippet(raw, "name='$id'");

            // 候选元素概要（用于判断是否选错容器）
            final candidates = <dom.Element>[
              ...(idIndex[id] ?? const []),
              ...(nameIndex[id] ?? const []),
            ];
            final candidateSummary =
                candidates.isEmpty
                    ? '[]'
                    : candidates
                            .take(4)
                            .map(
                              (e) =>
                                  '${e.localName}:${textScore(e)}:${shortenForLog(e.outerHtml, max: 120)}',
                            )
                            .join(' | ') +
                        (candidates.length > 4
                            ? ' …(+${candidates.length - 4})'
                            : '');

            _logger.warning(
              'FOOTNOTE_EXTRACT_SHORT id=$id '
              'tag=${noteElement.localName} '
              'extracted="${shortenForLog(extractedHtml, max: 120)}" '
              'noteOuter="$noteOuterHtmlForLog" '
              'anchor="${shortenForLog(a.outerHtml, max: 180)}" '
              'candidates=$candidateSummary '
              'snipHref="${shortenForLog(snippetHref ?? '', max: 160)}" '
              'snipId="${shortenForLog(snippetId1 ?? snippetId2 ?? '', max: 160)}" '
              'snipName="${shortenForLog(snippetName1 ?? snippetName2 ?? '', max: 160)}"',
            );
          }

          // ⚠️ 极其重要：为了保持与 Web 端的 DOM 节点计数与结构绝对一致（保证双边生成的 XPath index 相同）
          // 我们必须如同 Web(style.display = 'none') 那样仅仅将其 CSS 隐藏。
          // 绝不能调用 remove()，否则后续所有标签的下标将发生毁灭性漂移！
          final currentStyle = noteElement.attributes['style'] ?? '';
          noteElement.attributes['style'] = '$currentStyle; display: none;';
        }

        // 禁用默认跳转行为，交由 Flutter 手势处理
        a.attributes['data-footnote-id'] = id;
        a.attributes.remove('href');

        // 清理脚注锚点内部的 <sup>/<img>，避免正文容器被误判为“包含图片”从而触发插图样式（居中/无 padding）。
        // 视觉由 Flutter 的 customWidgetBuilder 接管。
        a.innerHtml = '';
      }

      // 清理残留的脚注小图标（有些内容会把 marker 渲染成独立的 img.footnote）
      for (final img in doc.querySelectorAll('img.footnote')) {
        img.remove();
      }

      final processedHtml = doc.body?.innerHtml ?? html;
      return _FootnoteProcessingResult(
        html: processedHtml,
        notesById: notesById,
      );
    } catch (_) {
      // 解析失败则回退到原文
      return _FootnoteProcessingResult(html: html, notesById: const {});
    }
  }

  // ==================== 悬浮控件 ====================

  /// 悬浮顶部功能区
  Widget _buildFloatingTopBar(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final settings = ref.watch(settingsProvider);

    return Positioned(
      top: topPadding + 8,
      left: 12,
      right: 12,
      child: AnimatedBuilder(
        animation: _barsAnimController,
        builder: (context, child) {
          if (_barsAnimController.value == 0.0) {
            return const SizedBox.shrink();
          }

          final slideOffset = Tween<Offset>(
            begin: const Offset(0, -1.0), // 向上翻出隐藏
            end: Offset.zero,
          ).evaluate(
            CurvedAnimation(
              parent: _barsAnimController,
              curve: Curves.easeOutCubic,
            ),
          );

          return FractionalTranslation(
            translation: slideOffset,
            child: IgnorePointer(ignoring: !_barsVisible, child: child),
          );
        },
        child: Row(
          children: [
            // 返回按钮 - AdaptiveFloatingActionButton
            if (settings.useIOS26Style)
              SizedBox(
                width: 44,
                height: 44,
                child: AdaptiveButton.sfSymbol(
                  onPressed: () {
                    _exitReaderPage();
                  },
                  sfSymbol: const SFSymbol('chevron.left', size: 20),
                  style: AdaptiveButtonStyle.glass,
                  borderRadius: BorderRadius.circular(1000),
                  useSmoothRectangleBorder: false,
                  padding: EdgeInsets.zero,
                ),
              )
            else
              Builder(
                builder: (context) {
                  final settings = ref.watch(settingsProvider);
                  final colorScheme =
                      (settings.coverColorExtraction
                          ? _dynamicColorScheme
                          : null) ??
                      Theme.of(context).colorScheme;
                  return AdaptiveFloatingActionButton(
                    mini: true,
                    onPressed: () {
                      _exitReaderPage();
                    },
                    backgroundColor: colorScheme.primaryContainer,
                    foregroundColor: colorScheme.onPrimaryContainer,
                    child: Icon(
                      PlatformInfo.isIOS
                          ? CupertinoIcons.chevron_left
                          : Icons.arrow_back,
                      size: 20,
                    ),
                  );
                },
              ),
            const SizedBox(width: 12),

            // 章节信息卡片 - 根据标题长度动态收缩
            // 使用 Flexible + Center：允许收缩，且在剩余空间居中
            Flexible(
              child: Center(
                child: Builder(
                  builder: (context) {
                    // 根据阅读背景亮度动态计算文字颜色
                    final settings = ref.watch(settingsProvider);
                    final readerBgColor = _getReaderBackgroundColor(settings);
                    // computeLuminance 返回 0.0-1.0，越接近 1 越亮
                    final isLightBg = readerBgColor.computeLuminance() > 0.5;
                    final textColor = isLightBg ? Colors.black : Colors.white;
                    final subTextColor = textColor.withValues(alpha: 0.7);

                    return UniversalGlassPanel(
                      blurAmount: 15,
                      borderRadius: BorderRadius.circular(100),
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 140,
                        ), // 最小宽度
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.outlineVariant.withValues(alpha: 0.3),
                            width: 0.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 章节标题（支持简化 + 长标题跑马灯滚动 + 点击显示完整标题）
                            GestureDetector(
                              onTap: () {
                                if ((_chapter?.title.trim().isNotEmpty ??
                                        false) ||
                                    (widget.bookTitle?.trim().isNotEmpty ??
                                        false)) {
                                  unawaited(
                                    showReaderTitleSheet(
                                      context,
                                      bookId: widget.bid,
                                      bookTitle: widget.bookTitle,
                                      chapterTitle: _chapter?.title,
                                    ),
                                  );
                                }
                              },
                              child: _MarqueeText(
                                text: _getDisplayTitle(settings),
                                horizontalPadding: 16.0,
                                style: Theme.of(
                                  context,
                                ).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            // 阅读进度（clamp 确保 0-100%）
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 70, // 加宽以容纳长文本
                                    child: ValueListenableBuilder<String>(
                                      valueListenable: _timeStringNotifier,
                                      builder: (context, timeString, _) {
                                        return Text(
                                          timeString,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall?.copyWith(
                                            color: subTextColor,
                                            fontSize: 11,
                                            // height: 1,
                                          ),
                                          textAlign:
                                              TextAlign.right, // 靠右对齐，紧贴电量条
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ReaderBatteryIndicator(
                                    batteryLevelListenable:
                                        _batteryLevelNotifier,
                                    batteryStateListenable:
                                        _batteryStateNotifier,
                                    style:
                                        settings
                                            .effectiveReaderBatteryIndicatorStyle,
                                    color: subTextColor,
                                    textStyle: Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.copyWith(
                                      color: subTextColor,
                                      fontSize: 11,
                                      height: 1,
                                    ),
                                  ),

                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 70, // 保持对称
                                    child: ValueListenableBuilder<double>(
                                      valueListenable: _readProgressNotifier,
                                      builder: (context, value, _) {
                                        final percent =
                                            (value.clamp(0.0, 1.0) * 100)
                                                .round()
                                                .clamp(0, 100)
                                                .toInt();
                                        return Text(
                                          '已读 $percent%',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall?.copyWith(
                                            color: subTextColor,
                                            fontSize: 11,
                                            // height: 1,
                                          ),
                                          textAlign: TextAlign.left,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),

            // 更多菜单按钮（章节列表 + 阅读背景）
            if (Platform.isIOS || Platform.isMacOS)
              AdaptivePopupMenuButton.icon<String>(
                icon:
                    settings.useIOS26Style
                        ? 'ellipsis'
                        : CupertinoIcons.ellipsis,
                buttonStyle: PopupButtonStyle.glass,
                items: [
                  AdaptivePopupMenuItem(
                    label: '章节列表',
                    icon:
                        settings.useIOS26Style
                            ? 'list.bullet'
                            : CupertinoIcons.list_bullet,
                    value: 'chapters',
                  ),
                  AdaptivePopupMenuItem(
                    label: '阅读背景',
                    icon:
                        settings.useIOS26Style
                            ? 'paintbrush'
                            : CupertinoIcons.paintbrush,
                    value: 'background',
                  ),
                ],
                onSelected: (index, item) {
                  switch (item.value) {
                    case 'chapters':
                      _showChapterListSheet(context);
                      break;
                    case 'background':
                      unawaited(_openReaderBackgroundPage());
                      break;
                  }
                },
              )
            else
              Builder(
                builder: (context) {
                  // 根据阅读背景亮度动态计算图标颜色
                  final settings = ref.watch(settingsProvider);
                  final readerBgColor = _getReaderBackgroundColor(settings);
                  final isLightBg = readerBgColor.computeLuminance() > 0.5;
                  final iconColor = isLightBg ? Colors.black : Colors.white;

                  return PopupMenuButton<String>(
                    icon: Icon(Icons.more_horiz, color: iconColor),
                    itemBuilder: (context) {
                      final colorScheme = Theme.of(context).colorScheme;
                      return [
                        PopupMenuItem(
                          value: 'chapters',
                          child: Row(
                            children: [
                              Icon(
                                Icons.list,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 12),
                              const Text('章节列表'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'background',
                          child: Row(
                            children: [
                              Icon(
                                Icons.palette_outlined,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 12),
                              const Text('阅读背景'),
                            ],
                          ),
                        ),
                      ];
                    },
                    onSelected: (value) {
                      switch (value) {
                        case 'chapters':
                          _showChapterListSheet(context);
                          break;
                        case 'background':
                          unawaited(_openReaderBackgroundPage());
                          break;
                      }
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  /// 悬浮底部功能区（上下章导航）
  Widget _buildFloatingBottomControls(BuildContext context) {
    final bottomPadding = _readerBottomPadding(context);
    final settings = ref.watch(settingsProvider);

    return Positioned(
      right: 16,
      bottom: bottomPadding + 24,
      child: AnimatedBuilder(
        animation: _barsAnimController,
        builder: (context, child) {
          if (_barsAnimController.value == 0.0) {
            return const SizedBox.shrink();
          }

          // 使用 Tween 仅实现滑动效果 (从 offset x: 1.5 到 0)，不再使用 Opacity
          final slideOffset = Tween<Offset>(
            begin: const Offset(1.5, 0),
            end: Offset.zero,
          ).evaluate(
            CurvedAnimation(
              parent: _barsAnimController,
              curve: Curves.easeOutCubic,
            ),
          );

          return FractionalTranslation(
            translation: slideOffset,
            child: IgnorePointer(ignoring: !_barsVisible, child: child),
          );
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 上一章
            if (settings.useIOS26Style)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(1000),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: AdaptiveButton.sfSymbol(
                  key: ValueKey('prev_btn_${_targetSortNum > 1}'),
                  onPressed: _targetSortNum > 1 ? _onPrev : null,
                  sfSymbol: const SFSymbol('chevron.left', size: 20),
                  style: AdaptiveButtonStyle.glass,
                  borderRadius: BorderRadius.circular(1000),
                  useSmoothRectangleBorder: false,
                  padding: EdgeInsets.zero,
                ),
              )
            else
              Builder(
                builder: (context) {
                  final settings = ref.watch(settingsProvider);
                  final colorScheme =
                      (settings.coverColorExtraction
                          ? _dynamicColorScheme
                          : null) ??
                      Theme.of(context).colorScheme;
                  return AdaptiveFloatingActionButton(
                    mini: true,
                    onPressed: _targetSortNum > 1 ? _onPrev : null,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    foregroundColor: colorScheme.onSurfaceVariant,
                    elevation: 0,
                    child: const Icon(Icons.chevron_left),
                  );
                },
              ),
            const SizedBox(width: 12),
            // 下一章
            if (settings.useIOS26Style)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(1000),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: AdaptiveButton.sfSymbol(
                  key: ValueKey(
                    'next_btn_${_targetSortNum < widget.totalChapters}',
                  ),
                  onPressed:
                      _targetSortNum < widget.totalChapters ? _onNext : null,
                  sfSymbol: const SFSymbol('chevron.right', size: 20),
                  style: AdaptiveButtonStyle.glass,
                  borderRadius: BorderRadius.circular(1000),
                  useSmoothRectangleBorder: false,
                  padding: EdgeInsets.zero,
                ),
              )
            else
              Builder(
                builder: (context) {
                  final settings = ref.watch(settingsProvider);
                  final colorScheme =
                      (settings.coverColorExtraction
                          ? _dynamicColorScheme
                          : null) ??
                      Theme.of(context).colorScheme;
                  return AdaptiveFloatingActionButton(
                    mini: true,
                    onPressed:
                        _targetSortNum < widget.totalChapters ? _onNext : null,
                    backgroundColor: colorScheme.primaryContainer,
                    foregroundColor: colorScheme.onPrimaryContainer,
                    child: Icon(
                      PlatformInfo.isIOS
                          ? CupertinoIcons.chevron_right
                          : Icons.chevron_right,
                      size: 20,
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  /// 章节列表底部弹窗
  Future<void> _showChapterListSheet(BuildContext context) async {
    await showReaderChapterListSheet(
      context,
      bookId: widget.bid,
      currentSortNum: _chapter?.sortNum ?? _targetSortNum,
      onSelected: (sortNum) {
        if (sortNum == _chapter?.sortNum) {
          return;
        }
        setState(() {
          _targetSortNum = sortNum;
        });
        _loadChapter(
          widget.bid,
          sortNum,
          openPosition: _ReaderChapterOpenPosition.start,
        );
      },
    );
  }
  /*
    var chapters = BookDetailPageState.cachedChapterList;

    // 如果没有缓存（直接进入阅读页的情况），尝试重新获取
    if (chapters == null || chapters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('正在加载章节列表...'),
          duration: Duration(seconds: 1),
        ),
      );

      try {
        final bookInfo = await _bookService.getBookInfo(widget.bid);
        if (bookInfo.chapters.isNotEmpty) {
          chapters = bookInfo.chapters;
          // 更新缓存，以便下次不用再加载
          BookDetailPageState.cachedChapterList = bookInfo.chapters;
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('加载章节列表失败: $e')));
        }
        return;
      }
    }

    if (chapters == null || chapters.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('暂无章节信息')));
      }
      return;
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;
        // 创建非空局部变量，避免 Dart 闭包中的 null 检查问题
        final chapterList = chapters!;

        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.6,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Text(
                    '章节列表',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // 副标题
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    '共 ${chapterList.length} 章 · 当前第 ${_chapter?.sortNum ?? 0} 章',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                // 章节列表
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: chapterList.length,
                    itemBuilder: (context, index) {
                      final chapter = chapterList[index];
                      final sortNum = index + 1;
                      final isCurrentChapter = sortNum == _chapter?.sortNum;

                      return ListTile(
                        // 移除 leading，改用 Row 在 title 中布局以保证对齐
                        title: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            SizedBox(
                              width: 40,
                              child: Text(
                                '$sortNum',
                                textAlign: TextAlign.center,
                                style: textTheme.bodyLarge?.copyWith(
                                  color:
                                      isCurrentChapter
                                          ? colorScheme.primary
                                          : colorScheme.onSurfaceVariant,
                                  fontWeight:
                                      isCurrentChapter ? FontWeight.bold : null,
                                  height: 1.0, // 强制行高一致，减少字体度量差异的影响
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                chapter.title,
                                style: textTheme.bodyLarge?.copyWith(
                                  color:
                                      isCurrentChapter
                                          ? colorScheme.primary
                                          : null,
                                  fontWeight:
                                      isCurrentChapter ? FontWeight.bold : null,
                                  height: 1.0, // 强制行高一致
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        trailing:
                            isCurrentChapter
                                ? Icon(
                                  Icons.play_arrow,
                                  color: colorScheme.primary,
                                )
                                : null,
                        onTap: () {
                          Navigator.pop(context);
                          if (sortNum != _chapter?.sortNum) {
                            setState(() {
                              _targetSortNum = sortNum;
                            });
                            _loadChapter(
                              widget.bid,
                              sortNum,
                              openPosition: _ReaderChapterOpenPosition.start,
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 获取当前显示用的章节标题（根据设置可能简化）。
*/

  String _getDisplayTitle(AppSettings settings) {
    if (_loading) return '加载中';
    String title = _chapter?.title ?? '';
    if (title.isNotEmpty &&
        settings.isCleanChapterTitleEnabled(
          AppSettings.cleanChapterTitleReaderTitleScope,
        )) {
      title = simplifyReaderChapterTitle(title);
    }
    return title;
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(_error ?? '未知错误', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed:
                () => _loadChapter(
                  widget.bid,
                  _targetSortNum,
                  openPosition: _ReaderChapterOpenPosition.saved,
                ),
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

/// 阅读页脚注/注释触发器：用 Flutter 原生图标替代 Web 的脚注小图片，并点击弹出 Popover。
class _FootnoteAnchor extends StatefulWidget {
  final String footnoteId;
  final String? noteHtml;
  final double baseFontSize;
  final double lineHeight;
  final String? fontFamily;
  final Color readerBackgroundColor;
  final Color readerTextColor;

  const _FootnoteAnchor({
    super.key,
    required this.footnoteId,
    required this.noteHtml,
    required this.baseFontSize,
    required this.lineHeight,
    required this.fontFamily,
    required this.readerBackgroundColor,
    required this.readerTextColor,
  });

  static void dismissCurrent() {
    _FootnoteAnchorState._currentOpen?._removeOverlay();
  }

  @override
  State<_FootnoteAnchor> createState() => _FootnoteAnchorState();
}

class _FootnoteAnchorState extends State<_FootnoteAnchor>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static _FootnoteAnchorState? _currentOpen;

  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      reverseDuration: const Duration(milliseconds: 120),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _removeOverlay(animate: false);
    _fadeController.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_overlayEntry != null) {
      _removeOverlay();
      return;
    }

    // 确保同一时间只展示一个 Popover
    if (_currentOpen != null && _currentOpen != this) {
      _currentOpen!._removeOverlay();
    }
    _currentOpen = this;
    _showOverlay();
  }

  void _showOverlay() {
    if (!mounted) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final anchorTopLeft = renderBox.localToGlobal(Offset.zero);
    final anchorSize = renderBox.size;

    final media = MediaQuery.of(context);
    final screenSize = media.size;
    final paddingTop = media.padding.top;
    final paddingBottom = media.padding.bottom;

    final spaceBelow =
        screenSize.height -
        (anchorTopLeft.dy + anchorSize.height) -
        paddingBottom;
    final spaceAbove = anchorTopLeft.dy - paddingTop;
    final showBelow = spaceBelow >= 140 || spaceBelow >= spaceAbove;

    final maxWidth = (screenSize.width * 0.9).clamp(0.0, 420.0);
    final maxHeight = (screenSize.height * 0.35).clamp(0.0, 320.0);

    // 将 Popover 水平居中于触发点，必要时微调避免越界
    final anchorCenterX = anchorTopLeft.dx + anchorSize.width / 2;
    final idealLeft = anchorCenterX - maxWidth / 2;
    const horizontalMargin = 12.0;
    final clampedLeft = idealLeft.clamp(
      horizontalMargin,
      screenSize.width - maxWidth - horizontalMargin,
    );
    final dx = clampedLeft - idealLeft;

    _isClosing = false;
    _fadeController.stop();
    _fadeController.value = 0.0;

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        return Stack(
          children: [
            // 点击空白处消失
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _removeOverlay,
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor:
                  showBelow ? Alignment.bottomCenter : Alignment.topCenter,
              followerAnchor:
                  showBelow ? Alignment.topCenter : Alignment.bottomCenter,
              offset: Offset(dx, showBelow ? 8 : -8),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Material(
                  color: Colors.transparent,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: maxWidth,
                        maxHeight: maxHeight,
                      ),
                      child: _buildPopoverContent(context),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    final overlay = Overlay.of(context, rootOverlay: true);
    overlay.insert(_overlayEntry!);

    _fadeController.forward();
  }

  /// 规范化脚注 HTML：去掉返回引用空链接，并在存在列表结构时扁平化为纯内容。
  ///
  /// 目标：避免 flutter_widget_from_html 对 <ol>/<li> 的 marker 渲染产生残留符号（如只剩一个“.”）。
  String _normalizeFootnoteHtml(String html) {
    try {
      final doc = html_parser.parse('<div id="__root__">$html</div>');
      final root = doc.getElementById('__root__');
      if (root == null) return html;

      // 移除形如：<a href="#note_refX"></a>
      for (final a in root.querySelectorAll('a')) {
        if (a.text.trim().isEmpty && a.children.isEmpty) {
          a.remove();
        }
      }

      // 若包含列表项，则直接抽取 li 内容（对标 Web 的 list-style:none，且更稳妥）
      final items =
          root
              .querySelectorAll('li')
              .map((e) => e.innerHtml.trim())
              .where((s) => s.isNotEmpty)
              .toList();
      if (items.isNotEmpty) {
        return items.map((s) => '<div>$s</div>').join();
      }

      return root.innerHtml.trim();
    } catch (_) {
      return html;
    }
  }

  Widget _buildPopoverContent(BuildContext context) {
    final bgColor = Color.alphaBlend(
      widget.readerTextColor.withValues(alpha: 0.08),
      widget.readerBackgroundColor,
    );

    final borderColor = widget.readerTextColor.withValues(alpha: 0.18);

    final noteHtml = widget.noteHtml;
    final normalizedHtml =
        (noteHtml != null && noteHtml.trim().isNotEmpty)
            ? _normalizeFootnoteHtml(noteHtml)
            : null;
    final content =
        (normalizedHtml != null && normalizedHtml.trim().isNotEmpty)
            ? HtmlWidget(
              normalizedHtml,
              textStyle: TextStyle(
                fontFamily: widget.fontFamily,
                fontSize: (widget.baseFontSize * 0.95).clamp(12.0, 18.0),
                height: widget.lineHeight,
                color: widget.readerTextColor,
              ),
              customStylesBuilder: (element) {
                // 对标 Web: .note-style ol { list-style: none; margin:0; padding:10px }
                if (element.localName == 'ol' || element.localName == 'ul') {
                  return {
                    // flutter_widget_from_html 对 shorthand 的支持不稳定，显式使用 list-style-type
                    'list-style-type': 'none',
                    'margin': '0',
                    'padding': '0',
                    'padding-left': '0',
                  };
                }
                if (element.localName == 'li') {
                  return {
                    'list-style-type': 'none',
                    'margin': '0',
                    'padding': '0',
                  };
                }
                // 脚注内容里常见的“返回引用”空链接：<a href="#note_refX"></a>
                // Web 里存在但视觉上不展示；这里直接隐藏，避免多余的空白/符号。
                if (element.localName == 'a') {
                  final text = element.text.trim();
                  if (text.isEmpty && element.children.isEmpty) {
                    return {'display': 'none'};
                  }
                }
                if (element.localName == 'p') {
                  return {'margin': '0', 'padding': '0'};
                }
                return null;
              },
            )
            : Text(
              '未找到注释内容',
              style: TextStyle(
                fontFamily: widget.fontFamily,
                fontSize: (widget.baseFontSize * 0.95).clamp(12.0, 18.0),
                height: widget.lineHeight,
                color: widget.readerTextColor.withValues(alpha: 0.7),
              ),
            );

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Scrollbar(
          thumbVisibility: false,
          child: SingleChildScrollView(child: content),
        ),
      ),
    );
  }

  void _removeOverlay({bool animate = true}) {
    final entry = _overlayEntry;
    if (entry == null) return;

    if (!animate) {
      entry.remove();
      _overlayEntry = null;
      _isClosing = false;
      _fadeController.stop();
      _fadeController.value = 0.0;
      if (_currentOpen == this) {
        _currentOpen = null;
      }
      return;
    }

    if (_isClosing) return;
    _isClosing = true;

    _fadeController
        .reverse()
        .then((_) {
          // 可能已被立即移除/替换
          if (_overlayEntry == entry) {
            entry.remove();
            _overlayEntry = null;
          } else {
            try {
              entry.remove();
            } catch (_) {}
          }

          _isClosing = false;
          if (_currentOpen == this) {
            _currentOpen = null;
          }
        })
        .catchError((_) {
          // TickerCanceled 等：直接移除
          if (_overlayEntry == entry) {
            entry.remove();
            _overlayEntry = null;
          } else {
            try {
              entry.remove();
            } catch (_) {}
          }

          _isClosing = false;
          if (_currentOpen == this) {
            _currentOpen = null;
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = (widget.baseFontSize * 0.85).clamp(12.0, 18.0).toDouble();
    final iconColor = Theme.of(context).colorScheme.primary;

    return CompositedTransformTarget(
      link: _layerLink,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          child: Icon(
            Icons.note_alt_outlined,
            size: iconSize,
            color: iconColor,
          ),
        ),
      ),
    );
  }
}

/// 跑马灯文本组件：当文本超出容器宽度时，无限循环滚动（头尾视觉衔接），只在起始位置停顿。
class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final double horizontalPadding;

  const _MarqueeText({
    required this.text,
    this.style,
    this.horizontalPadding = 0.0,
  });

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _pauseTimer;
  bool _disposed = false;

  // 测量结果
  double _textWidth = 0;
  double _textHeight = 0;
  double _containerWidth = 0;
  bool _needsScroll = false;

  // 两份文本之间的间距
  static const double _gap = 48.0;
  // 滚动速度
  static const double _scrollSpeed = 30.0; // px/s
  // 起始位置停顿时间
  static const Duration _pauseDuration = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _controller.addStatusListener(_onAnimationStatus);
  }

  @override
  void didUpdateWidget(covariant _MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _stopAnimation();
      // 重置测量缓存，让 LayoutBuilder 重新触发
      _textWidth = 0;
      _containerWidth = 0;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _pauseTimer?.cancel();
    _controller.removeStatusListener(_onAnimationStatus);
    _controller.dispose();
    super.dispose();
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (_disposed || !mounted) return;
    if (status == AnimationStatus.completed) {
      // 一轮滚动完成，跳回起点并停顿
      _controller.value = 0.0;
      _pauseTimer = Timer(_pauseDuration, () => _startScroll());
    }
  }

  void _measure(double containerW) {
    if (_disposed || !mounted) return;

    final textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();

    final tw = textPainter.width;
    final th = textPainter.height;
    textPainter.dispose();

    // 考虑两侧需要保留的 padding，可用宽度需减去它们
    final shouldScroll = tw > (containerW - 2 * widget.horizontalPadding);

    if (tw != _textWidth || containerW != _containerWidth) {
      _textWidth = tw;
      _textHeight = th;
      _containerWidth = containerW;

      _stopAnimation();
      if (shouldScroll != _needsScroll) {
        setState(() {
          _needsScroll = shouldScroll;
        });
      }
      if (shouldScroll) {
        _pauseTimer = Timer(_pauseDuration, () => _startScroll());
      }
    }
  }

  void _stopAnimation() {
    _pauseTimer?.cancel();
    _pauseTimer = null;
    _controller.stop();
    _controller.value = 0.0;
  }

  void _startScroll() {
    if (_disposed || !mounted || !_needsScroll) return;

    // 滚动距离 = 文本宽度 + 间距（第一份文本移出并在原地由第二份文本替代所需要的偏移量）
    final scrollDistance = _textWidth + _gap;
    final durationMs = (scrollDistance / _scrollSpeed * 1000).round();

    _controller.duration = Duration(milliseconds: durationMs);
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 在 build 后测量（避免在 build 中直接 setState）
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_disposed && mounted) {
            _measure(constraints.maxWidth);
          }
        });

        if (!_needsScroll) {
          // 短标题：静态居中显示（保持原有行为）
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: widget.horizontalPadding),
            child: Text(
              widget.text,
              style: widget.style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          );
        }

        // 长标题：无限循环滚动
        // 核心：SizedBox 固定容器大小 → ClipRect 按容器裁剪 → OverflowBox 放开子级约束
        final scrollDistance = _textWidth + _gap;

        return SizedBox(
          width: constraints.maxWidth,
          height: _textHeight > 0 ? _textHeight : null,
          child: ClipRect(
            child: OverflowBox(
              maxWidth: double.infinity,
              alignment: Alignment.centerLeft,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final offset = _controller.value * scrollDistance;
                  return Transform.translate(
                    offset: Offset(-offset, 0),
                    child: child,
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 提供起始位置的留白
                    SizedBox(width: widget.horizontalPadding),
                    Text(
                      widget.text,
                      style: widget.style,
                      maxLines: 1,
                      softWrap: false,
                    ),
                    SizedBox(width: _gap),
                    Text(
                      widget.text,
                      style: widget.style,
                      maxLines: 1,
                      softWrap: false,
                    ),
                    // 给结尾也补个留白，防止截断
                    SizedBox(width: widget.horizontalPadding),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
