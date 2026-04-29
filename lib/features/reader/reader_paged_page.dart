import 'dart:async';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:novella/core/layout/app_window_class.dart';
import 'package:novella/core/theme/app_color_profiles.dart';
import 'package:novella/core/utils/cover_url_utils.dart';
import 'package:novella/core/utils/font_manager.dart';
import 'package:novella/core/utils/time_utils.dart';
import 'package:novella/core/utils/xpath_utils.dart';
import 'package:novella/core/widgets/m3e_loading_indicator.dart';
import 'package:novella/data/services/chapter_service.dart';
import 'package:novella/data/services/reading_progress_service.dart';
import 'package:novella/data/services/reading_time_service.dart';
import 'package:novella/features/reader/reader_background_page.dart';
import 'package:novella/features/reader/shared/reader_battery_indicator.dart';
import 'package:novella/features/reader/shared/reader_chapter_sheet.dart';
import 'package:novella/features/reader/shared/reader_image_view.dart';
import 'package:novella/features/reader/shared/reader_text_sanitizer.dart';
import 'package:novella/features/reader/shared/reader_title_sheet.dart';
import 'package:novella/features/reader/shared/reader_title_utils.dart';
import 'package:novella/features/settings/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ReaderBlock {
  final String html;
  final String xPath;
  final String cleanXPath;
  final int textLength;
  final int imageCount;
  const _ReaderBlock(
    this.html,
    this.xPath,
    this.cleanXPath,
    this.textLength,
    this.imageCount,
  );
}

class _ReaderPageSlice {
  final int start;
  final int end;
  final String xPath;
  final String html;
  const _ReaderPageSlice(this.start, this.end, this.xPath, this.html);
}

class _ReaderPageSpread {
  final _ReaderPageSlice primary;
  final _ReaderPageSlice? secondary;

  const _ReaderPageSpread(this.primary, [this.secondary]);

  String get xPath => secondary?.xPath ?? primary.xPath;

  bool containsBlockIndex(int blockIndex) {
    final inPrimary = blockIndex >= primary.start && blockIndex < primary.end;
    if (inPrimary) {
      return true;
    }

    final extra = secondary;
    if (extra == null) {
      return false;
    }
    return blockIndex >= extra.start && blockIndex < extra.end;
  }
}

class _FootnoteProcessingResult {
  final String html;
  final Map<String, String> notesById;

  const _FootnoteProcessingResult({
    required this.html,
    required this.notesById,
  });
}

enum _ReaderChapterOpenPosition { saved, start, end }

class ReaderPagedPage extends ConsumerStatefulWidget {
  final int bid;
  final int sortNum;
  final int totalChapters;
  final String? coverUrl;
  final String? bookTitle;
  final bool allowServerOverrideOnOpen;
  const ReaderPagedPage({
    super.key,
    required this.bid,
    required this.sortNum,
    required this.totalChapters,
    this.coverUrl,
    this.bookTitle,
    this.allowServerOverrideOnOpen = false,
  });

  @override
  ConsumerState<ReaderPagedPage> createState() => _ReaderPagedPageState();
}

class _ReaderPagedPageState extends ConsumerState<ReaderPagedPage>
    with WidgetsBindingObserver {
  static const double _topBarButtonSize = 44;
  static const double _topBarHorizontalInset = 12;
  static const double _topBarVerticalInset = 8;
  static const double _topBarGap = 12;
  static const double _contentTopGap = 20;
  static const double _contentBottomGap = 32;
  static const double _indicatorBottomGap = 28;
  static const double _indicatorAvoidanceHeight = 34;
  static const double _doublePageGap = 24;
  static const double _manualPageTurnTriggerDistance = 48;
  static const _blockTags = {
    'p',
    'div',
    'img',
    'table',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'li',
    'blockquote',
    'hr',
  };
  static const _tableRelatedTags = {
    'table',
    'thead',
    'tbody',
    'tfoot',
    'tr',
    'td',
    'th',
    'caption',
  };
  static const _previewImageContainerClasses = {
    'duokan-image-single',
    'image-preview',
    'illus',
  };
  final _chapterService = ChapterService();
  final _fontManager = FontManager();
  final _progressService = ReadingProgressService();
  final _readingTimeService = ReadingTimeService();
  final _pageController = PageController();
  final Battery _battery = Battery();
  final ValueNotifier<int> _batteryLevelNotifier = ValueNotifier<int>(100);
  final ValueNotifier<BatteryState> _batteryStateNotifier =
      ValueNotifier<BatteryState>(BatteryState.unknown);
  final ValueNotifier<String> _timeStringNotifier = ValueNotifier<String>('');
  static final Map<String, ColorScheme> _schemeCache = {};
  final Map<String, String> _indentedBlockHtmlCache = {};
  final Map<String, double> _imageAspectRatioCache = {};
  Map<String, String> _footnoteNotesById = const {};
  Timer? _infoTimer;
  StreamSubscription<BatteryState>? _batteryStateSubscription;
  SharedPreferences? _prefs;
  bool _exitInProgress = false;
  bool _topOverlayVisible = true;
  ChapterContent? _chapter;
  List<_ReaderBlock> _blocks = const [];
  Map<String, int> _indexByXPath = const {};
  String? _fontFamily;
  String? _error;
  ColorScheme? _dynamicColorScheme;
  String? _pendingRestoreXPath;
  String _currentXPath = '//*';
  String _lastLayoutKey = '';
  String _restoredLayoutKey = '';
  String _lastMeasureKey = '';
  Map<int, double> _measuredBlockHeights = const {};
  Map<int, double> _pendingMeasuredBlockHeights = const {};
  bool _loading = true;
  bool _measurementFlushScheduled = false;
  int _currentPage = 0;
  late int _targetSortNum;
  int _loadVersion = 0;
  String _activeMeasureKey = '';
  String _pendingMeasureKey = '';
  String _measurementLayerCacheKey = '';
  double _manualPageDragOffset = 0;
  double? _stableAndroidBottomPadding;
  bool? _lastAppliedShowSystemStatusBar;
  int? _lastAppliedSystemOverlayBackgroundColor;
  Widget? _cachedMeasurementLayer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _targetSortNum = widget.sortNum;
    _applyReaderSystemUiMode(ref.read(settingsProvider), force: true);
    _initInfoBar();
    _loadChapter(
      widget.sortNum,
      openPosition: _ReaderChapterOpenPosition.saved,
    );
    _readingTimeService.startSession();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dynamicColorScheme == null) {
      _extractColors();
    }
  }

  void _initInfoBar() {
    _updateTime();
    _updateBattery();

    _batteryStateSubscription = _battery.onBatteryStateChanged.listen((state) {
      if (!mounted) return;
      _batteryStateNotifier.value = state;
      _updateBattery();
    });

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
    } catch (_) {}
  }

  @override
  void dispose() {
    _FootnoteAnchor.dismissCurrent();
    final chapter = _chapter;
    if (chapter != null) {
      unawaited(
        _progressService.saveLocalPosition(
          bookId: widget.bid,
          chapterId: chapter.id,
          sortNum: chapter.sortNum,
          xPath: _currentXPath,
          title: widget.bookTitle,
          cover: widget.coverUrl,
          chapterTitle: chapter.title,
          immediate: true,
        ),
      );
    }
    _readingTimeService.endSession();
    _batteryStateSubscription?.cancel();
    _infoTimer?.cancel();
    _batteryLevelNotifier.dispose();
    _batteryStateNotifier.dispose();
    _timeStringNotifier.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(_saveCurrentPosition());
      _readingTimeService.endSession();
    }
    if (state == AppLifecycleState.resumed) {
      _applyReaderSystemUiMode(ref.read(settingsProvider), force: true);
      _readingTimeService.startSession();
      _updateTime();
      _updateBattery();
    }
  }

  Future<void> _saveCurrentPosition({String? xPath}) async {
    final chapter = _chapter;
    if (chapter == null) return;
    final currentXPath = xPath ?? _currentXPath;
    await _progressService.saveLocalPosition(
      bookId: widget.bid,
      chapterId: chapter.id,
      sortNum: chapter.sortNum,
      xPath: currentXPath,
      title: widget.bookTitle,
      cover: widget.coverUrl,
      chapterTitle: chapter.title,
    );
    await _progressService.saveReadPosition(
      bookId: widget.bid,
      chapterId: chapter.id,
      xPath: currentXPath,
    );
  }

  void _applyReaderSystemUiMode(AppSettings settings, {bool force = false}) {
    final showStatusBar = settings.readerPagedShowSystemStatusBar;
    if (!force && _lastAppliedShowSystemStatusBar == showStatusBar) {
      return;
    }

    _lastAppliedShowSystemStatusBar = showStatusBar;
    unawaited(
      showStatusBar
          ? SystemChrome.setEnabledSystemUIMode(
            SystemUiMode.manual,
            overlays: const [SystemUiOverlay.top],
          )
          : SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
  }

  Future<void> _saveProgressForExit() async {
    if (_exitInProgress) return;
    _exitInProgress = true;

    final chapter = _chapter;
    if (chapter == null) return;

    final currentXPath = _currentXPath;

    try {
      await _progressService.saveLocalPosition(
        bookId: widget.bid,
        chapterId: chapter.id,
        sortNum: chapter.sortNum,
        xPath: currentXPath,
        title: widget.bookTitle,
        cover: widget.coverUrl,
        chapterTitle: chapter.title,
        immediate: true,
      );
    } catch (_) {}

    unawaited(
      _progressService.saveReadPosition(
        bookId: widget.bid,
        chapterId: chapter.id,
        xPath: currentXPath,
      ),
    );
  }

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  String _imageAspectRatioPrefsKey(String src) => 'image_ratio_$src';

  Future<void> _cacheImageAspectRatio(String src, double ratio) async {
    if (!ratio.isFinite || ratio <= 0) {
      return;
    }
    _imageAspectRatioCache[src] = ratio;
    try {
      final prefs = await _ensurePrefs();
      await prefs.setDouble(_imageAspectRatioPrefsKey(src), ratio);
    } catch (_) {}
  }

  Future<void> _resolveImageAspectRatio(String src) async {
    if (src.isEmpty || _imageAspectRatioCache.containsKey(src)) {
      return;
    }

    try {
      final prefs = await _ensurePrefs();
      final cachedRatio = prefs.getDouble(_imageAspectRatioPrefsKey(src));
      if (cachedRatio != null && cachedRatio.isFinite && cachedRatio > 0) {
        _imageAspectRatioCache[src] = cachedRatio;
        return;
      }
    } catch (_) {}

    if (!mounted) {
      return;
    }

    final completer = Completer<void>();
    final imageProvider = CachedNetworkImageProvider(src);
    final stream = imageProvider.resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        final width = info.image.width.toDouble();
        final height = info.image.height.toDouble();
        if (height > 0) {
          unawaited(_cacheImageAspectRatio(src, width / height));
        }
        if (!completer.isCompleted) {
          completer.complete();
        }
        stream.removeListener(listener);
      },
      onError: (_, __) {
        if (!completer.isCompleted) {
          completer.complete();
        }
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);

    try {
      await completer.future.timeout(const Duration(seconds: 8));
    } on TimeoutException {
      stream.removeListener(listener);
    }
  }

  Future<void> _primeImageAspectRatios(String html) async {
    if (html.isEmpty) {
      return;
    }

    final fragment = html_parser.parseFragment(html);
    final pending = <Future<void>>[];
    final seen = <String>{};
    for (final image in fragment.querySelectorAll('img')) {
      if (_isFootnoteMarkerImage(image)) {
        continue;
      }

      final src = image.attributes['src']?.trim();
      if (src == null || src.isEmpty || !seen.add(src)) {
        continue;
      }

      final explicitRatio = _imageAspectRatio(
        _parseDimension(image.attributes['width']),
        _parseDimension(image.attributes['height']),
      );
      if (explicitRatio != null) {
        pending.add(_cacheImageAspectRatio(src, explicitRatio));
        continue;
      }

      if (_imageAspectRatioCache.containsKey(src)) {
        continue;
      }

      pending.add(_resolveImageAspectRatio(src));
    }

    if (pending.isEmpty) {
      return;
    }

    await Future.wait(pending);
  }

  String _resolveInitialRestoreXPath(
    _ReaderChapterOpenPosition openPosition,
    List<_ReaderBlock> blocks,
    ReadPosition? localPosition,
    int sortNum,
  ) {
    if (blocks.isEmpty) {
      return '//*';
    }

    switch (openPosition) {
      case _ReaderChapterOpenPosition.end:
        return blocks.last.xPath;
      case _ReaderChapterOpenPosition.start:
        return blocks.first.xPath;
      case _ReaderChapterOpenPosition.saved:
        if (localPosition != null &&
            localPosition.sortNum == sortNum &&
            localPosition.xPath.isNotEmpty) {
          return localPosition.xPath;
        }
        return blocks.first.xPath;
    }
  }

  Future<void> _loadChapter(
    int sortNum, {
    _ReaderChapterOpenPosition openPosition = _ReaderChapterOpenPosition.start,
  }) async {
    final version = ++_loadVersion;
    _FootnoteAnchor.dismissCurrent();
    if (_chapter != null) unawaited(_saveCurrentPosition());
    setState(() {
      _loading = true;
      _error = null;
      _pendingRestoreXPath = null;
      _currentPage = 0;
      _currentXPath = '//*';
      _lastLayoutKey = '';
      _restoredLayoutKey = '';
      _lastMeasureKey = '';
      _measuredBlockHeights = const {};
      _pendingMeasuredBlockHeights = const {};
      _footnoteNotesById = const {};
    });
    _measurementFlushScheduled = false;
    _pendingMeasureKey = '';
    _activeMeasureKey = '';
    _measurementLayerCacheKey = '';
    _cachedMeasurementLayer = null;
    await SchedulerBinding.instance.endOfFrame;
    if (!mounted || version != _loadVersion) return;
    try {
      final settings = ref.read(settingsProvider);
      final chapter = await _chapterService.getNovelContent(
        widget.bid,
        sortNum,
        convert: settings.convertType == 'none' ? null : settings.convertType,
      );
      if (version != _loadVersion) return;
      final fontFamily =
          chapter.fontUrl == null
              ? null
              : await _fontManager.loadFont(
                chapter.fontUrl,
                cacheEnabled: settings.fontCacheEnabled,
                cacheLimit: settings.fontCacheLimit,
              );
      if (version != _loadVersion) return;
      final invisibleCodepoints = _fontManager.getInvisibleCodepoints(
        fontFamily,
      );
      final sanitizedContent = sanitizeReaderHtmlTextNodes(
        chapter.content,
        invisibleCodepoints,
      );
      final processed = _processFootnotes(sanitizedContent);
      await _primeImageAspectRatios(processed.html);
      if (version != _loadVersion) return;
      final blocks = _buildBlocks(processed.html);
      final localPosition = await _progressService.getLocalPosition(widget.bid);
      if (!mounted || version != _loadVersion) return;
      final initialRestoreXPath = _resolveInitialRestoreXPath(
        openPosition,
        blocks.$1,
        localPosition,
        sortNum,
      );
      setState(() {
        _chapter = chapter;
        _fontFamily = fontFamily;
        _blocks = blocks.$1;
        _indexByXPath = blocks.$2;
        _footnoteNotesById = processed.notesById;
        _indentedBlockHtmlCache.clear();
        _loading = false;
        _targetSortNum = sortNum;
        _currentXPath = _blocks.isEmpty ? '//*' : _blocks.first.xPath;
        _pendingRestoreXPath = initialRestoreXPath;
      });
    } catch (e) {
      if (!mounted || version != _loadVersion) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  (List<_ReaderBlock>, Map<String, int>) _buildBlocks(String html) {
    final blocks = <_ReaderBlock>[];
    final indexByXPath = <String, int>{};
    void add(dom.Element element, String rawXPath) {
      final cleanXPath = XPathUtils.cleanXPath(rawXPath);
      final renderable = _buildRenderableBlockContent(element);
      indexByXPath.putIfAbsent(cleanXPath, () => blocks.length);
      blocks.add(
        _ReaderBlock(
          renderable.html,
          rawXPath,
          cleanXPath,
          renderable.textLength,
          renderable.imageCount,
        ),
      );
    }

    void walk(dom.Node node, String currentPath) {
      if (node is! dom.Element) return;
      final tag = node.localName ?? '';
      int index = 1;
      final parent = node.parentNode;
      if (parent != null) {
        for (final sibling in parent.nodes) {
          if (sibling == node) break;
          if (sibling is dom.Element && sibling.localName == tag) index++;
        }
      }
      final path =
          currentPath.isEmpty
              ? '//*/$tag[$index]'
              : '$currentPath/$tag[$index]';
      if (_shouldUseAsBlock(node)) {
        add(node, path);
        return;
      }
      for (final child in node.nodes) {
        walk(child, path);
      }
    }

    final fragment = html_parser.parseFragment(html);
    for (final node in fragment.nodes) {
      walk(node, '');
    }
    if (blocks.isEmpty) {
      final wrapper = dom.Element.tag('div')..innerHtml = html;
      add(wrapper, '//*');
    }
    return (blocks, indexByXPath);
  }

  ({String html, int textLength, int imageCount}) _buildRenderableBlockContent(
    dom.Element element,
  ) {
    final originalHtml = element.outerHtml;
    final originalTextLength = _normalizeText(element.text).length;
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
        textLength: _normalizeText(root.text).length,
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

  bool _isElementHidden(dom.Element element) {
    final style = (element.attributes['style'] ?? '').toLowerCase();
    return RegExp(r'display\s*:\s*none').hasMatch(style);
  }

  _FootnoteProcessingResult _processFootnotes(String html) {
    if (html.isEmpty) {
      return const _FootnoteProcessingResult(html: '', notesById: {});
    }

    try {
      final doc = html_parser.parse(html);
      final notesById = <String, String>{};

      String? attrValue(dom.Element element, String nameLower) {
        for (final entry in element.attributes.entries) {
          if (entry.key.toString().toLowerCase() == nameLower) {
            return entry.value;
          }
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

      int textScore(dom.Element element) {
        return _normalizeText(element.text).length;
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

      final idIndex = <String, List<dom.Element>>{};
      final nameIndex = <String, List<dom.Element>>{};
      final root = doc.documentElement ?? doc;
      for (final element in walkElements(root)) {
        final idValue = attrValue(element, 'id');
        if (idValue != null && idValue.isNotEmpty) {
          (idIndex[idValue] ??= <dom.Element>[]).add(element);
        }
        final nameValue = attrValue(element, 'name');
        if (nameValue != null && nameValue.isNotEmpty) {
          (nameIndex[nameValue] ??= <dom.Element>[]).add(element);
        }
      }

      dom.Element? findBestNoteContainer(String id) {
        final candidates = <dom.Element>[
          ...(idIndex[id] ?? const <dom.Element>[]),
          ...(nameIndex[id] ?? const <dom.Element>[]),
        ];
        if (candidates.isEmpty) {
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

          final candidateScore = textScore(container);
          final priority = noteContainerPriority(container);
          final size = container.outerHtml.length;
          final shouldUse =
              best == null ||
              candidateScore > bestScore ||
              (candidateScore == bestScore && priority < bestPriority) ||
              (candidateScore == bestScore &&
                  priority == bestPriority &&
                  size < bestSize);
          if (shouldUse) {
            best = container;
            bestScore = candidateScore;
            bestPriority = priority;
            bestSize = size;
          }
        }

        return best;
      }

      for (final anchor in doc.querySelectorAll('a.duokan-footnote')) {
        final href = anchor.attributes['href'];
        if (href == null || !href.startsWith('#') || href.length <= 1) {
          continue;
        }

        final id = href.substring(1);
        if (id.isEmpty) {
          continue;
        }

        final noteElement = findBestNoteContainer(id);
        if (noteElement != null) {
          notesById.putIfAbsent(id, () => noteElement.innerHtml.trim());
          final currentStyle = noteElement.attributes['style'] ?? '';
          noteElement.attributes['style'] = '$currentStyle; display: none;';
        }

        anchor.attributes['data-footnote-id'] = id;
        anchor.attributes.remove('href');
        anchor.innerHtml = '';
      }

      for (final img in doc.querySelectorAll('img.footnote')) {
        img.remove();
      }

      return _FootnoteProcessingResult(
        html: doc.body?.innerHtml ?? html,
        notesById: notesById,
      );
    } catch (_) {
      return _FootnoteProcessingResult(html: html, notesById: const {});
    }
  }

  String _normalizeText(String text) {
    return normalizeReaderText(text);
  }

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

    final rawText = _normalizeText(element.text);
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

  bool _shouldUseAsBlock(dom.Element element) {
    final tag = element.localName ?? '';
    if (!_blockTags.contains(tag)) return false;
    if (_isElementHidden(element)) {
      return false;
    }
    if (tag == 'img' || tag == 'hr' || tag == 'table') return true;
    if (tag == 'div') {
      if (_isStandaloneIllustrationContainer(element)) {
        return true;
      }
      final hasDirectBlockChild = element.nodes.any(
        (node) => node is dom.Element && _blockTags.contains(node.localName),
      );
      if (hasDirectBlockChild) return false;
    }
    return _normalizeText(element.text).isNotEmpty ||
        element.getElementsByTagName('img').isNotEmpty ||
        element.getElementsByTagName('br').isNotEmpty;
  }

  bool _hasAncestorTag(
    dom.Element element,
    Set<String> tags, {
    int maxDepth = 8,
  }) {
    dom.Element? current = element.parent;
    var depth = 0;
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
    return _hasAncestorTag(element, _tableRelatedTags);
  }

  ({bool isFloating, bool isFloatRight}) _resolveFloatingImage(
    dom.Element element,
  ) {
    dom.Element? current = element;
    for (var i = 0; i < 3 && current != null; i++) {
      final style = (current.attributes['style'] ?? '').toLowerCase();
      final align = (current.attributes['align'] ?? '').toLowerCase();
      final classes = current.classes;
      if (style.contains('float: right') ||
          align == 'right' ||
          classes.contains('fr')) {
        return (isFloating: true, isFloatRight: true);
      }
      if (style.contains('float: left') ||
          align == 'left' ||
          classes.contains('fl')) {
        return (isFloating: true, isFloatRight: false);
      }
      current = current.parent;
    }
    return (isFloating: false, isFloatRight: false);
  }

  double? _parseDimension(String? rawValue) {
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

  bool _isPreviewImageContainer(dom.Element? element) {
    if (element == null) {
      return false;
    }
    return element.classes.any(_previewImageContainerClasses.contains);
  }

  bool _hasNonFootnoteImage(dom.Element element) {
    return element
        .getElementsByTagName('img')
        .any((img) => !_isFootnoteMarkerImage(img));
  }

  bool _isImageOnlyBlockContainer(dom.Element element) {
    return _hasNonFootnoteImage(element) &&
        _normalizeText(element.text).isEmpty;
  }

  bool _isStandaloneIllustrationContainer(dom.Element element) {
    if (element.localName != 'div') {
      return false;
    }
    if (!_isIllustrationContainer(element) &&
        !_isPreviewImageContainer(element)) {
      return false;
    }
    if (_normalizeText(element.text).isNotEmpty) {
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

  double? _imageAspectRatio(double? width, double? height) {
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return width / height;
  }

  double? _resolvedImageAspectRatio(dom.Element element) {
    final explicitRatio = _imageAspectRatio(
      _parseDimension(element.attributes['width']),
      _parseDimension(element.attributes['height']),
    );
    if (explicitRatio != null) {
      return explicitRatio;
    }

    final src = element.attributes['src']?.trim();
    if (src == null || src.isEmpty) {
      return null;
    }

    return _imageAspectRatioCache[src];
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

    final aspectRatio = _resolvedImageAspectRatio(image);
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
          borderRadius: 4,
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

  Widget? _buildImageWidget(
    dom.Element element,
    Color textColor,
    double readerSidePadding,
    bool openImagePreviewOnLongPress,
  ) {
    if (element.localName != 'img') {
      return null;
    }

    final src = element.attributes['src']?.trim();
    if (src == null || src.isEmpty) {
      return null;
    }

    final alt = element.attributes['alt'];
    final width = _parseDimension(element.attributes['width']);
    final height = _parseDimension(element.attributes['height']);
    final aspectRatio = _imageAspectRatio(width, height);
    final parentTag = element.parent?.localName;
    final insideTable = _isInsideTableStructure(element);
    final insideIllustration = _isInsideIllustrationContainer(element);
    final floating = _resolveFloatingImage(element);
    final isPreviewable = _isPreviewableReaderImage(element);

    if (floating.isFloating) {
      return Align(
        alignment:
            floating.isFloatRight
                ? Alignment.centerRight
                : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: ReaderRoundedNetworkImage(
            imageUrl: src,
            alt: alt,
            width: width,
            height: height,
            errorColor: textColor,
            borderRadius: 4,
            previewable: isPreviewable,
            openPreviewOnLongPress: openImagePreviewOnLongPress,
          ),
        ),
      );
    }

    final horizontalPadding =
        parentTag == 'p' || parentTag == 'div' || parentTag == 'blockquote'
            ? 5.0
            : 0.0;

    Widget buildResponsiveImage(
      BuildContext context, {
      EdgeInsetsGeometry padding = EdgeInsets.zero,
      double? maxWidth,
    }) {
      Widget image = ReaderRoundedNetworkImage(
        imageUrl: src,
        alt: alt,
        errorColor: textColor,
        borderRadius: 4,
        previewable: isPreviewable,
        openPreviewOnLongPress: openImagePreviewOnLongPress,
      );

      if (aspectRatio != null && !insideTable) {
        image = AspectRatio(aspectRatio: aspectRatio, child: image);
      }

      if (maxWidth != null) {
        image = ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: image,
        );
      }

      if (padding != EdgeInsets.zero) {
        image = Padding(padding: padding, child: image);
      }

      return image;
    }

    if (!insideTable && !insideIllustration) {
      return InlineCustomWidget(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: Builder(
          builder: (context) {
            final maxWidth = (MediaQuery.sizeOf(context).width -
                    readerSidePadding * 2)
                .clamp(48.0, double.infinity);
            return buildResponsiveImage(
              context,
              maxWidth: maxWidth,
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            );
          },
        ),
      );
    }

    return Builder(
      builder: (context) {
        final maxWidth =
            insideTable
                ? null
                : (MediaQuery.sizeOf(context).width - readerSidePadding * 2)
                    .clamp(48.0, double.infinity);
        return buildResponsiveImage(
          context,
          maxWidth: maxWidth,
          padding:
              insideIllustration
                  ? EdgeInsets.zero
                  : EdgeInsets.symmetric(horizontal: horizontalPadding),
        );
      },
    );
  }

  bool _isInsideIllustrationContainer(dom.Element element) {
    dom.Element? current = element.parent;
    var depth = 0;
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

      if (_normalizeText(root.text).isNotEmpty) {
        return true;
      }

      final hasNonFootnoteImage = root
          .getElementsByTagName('img')
          .any((img) => !_isFootnoteMarkerImage(img));
      return !hasNonFootnoteImage && root.getElementsByTagName('br').isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  double _paragraphSpacingBeforeBlock(int blockIndex, AppSettings settings) {
    if (blockIndex <= 0 || blockIndex >= _blocks.length) {
      return 0;
    }
    return _blockUsesReaderParagraphSpacing(_blocks[blockIndex - 1])
        ? settings.readerParagraphSpacing
        : 0.0;
  }

  Map<String, String>? _buildReaderBlockTagStyles(
    dom.Element element,
    double readerLineHeight,
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
          'font-size': '1.65em',
          'line-height': '120%',
          'text-align': 'center',
          'font-weight': 'bold',
          'margin-top': '0.1em',
          'margin-bottom': '0.4em',
        };
      case 'h2':
        return {
          'font-size': '1.25em',
          'line-height': '120%',
          'text-align': 'center',
          'font-weight': 'bold',
          'margin-top': '0.3em',
          'margin-bottom': '0.5em',
        };
      case 'h3':
        return {
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
          'font-size': '1.5em',
          'font-weight': 'bold',
          'text-indent': '1.333em',
          'margin-top': '0.5em',
          'margin-bottom': '1em',
        };
      case 'center':
        return {
          'line-height': readerLineHeight.toStringAsFixed(1),
          'text-align': 'center',
          'text-indent': '0',
        };
      default:
        return {'line-height': readerLineHeight.toStringAsFixed(1)};
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

  Widget _buildBlockWidget(
    _ReaderBlock block,
    AppSettings settings,
    Color textColor,
    Color linkColor,
  ) {
    final renderedHtml = _getRenderedBlockHtml(block, settings);
    return HtmlWidget(
      renderedHtml,
      textStyle: TextStyle(
        fontFamily: _fontFamily,
        fontSize: settings.fontSize,
        height: settings.readerLineHeight,
        color: textColor,
      ),
      customStylesBuilder: (element) {
        void mergeStyle(
          Map<String, String> target,
          Map<String, String>? incoming,
        ) {
          if (incoming != null && incoming.isNotEmpty) {
            target.addAll(incoming);
          }
        }

        final tag = element.localName ?? '';
        if (tag == 'img') {
          final style = <String, String>{};
          mergeStyle(style, _buildReaderPresetClassStyles(element));
          style['border-radius'] = '4px';

          final insideTable = _isInsideTableStructure(element);
          final insideIllustration = _isInsideIllustrationContainer(element);
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

          if (insideIllustration) {
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

          if (insideTable) {
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
          _buildReaderBlockTagStyles(element, settings.readerLineHeight),
        );
        mergeStyle(style, _buildReaderPresetClassStyles(element));

        if (tag == 'a') {
          style['color'] =
              '#${linkColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
        }

        if (!_usesReaderParagraphSpacing(tag) && _blockTags.contains(tag)) {
          style.putIfAbsent('margin', () => '0 0 0.85em 0');
        }

        return style.isEmpty ? null : style;
      },
      customWidgetBuilder: (element) {
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
            lineHeight: settings.readerLineHeight,
            fontFamily: _fontFamily,
            readerBackgroundColor: _readerBackgroundColor(settings, context),
            readerTextColor: textColor,
          );
        }

        return _buildIllustrationContainerWidget(
              element,
              textColor,
              settings.readerSidePadding,
              settings.readerImagePreviewOpenOnLongPress,
            ) ??
            _buildImageWidget(
              element,
              textColor,
              settings.readerSidePadding,
              settings.readerImagePreviewOpenOnLongPress,
            );
      },
      onTapUrl: (_) => true,
    );
  }

  void _onMeasuredBlock(int index, double height, String measureKey) {
    final normalizedHeight = height.isFinite ? height : 0.0;
    if (normalizedHeight <= 0 || !mounted || measureKey != _activeMeasureKey) {
      return;
    }

    final previous =
        measureKey == _lastMeasureKey
            ? _measuredBlockHeights[index]
            : _pendingMeasuredBlockHeights[index];
    if (previous != null && (previous - normalizedHeight).abs() < 0.5) {
      return;
    }

    if (_pendingMeasureKey != measureKey) {
      _pendingMeasureKey = measureKey;
      _pendingMeasuredBlockHeights = {index: normalizedHeight};
    } else {
      _pendingMeasuredBlockHeights = {
        ..._pendingMeasuredBlockHeights,
        index: normalizedHeight,
      };
    }

    if (_measurementFlushScheduled) {
      return;
    }

    _measurementFlushScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurementFlushScheduled = false;
      if (!mounted ||
          _pendingMeasureKey.isEmpty ||
          _pendingMeasuredBlockHeights.isEmpty) {
        return;
      }

      final flushedMeasureKey = _pendingMeasureKey;
      final pendingHeights = _pendingMeasuredBlockHeights;
      _pendingMeasureKey = '';
      _pendingMeasuredBlockHeights = const {};

      setState(() {
        if (_lastMeasureKey != flushedMeasureKey) {
          _lastMeasureKey = flushedMeasureKey;
          _measuredBlockHeights = pendingHeights;
          return;
        }

        final merged = Map<int, double>.from(_measuredBlockHeights);
        var changed = false;
        pendingHeights.forEach((blockIndex, blockHeight) {
          final existing = merged[blockIndex];
          if (existing == null || (existing - blockHeight).abs() >= 0.5) {
            merged[blockIndex] = blockHeight;
            changed = true;
          }
        });

        if (changed) {
          _measuredBlockHeights = merged;
        }
      });
    });
  }

  int _resolveBlockIndex(String xPath) {
    if (_blocks.isEmpty) return 0;
    var cleanXPath = XPathUtils.cleanXPath(xPath);
    while (cleanXPath.isNotEmpty) {
      final index = _indexByXPath[cleanXPath];
      if (index != null) return index;
      final slash = cleanXPath.lastIndexOf('/');
      if (slash <= 0) break;
      cleanXPath = cleanXPath.substring(0, slash);
    }
    return 0;
  }

  double _topContentPadding(BuildContext context) {
    return MediaQuery.paddingOf(context).top +
        _topBarVerticalInset +
        _topBarButtonSize +
        _contentTopGap;
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

  double _bottomContentPadding(BuildContext context) {
    return _readerBottomPadding(context) + _contentBottomGap;
  }

  double _imageOnlyBottomContentPadding(BuildContext context) {
    return _readerBottomPadding(context) +
        _indicatorBottomGap +
        _indicatorAvoidanceHeight;
  }

  double _pageContentHeight(BuildContext context, BoxConstraints constraints) {
    return (constraints.maxHeight -
            _topContentPadding(context) -
            _bottomContentPadding(context))
        .clamp(220.0, double.infinity);
  }

  List<_ReaderPageSlice> _buildPages(
    BuildContext context,
    BoxConstraints constraints,
    AppSettings settings,
  ) {
    if (_blocks.isEmpty) return const [];
    final budget = _pageContentHeight(context, constraints);
    final pages = <_ReaderPageSlice>[];
    var start = 0;
    var cost = 0.0;
    for (var i = 0; i < _blocks.length; i++) {
      final blockHeight = _measuredBlockHeights[i] ?? budget;
      final blockCost =
          blockHeight + _paragraphSpacingBeforeBlock(i, settings) + 4;
      if (i > start && cost + blockCost > budget) {
        pages.add(_makePage(start, i));
        start = i;
        cost = blockHeight + 4;
      } else {
        cost += blockCost;
      }
    }
    pages.add(_makePage(start, _blocks.length));
    return pages;
  }

  List<_ReaderPageSpread> _buildPageSpreads(
    List<_ReaderPageSlice> pages, {
    required bool useDoublePage,
  }) {
    if (!useDoublePage) {
      return pages
          .map((page) => _ReaderPageSpread(page))
          .toList(growable: false);
    }

    final spreads = <_ReaderPageSpread>[];
    for (var index = 0; index < pages.length; index += 2) {
      final secondary = index + 1 < pages.length ? pages[index + 1] : null;
      spreads.add(_ReaderPageSpread(pages[index], secondary));
    }
    return spreads;
  }

  _ReaderPageSlice _makePage(int start, int end) {
    final html = _blocks
        .sublist(start, end)
        .map((block) => block.html)
        .join('\n');
    return _ReaderPageSlice(start, end, _blocks[start].xPath, html);
  }

  bool _isImageOnlyPage(_ReaderPageSlice page) {
    if (page.end <= page.start) {
      return false;
    }

    if (page.end - page.start != 1) {
      return false;
    }

    return _isStandaloneImageBlock(_blocks[page.start]);
  }

  String? _extractPrimaryImageSrc(_ReaderPageSlice page) {
    if (!_isImageOnlyPage(page)) {
      return null;
    }

    final fragment = html_parser.parseFragment(page.html);
    return fragment.querySelector('img')?.attributes['src'];
  }

  Widget _buildReaderPageContent({
    required _ReaderPageSlice page,
    required double contentWidth,
    required double contentHeight,
    required AppSettings settings,
    required Color textColor,
    required Color linkColor,
  }) {
    final imageOnly = _isImageOnlyPage(page);
    final imageUrl = _extractPrimaryImageSrc(page);
    return imageOnly && imageUrl != null
        ? _buildImageOnlyPage(
          page: page,
          imageUrl: imageUrl,
          width: contentWidth,
          maxHeight: contentHeight,
          settings: settings,
          textColor: textColor,
          linkColor: linkColor,
        )
        : _buildHtmlPage(
          page: page,
          width: contentWidth,
          maxHeight: contentHeight,
          settings: settings,
          textColor: textColor,
          linkColor: linkColor,
        );
  }

  bool _isStandaloneImageBlock(_ReaderBlock block) {
    if (block.imageCount != 1 || block.textLength != 0) {
      return false;
    }

    try {
      final fragment = html_parser.parseFragment(block.html);
      final elements = fragment.nodes.whereType<dom.Element>().toList();
      if (elements.length != 1) {
        return false;
      }

      final root = elements.first;
      final tag = root.localName ?? '';
      if (_tableRelatedTags.contains(tag)) {
        return false;
      }
      if (tag == 'img') {
        return true;
      }
      final images =
          root
              .getElementsByTagName('img')
              .where((img) => !_isFootnoteMarkerImage(img))
              .toList();
      return images.length == 1 && _normalizeText(root.text).isEmpty;
    } catch (_) {
      return false;
    }
  }

  void _scheduleRestore(List<_ReaderPageSpread> spreads, String layoutKey) {
    if (_lastLayoutKey == layoutKey) return;
    _lastLayoutKey = layoutKey;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || spreads.isEmpty) return;
      if (!_pageController.hasClients) {
        if (!mounted) return;
        setState(() {
          _lastLayoutKey = '';
        });
        return;
      }
      var targetPage = _currentPage.clamp(0, spreads.length - 1);
      if (_pendingRestoreXPath != null && _pendingRestoreXPath!.isNotEmpty) {
        final blockIndex = _resolveBlockIndex(_pendingRestoreXPath!);
        targetPage = spreads.indexWhere(
          (spread) => spread.containsBlockIndex(blockIndex),
        );
        if (targetPage < 0) targetPage = 0;
      }
      _pageController.jumpToPage(targetPage);
      final xPath = spreads[targetPage].xPath;
      if (!mounted) return;
      setState(() {
        _currentPage = targetPage;
        _currentXPath = xPath;
        _pendingRestoreXPath = null;
        _restoredLayoutKey = layoutKey;
      });
      await _saveCurrentPosition(xPath: xPath);
    });
  }

  void _goToPage(int pageIndex, {required bool animated}) {
    if (!_pageController.hasClients) {
      return;
    }

    if (animated) {
      _pageController.animateToPage(
        pageIndex,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    _pageController.jumpToPage(pageIndex);
  }

  void _goToPreviousPage({required bool animated}) {
    if (_currentPage > 0) {
      _goToPage(_currentPage - 1, animated: animated);
      return;
    }

    if (_targetSortNum > 1) {
      _FootnoteAnchor.dismissCurrent();
      _loadChapter(
        _targetSortNum - 1,
        openPosition: _ReaderChapterOpenPosition.end,
      );
    }
  }

  void _goToNextPage({required int pageCount, required bool animated}) {
    if (_currentPage < pageCount - 1) {
      _goToPage(_currentPage + 1, animated: animated);
      return;
    }

    if (_targetSortNum < widget.totalChapters) {
      _FootnoteAnchor.dismissCurrent();
      _loadChapter(
        _targetSortNum + 1,
        openPosition: _ReaderChapterOpenPosition.start,
      );
    }
  }

  void _handleManualPageDragStart(DragStartDetails details) {
    _manualPageDragOffset = 0;
  }

  void _handleManualPageDragUpdate(DragUpdateDetails details) {
    _manualPageDragOffset += details.primaryDelta ?? 0;
  }

  void _handleManualPageDragCancel() {
    _manualPageDragOffset = 0;
  }

  void _handleManualPageDragEnd({required int pageCount}) {
    final dragOffset = _manualPageDragOffset;
    _manualPageDragOffset = 0;

    if (dragOffset >= _manualPageTurnTriggerDistance) {
      _goToPreviousPage(animated: false);
      return;
    }

    if (dragOffset <= -_manualPageTurnTriggerDistance) {
      _goToNextPage(pageCount: pageCount, animated: false);
    }
  }

  void _extractColors() {
    if (widget.coverUrl == null || widget.coverUrl!.isEmpty) {
      return;
    }

    final settings = ref.read(settingsProvider);
    if (!settings.coverColorExtraction) {
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorProfile = AppColorProfiles.profileFor(
      isDark: isDark,
      oledBlackEnabled: settings.oledBlack,
    );
    final cacheKey = '${widget.bid}_$colorProfile';

    if (_schemeCache.containsKey(cacheKey)) {
      if (mounted) {
        setState(() {
          _dynamicColorScheme = _schemeCache[cacheKey]!;
        });
      }
      return;
    }

    final seedColor = CoverUrlUtils.extractSeedColor(widget.coverUrl);
    if (seedColor != null && mounted) {
      final scheme = AppColorProfiles.colorSchemeFromCoverSeed(
        seedColor,
        profile: colorProfile,
      );
      _schemeCache[cacheKey] = scheme;
      setState(() {
        _dynamicColorScheme = scheme;
      });
    }
  }

  Color _readerBackgroundColor(AppSettings settings, BuildContext context) {
    final themeScheme =
        (settings.coverColorExtraction ? _dynamicColorScheme : null) ??
        Theme.of(context).colorScheme;
    if (settings.readerUseThemeBackground) {
      return themeScheme.surface;
    }
    if (settings.readerUseCustomColor) {
      return Color(settings.readerBackgroundColor);
    }
    return kReaderPresets[settings.readerPresetIndex.clamp(
          0,
          kReaderPresets.length - 1,
        )]
        .backgroundColor;
  }

  Color _readerTextColor(AppSettings settings, BuildContext context) {
    final themeScheme =
        (settings.coverColorExtraction ? _dynamicColorScheme : null) ??
        Theme.of(context).colorScheme;
    if (settings.readerUseThemeBackground) {
      return themeScheme.onSurface;
    }
    if (settings.readerUseCustomColor) {
      return Color(settings.readerTextColor);
    }
    return kReaderPresets[settings.readerPresetIndex.clamp(
          0,
          kReaderPresets.length - 1,
        )]
        .textColor;
  }

  SystemUiOverlayStyle _readerSystemOverlayStyle(Color backgroundColor) {
    final brightness = ThemeData.estimateBrightnessForColor(backgroundColor);
    final iconBrightness =
        brightness == Brightness.dark ? Brightness.light : Brightness.dark;
    final iosStatusBarBrightness =
        iconBrightness == Brightness.light ? Brightness.dark : Brightness.light;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: iconBrightness,
      statusBarBrightness: iosStatusBarBrightness,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: iconBrightness,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
    );
  }

  void _applyReaderSystemOverlayStyle(Color backgroundColor) {
    final backgroundValue = backgroundColor.toARGB32();
    if (_lastAppliedSystemOverlayBackgroundColor == backgroundValue) {
      return;
    }
    _lastAppliedSystemOverlayBackgroundColor = backgroundValue;
    SystemChrome.setSystemUIOverlayStyle(
      _readerSystemOverlayStyle(backgroundColor),
    );
  }

  Future<void> _openChapterList(BuildContext context) async {
    await showReaderChapterListSheet(
      context,
      bookId: widget.bid,
      currentSortNum: _chapter?.sortNum ?? _targetSortNum,
      onSelected: (sortNum) {
        if (sortNum == _targetSortNum) {
          return;
        }
        _FootnoteAnchor.dismissCurrent();
        _loadChapter(sortNum, openPosition: _ReaderChapterOpenPosition.start);
      },
    );
  }
  /*
    var chapters = BookDetailPageState.cachedChapterList;
    if (chapters == null || chapters.isEmpty) {
      final bookInfo = await _bookService.getBookInfo(widget.bid);
      chapters = bookInfo.chapters;
      BookDetailPageState.cachedChapterList = chapters;
    }
    final loadedChapters = chapters;
    if (!context.mounted || loadedChapters.isEmpty) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        return ListView.builder(
          itemCount: loadedChapters.length,
          itemBuilder: (context, index) {
            final sortNum = index + 1;
            return ListTile(
              selected: sortNum == _targetSortNum,
              title: Text(loadedChapters[index].title),
              subtitle: Text('第 $sortNum 章'),
              onTap: () {
                Navigator.of(context).pop();
                if (sortNum == _targetSortNum) {
                  return;
                }
                _loadChapter(
                  sortNum,
                  openPosition: _ReaderChapterOpenPosition.start,
                );
              },
            );
          },
        );
      },
    );
  }
*/

  Widget _buildImageOnlyPage({
    required _ReaderPageSlice page,
    required String imageUrl,
    required double width,
    required double maxHeight,
    required AppSettings settings,
    required Color textColor,
    required Color linkColor,
  }) {
    final block = _blocks[page.start];

    return SizedBox.expand(
      child: ClipRect(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width, maxHeight: maxHeight),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: SizedBox(
                key: ValueKey('image_only_$imageUrl'),
                width: width,
                child: _buildBlockWidget(block, settings, textColor, linkColor),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHtmlPage({
    required _ReaderPageSlice page,
    required double width,
    required double maxHeight,
    required AppSettings settings,
    required Color textColor,
    required Color linkColor,
  }) {
    final blockWidgets = <Widget>[];
    for (int i = page.start; i < page.end; i++) {
      final topSpacing =
          i > page.start ? _paragraphSpacingBeforeBlock(i, settings) : 0.0;
      if (topSpacing > 0) {
        blockWidgets.add(SizedBox(height: topSpacing));
      }
      blockWidgets.add(
        _buildBlockWidget(_blocks[i], settings, textColor, linkColor),
      );
    }
    final measuredHeight = List<double>.generate(
      page.end - page.start,
      (offset) => _measuredBlockHeights[page.start + offset] ?? 0,
    ).fold<double>(0, (sum, value) => sum + value);
    final requiresScaleDown =
        page.end - page.start == 1 &&
        measuredHeight > 0 &&
        measuredHeight > maxHeight;

    Widget content = SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: blockWidgets,
      ),
    );

    if (requiresScaleDown) {
      content = FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topCenter,
        child: content,
      );
    }

    return SizedBox.expand(child: ClipRect(child: content));
  }

  Widget _buildMeasurementLayer({
    required String measureKey,
    required double width,
    required AppSettings settings,
    required Color textColor,
    required Color linkColor,
  }) {
    return Offstage(
      offstage: true,
      child: SingleChildScrollView(
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < _blocks.length; i++)
                _MeasureSize(
                  onChange:
                      (size) => _onMeasuredBlock(i, size.height, measureKey),
                  child: _buildBlockWidget(
                    _blocks[i],
                    settings,
                    textColor,
                    linkColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _measurementLayerFor({
    required String measureKey,
    required double width,
    required AppSettings settings,
    required Color textColor,
    required Color linkColor,
  }) {
    final cacheKey =
        '$measureKey|${width.toStringAsFixed(1)}|'
        '${textColor.toARGB32()}|${linkColor.toARGB32()}';
    if (_measurementLayerCacheKey != cacheKey ||
        _cachedMeasurementLayer == null) {
      _measurementLayerCacheKey = cacheKey;
      _cachedMeasurementLayer = _buildMeasurementLayer(
        measureKey: measureKey,
        width: width,
        settings: settings,
        textColor: textColor,
        linkColor: linkColor,
      );
    }
    return _cachedMeasurementLayer!;
  }

  String _displayTitle(AppSettings settings) {
    return buildReaderDisplayTitle(
      loading: _loading,
      cleanChapterTitle: settings.isCleanChapterTitleEnabled(
        AppSettings.cleanChapterTitleReaderTitleScope,
      ),
      chapterTitle: _chapter?.title,
      bookTitle: widget.bookTitle,
    );
  }

  void _showTitleSheet(BuildContext context) {
    unawaited(
      showReaderTitleSheet(
        context,
        bookId: widget.bid,
        bookTitle: widget.bookTitle,
        chapterTitle: _chapter?.title,
      ),
    );
  }

  Future<void> _exitPagedReader(BuildContext context) async {
    final navigator = Navigator.of(context);
    await _saveProgressForExit();
    if (mounted) {
      navigator.pop();
    }
  }

  void _handleTopMenuSelection(BuildContext context, String value) {
    switch (value) {
      case 'chapters':
        _openChapterList(context);
        return;
      case 'background':
        unawaited(_openReaderBackgroundPage(context));
        return;
    }
  }

  Future<void> _openReaderBackgroundPage(BuildContext context) async {
    final settings = ref.read(settingsProvider);
    final navigator = Navigator.of(context);
    final shouldHideNativeOverlay =
        PlatformInfo.isIOS && settings.useIOS26Style && _topOverlayVisible;

    if (shouldHideNativeOverlay && mounted) {
      setState(() {
        _topOverlayVisible = false;
      });
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }

    try {
      final route =
          PlatformInfo.isIOS
              ? CupertinoPageRoute<void>(
                builder: (context) => const ReaderBackgroundPage(),
              )
              : MaterialPageRoute<void>(
                builder: (context) => const ReaderBackgroundPage(),
              );
      await navigator.push(route);
    } finally {
      if (shouldHideNativeOverlay && mounted) {
        setState(() {
          _topOverlayVisible = true;
        });
      }
    }
  }

  Widget _buildBackButton(
    BuildContext context,
    AppSettings settings,
    Color textColor,
  ) {
    if (settings.useIOS26Style) {
      return SizedBox(
        width: _topBarButtonSize,
        height: _topBarButtonSize,
        child: AdaptiveButton.sfSymbol(
          onPressed: () => _exitPagedReader(context),
          sfSymbol: const SFSymbol('chevron.left', size: 20),
          style: AdaptiveButtonStyle.glass,
          borderRadius: BorderRadius.circular(1000),
          useSmoothRectangleBorder: false,
          padding: EdgeInsets.zero,
        ),
      );
    }

    if (PlatformInfo.isIOS) {
      return SizedBox(
        width: _topBarButtonSize,
        height: _topBarButtonSize,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          borderRadius: BorderRadius.circular(_topBarButtonSize / 2),
          onPressed: () => _exitPagedReader(context),
          child: Icon(CupertinoIcons.chevron_back, color: textColor, size: 22),
        ),
      );
    }

    return SizedBox(
      width: _topBarButtonSize,
      height: _topBarButtonSize,
      child: IconButton(
        onPressed: () => _exitPagedReader(context),
        icon: Icon(Icons.arrow_back, color: textColor),
      ),
    );
  }

  Widget _buildTopMenuButton(
    BuildContext context,
    AppSettings settings,
    Color textColor,
  ) {
    if (PlatformInfo.isIOS || PlatformInfo.isMacOS) {
      return AdaptivePopupMenuButton.icon<String>(
        icon: settings.useIOS26Style ? 'ellipsis' : CupertinoIcons.ellipsis,
        tint: Theme.of(context).colorScheme.primary,
        buttonStyle: PopupButtonStyle.glass,
        items: [
          AdaptivePopupMenuItem<String>(
            label: '章节列表',
            icon:
                settings.useIOS26Style
                    ? 'list.bullet'
                    : CupertinoIcons.list_bullet,
            value: 'chapters',
          ),
          AdaptivePopupMenuItem<String>(
            label: '阅读背景',
            icon:
                settings.useIOS26Style
                    ? 'paintbrush'
                    : CupertinoIcons.paintbrush,
            value: 'background',
          ),
        ],
        onSelected: (index, item) {
          final value = item.value;
          if (value == null) {
            return;
          }
          _handleTopMenuSelection(context, value);
        },
      );
    }

    return Builder(
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return PopupMenuButton<String>(
          icon: Icon(Icons.more_horiz, color: textColor),
          itemBuilder:
              (context) => [
                PopupMenuItem(
                  value: 'chapters',
                  child: Row(
                    children: [
                      Icon(Icons.list, color: colorScheme.onSurfaceVariant),
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
              ],
          onSelected: (value) => _handleTopMenuSelection(context, value),
        );
      },
    );
  }

  Widget _buildTitlePanel({
    required BuildContext context,
    required AppSettings settings,
    required Color textColor,
    Alignment alignment = Alignment.centerLeft,
    double horizontalPadding = 0,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showTitleSheet(context),
      child: SizedBox(
        height: _topBarButtonSize,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Align(
            alignment: alignment,
            child: _TitleMarqueeText(
              text: _displayTitle(settings),
              horizontalPadding: 0,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleCard(
    BuildContext context,
    AppSettings settings,
    Color textColor,
  ) {
    return _buildTitlePanel(
      context: context,
      settings: settings,
      textColor: textColor,
    );
  }

  Widget _buildTopOverlay(
    BuildContext context,
    AppSettings settings,
    Color textColor,
  ) {
    if (!_topOverlayVisible) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: MediaQuery.paddingOf(context).top + _topBarVerticalInset,
      left: _topBarHorizontalInset,
      right: _topBarHorizontalInset,
      child: Row(
        children: [
          _buildBackButton(context, settings, textColor),
          const SizedBox(width: _topBarGap),
          Expanded(child: _buildTitleCard(context, settings, textColor)),
          const SizedBox(width: _topBarGap),
          _buildTopMenuButton(context, settings, textColor),
        ],
      ),
    );
  }

  Widget _buildProgressPill(
    BuildContext context, {
    required IconData icon,
    required String value,
    required Color textColor,
  }) {
    final foregroundColor = textColor.withValues(alpha: 0.85);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: foregroundColor),
          const SizedBox(width: 6),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: foregroundColor),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomInfoStrip(
    BuildContext context,
    AppSettings settings,
    Color textColor,
  ) {
    final subTextColor = textColor.withValues(alpha: 0.65);
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ValueListenableBuilder<String>(
          valueListenable: _timeStringNotifier,
          builder: (context, timeString, _) {
            return Text(
              timeString,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: subTextColor,
                fontSize: 11,
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        ReaderBatteryIndicator(
          batteryLevelListenable: _batteryLevelNotifier,
          batteryStateListenable: _batteryStateNotifier,
          style: settings.effectiveReaderBatteryIndicatorStyle,
          color: subTextColor,
          textStyle: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: subTextColor, fontSize: 11),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    _applyReaderSystemUiMode(settings);
    final baseTheme = Theme.of(context);
    final currentScheme =
        (settings.coverColorExtraction ? _dynamicColorScheme : null) ??
        baseTheme.colorScheme;
    if (settings.coverColorExtraction &&
        _dynamicColorScheme == null &&
        widget.coverUrl != null &&
        widget.coverUrl!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _dynamicColorScheme == null) {
          _extractColors();
        }
      });
    }
    final currentTheme = baseTheme.copyWith(
      colorScheme: currentScheme,
      scaffoldBackgroundColor: currentScheme.surface,
      canvasColor: currentScheme.surface,
      bottomSheetTheme: baseTheme.bottomSheetTheme.copyWith(
        backgroundColor: currentScheme.surface,
        modalBackgroundColor: currentScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: baseTheme.popupMenuTheme.copyWith(
        color: currentScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        final navigator = Navigator.of(context);
        await _saveProgressForExit();
        if (mounted) {
          navigator.pop(result);
        }
      },
      child: AnimatedTheme(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        data: currentTheme,
        child: CupertinoTheme(
          data: MaterialBasedCupertinoThemeData(materialTheme: currentTheme),
          child: Builder(
            builder: (context) {
              final backgroundColor = _readerBackgroundColor(settings, context);
              final textColor = _readerTextColor(settings, context);
              final linkColor = Theme.of(context).colorScheme.primary;
              final systemOverlayStyle = _readerSystemOverlayStyle(
                backgroundColor,
              );
              _applyReaderSystemOverlayStyle(backgroundColor);
              final scaffold = AdaptiveScaffold(
                body: Container(
                  color: backgroundColor,
                  child: Stack(
                    children: [
                      _loading
                          ? const Center(child: M3ELoadingIndicator())
                          : _error != null
                          ? Center(
                            child: Text(_error!, textAlign: TextAlign.center),
                          )
                          : LayoutBuilder(
                            builder: (context, constraints) {
                              final useDoublePage =
                                  context.appWindowClass ==
                                  AppWindowClass.expanded;
                              final pageViewportWidth =
                                  useDoublePage
                                      ? ((constraints.maxWidth -
                                                  _doublePageGap) /
                                              2)
                                          .clamp(240.0, double.infinity)
                                      : constraints.maxWidth;
                              final horizontalPadding = settings
                                  .readerSidePadding
                                  .clamp(0.0, (pageViewportWidth - 48) / 2);
                              final contentWidth =
                                  pageViewportWidth - horizontalPadding * 2;
                              final contentTopPadding = _topContentPadding(
                                context,
                              );
                              final contentBottomPadding =
                                  _bottomContentPadding(context);
                              final measureKey =
                                  '${_chapter?.id}|${contentWidth.toStringAsFixed(1)}|'
                                  '${settings.fontSize.toStringAsFixed(2)}|'
                                  '${settings.readerLineHeight.toStringAsFixed(2)}|'
                                  '${settings.readerParagraphSpacing.toStringAsFixed(1)}|'
                                  '${settings.readerSidePadding.toStringAsFixed(1)}|'
                                  '${settings.readerFirstLineIndent}|'
                                  '${useDoublePage ? 'double' : 'single'}|'
                                  '${_fontFamily ?? ''}';
                              _activeMeasureKey = measureKey;
                              final measurementReady =
                                  _lastMeasureKey == measureKey &&
                                  _measuredBlockHeights.length ==
                                      _blocks.length;
                              final pages =
                                  measurementReady
                                      ? _buildPages(
                                        context,
                                        constraints,
                                        settings,
                                      )
                                      : const <_ReaderPageSlice>[];
                              final spreads =
                                  measurementReady
                                      ? _buildPageSpreads(
                                        pages,
                                        useDoublePage: useDoublePage,
                                      )
                                      : const <_ReaderPageSpread>[];
                              final pageSignature = pages
                                  .map(
                                    (page) =>
                                        '${page.start}-${page.end}:${page.xPath}',
                                  )
                                  .join('|');
                              final layoutKey =
                                  '${_chapter?.id}|${constraints.maxWidth.toStringAsFixed(1)}|'
                                  '${constraints.maxHeight.toStringAsFixed(1)}|'
                                  '${contentWidth.toStringAsFixed(1)}|'
                                  '${settings.fontSize.toStringAsFixed(2)}|'
                                  '${settings.readerLineHeight.toStringAsFixed(2)}|'
                                  '${settings.readerParagraphSpacing.toStringAsFixed(1)}|'
                                  '${settings.readerSidePadding.toStringAsFixed(1)}|'
                                  '${settings.readerFirstLineIndent}|'
                                  '${useDoublePage ? 'double' : 'single'}|'
                                  '$pageSignature';
                              final pageDisplayReady =
                                  measurementReady &&
                                  spreads.isNotEmpty &&
                                  _restoredLayoutKey == layoutKey;
                              if (measurementReady && spreads.isNotEmpty) {
                                _scheduleRestore(spreads, layoutKey);
                              }
                              return Stack(
                                children: [
                                  _measurementLayerFor(
                                    measureKey: measureKey,
                                    width: contentWidth,
                                    settings: settings,
                                    textColor: textColor,
                                    linkColor: linkColor,
                                  ),
                                  if (measurementReady && pages.isNotEmpty)
                                    IgnorePointer(
                                      ignoring: !pageDisplayReady,
                                      child: Opacity(
                                        opacity: pageDisplayReady ? 1 : 0,
                                        child: Builder(
                                          builder: (context) {
                                            final disablePageTurnAnimation =
                                                settings.readerPagedNoAnimation;
                                            final pageView = PageView.builder(
                                              controller: _pageController,
                                              physics:
                                                  disablePageTurnAnimation
                                                      ? const NeverScrollableScrollPhysics()
                                                      : null,
                                              itemCount: spreads.length,
                                              onPageChanged: (index) {
                                                _FootnoteAnchor.dismissCurrent();
                                                final xPath =
                                                    spreads[index].xPath;
                                                setState(() {
                                                  _currentPage = index;
                                                  _currentXPath = xPath;
                                                });
                                                unawaited(
                                                  _saveCurrentPosition(
                                                    xPath: xPath,
                                                  ),
                                                );
                                              },
                                              itemBuilder: (context, index) {
                                                final spread = spreads[index];

                                                Widget buildSpreadPage(
                                                  _ReaderPageSlice page,
                                                ) {
                                                  final imageOnly =
                                                      _isImageOnlyPage(page);
                                                  final pageBottomPadding =
                                                      imageOnly
                                                          ? _imageOnlyBottomContentPadding(
                                                            context,
                                                          )
                                                          : contentBottomPadding;
                                                  final effectiveBottomPadding =
                                                      pageBottomPadding >
                                                              contentBottomPadding
                                                          ? pageBottomPadding
                                                          : contentBottomPadding;
                                                  final pageContentHeight =
                                                      (constraints.maxHeight -
                                                              contentTopPadding -
                                                              effectiveBottomPadding)
                                                          .clamp(
                                                            220.0,
                                                            double.infinity,
                                                          );
                                                  return Padding(
                                                    padding: EdgeInsets.fromLTRB(
                                                      horizontalPadding,
                                                      contentTopPadding,
                                                      horizontalPadding,
                                                      effectiveBottomPadding,
                                                    ),
                                                    child:
                                                        _buildReaderPageContent(
                                                          page: page,
                                                          contentWidth:
                                                              contentWidth,
                                                          contentHeight:
                                                              pageContentHeight,
                                                          settings: settings,
                                                          textColor: textColor,
                                                          linkColor: linkColor,
                                                        ),
                                                  );
                                                }

                                                return GestureDetector(
                                                  behavior:
                                                      HitTestBehavior.opaque,
                                                  onTapUp: (details) {
                                                    final dx =
                                                        details
                                                            .localPosition
                                                            .dx;
                                                    if (dx <=
                                                        constraints.maxWidth *
                                                            0.35) {
                                                      _goToPreviousPage(
                                                        animated:
                                                            !disablePageTurnAnimation,
                                                      );
                                                    } else if (dx >=
                                                        constraints.maxWidth *
                                                            0.65) {
                                                      _goToNextPage(
                                                        pageCount:
                                                            spreads.length,
                                                        animated:
                                                            !disablePageTurnAnimation,
                                                      );
                                                    }
                                                  },
                                                  child:
                                                      useDoublePage
                                                          ? Row(
                                                            children: [
                                                              Expanded(
                                                                child: buildSpreadPage(
                                                                  spread
                                                                      .primary,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                width:
                                                                    _doublePageGap,
                                                              ),
                                                              Expanded(
                                                                child:
                                                                    spread.secondary !=
                                                                            null
                                                                        ? buildSpreadPage(
                                                                          spread
                                                                              .secondary!,
                                                                        )
                                                                        : const SizedBox.shrink(),
                                                              ),
                                                            ],
                                                          )
                                                          : buildSpreadPage(
                                                            spread.primary,
                                                          ),
                                                );
                                              },
                                            );

                                            if (!disablePageTurnAnimation) {
                                              return pageView;
                                            }

                                            return GestureDetector(
                                              behavior:
                                                  HitTestBehavior.translucent,
                                              onHorizontalDragStart:
                                                  _handleManualPageDragStart,
                                              onHorizontalDragUpdate:
                                                  _handleManualPageDragUpdate,
                                              onHorizontalDragCancel:
                                                  _handleManualPageDragCancel,
                                              onHorizontalDragEnd:
                                                  (_) =>
                                                      _handleManualPageDragEnd(
                                                        pageCount:
                                                            spreads.length,
                                                      ),
                                              child: pageView,
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  if (!pageDisplayReady)
                                    const Center(child: M3ELoadingIndicator()),
                                  if (pageDisplayReady)
                                    Positioned(
                                      left: 16,
                                      right: 16,
                                      bottom:
                                          _readerBottomPadding(context) +
                                          _indicatorBottomGap,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '第 $_targetSortNum / ${widget.totalChapters} 章',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall?.copyWith(
                                                color: textColor.withValues(
                                                  alpha: 0.0,
                                                ),
                                              ),
                                            ),
                                          ),
                                          _buildProgressPill(
                                            context,
                                            icon: Icons.book_outlined,
                                            value:
                                                '$_targetSortNum/${widget.totalChapters}',
                                            textColor: textColor,
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: textColor.withValues(
                                                alpha: 0.08,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.menu_book_outlined,
                                                  size: 15,
                                                  color: textColor.withValues(
                                                    alpha: 0.85,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  '${_currentPage + 1}/${spreads.length}',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: textColor
                                                            .withValues(
                                                              alpha: 0.85,
                                                            ),
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (measurementReady &&
                                      pages.isNotEmpty &&
                                      !settings.readerPagedShowSystemStatusBar)
                                    Positioned(
                                      left: 16,
                                      bottom:
                                          _readerBottomPadding(context) +
                                          _indicatorBottomGap +
                                          6,
                                      child: IgnorePointer(
                                        child: _buildBottomInfoStrip(
                                          context,
                                          settings,
                                          textColor,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                      _buildTopOverlay(context, settings, textColor),
                    ],
                  ),
                ),
              );
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: systemOverlayStyle,
                child: scaffold,
              );
            },
          ),
        ),
      ),
    );
  }
}

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
    with SingleTickerProviderStateMixin {
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

    if (_currentOpen != null && _currentOpen != this) {
      _currentOpen!._removeOverlay();
    }
    _currentOpen = this;
    _showOverlay();
  }

  void _showOverlay() {
    if (!mounted) {
      return;
    }

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return;
    }

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
    _fadeController.value = 0;

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        return Stack(
          children: [
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

    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
    _fadeController.forward();
  }

  String _normalizeFootnoteHtml(String html) {
    try {
      final doc = html_parser.parse('<div id="__root__">$html</div>');
      final root = doc.getElementById('__root__');
      if (root == null) {
        return html;
      }

      for (final anchor in root.querySelectorAll('a')) {
        if (anchor.text.trim().isEmpty && anchor.children.isEmpty) {
          anchor.remove();
        }
      }

      final items =
          root
              .querySelectorAll('li')
              .map((element) => element.innerHtml.trim())
              .where((html) => html.isNotEmpty)
              .toList();
      if (items.isNotEmpty) {
        return items.map((html) => '<div>$html</div>').join();
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
                if (element.localName == 'ol' || element.localName == 'ul') {
                  return {
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
    if (entry == null) {
      return;
    }

    if (!animate) {
      entry.remove();
      _overlayEntry = null;
      _isClosing = false;
      _fadeController.stop();
      _fadeController.value = 0;
      if (_currentOpen == this) {
        _currentOpen = null;
      }
      return;
    }

    if (_isClosing) {
      return;
    }
    _isClosing = true;

    _fadeController
        .reverse()
        .then((_) {
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

class _MeasureSize extends SingleChildRenderObjectWidget {
  final ValueChanged<Size> onChange;

  const _MeasureSize({required this.onChange, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderMeasureSize(onChange);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasureSize renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

class _RenderMeasureSize extends RenderProxyBox {
  _RenderMeasureSize(this.onChange);

  ValueChanged<Size> onChange;
  Size? _oldSize;

  @override
  void performLayout() {
    super.performLayout();
    final newSize = child?.size;
    if (newSize == null || _oldSize == newSize) {
      return;
    }
    _oldSize = newSize;
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(newSize));
  }
}

class _TitleMarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final double horizontalPadding;

  const _TitleMarqueeText({
    required this.text,
    this.style,
    this.horizontalPadding = 0,
  });

  @override
  State<_TitleMarqueeText> createState() => _TitleMarqueeTextState();
}

class _TitleMarqueeTextState extends State<_TitleMarqueeText>
    with SingleTickerProviderStateMixin {
  static const double _gap = 48;
  static const double _scrollSpeed = 30;
  static const Duration _pauseDuration = Duration(seconds: 2);

  late final AnimationController _controller;
  Timer? _pauseTimer;
  bool _disposed = false;
  double _textWidth = 0;
  double _textHeight = 0;
  double _containerWidth = 0;
  bool _needsScroll = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _controller.addStatusListener(_onAnimationStatus);
  }

  @override
  void didUpdateWidget(covariant _TitleMarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _stopAnimation();
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
    if (_disposed || !mounted) {
      return;
    }
    if (status == AnimationStatus.completed) {
      _controller.value = 0;
      _pauseTimer = Timer(_pauseDuration, _startScroll);
    }
  }

  void _measure(double containerWidth) {
    if (_disposed || !mounted) {
      return;
    }

    final textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();

    final textWidth = textPainter.width;
    final textHeight = textPainter.height;
    textPainter.dispose();

    final shouldScroll =
        textWidth > (containerWidth - 2 * widget.horizontalPadding);

    if (textWidth != _textWidth || containerWidth != _containerWidth) {
      _textWidth = textWidth;
      _textHeight = textHeight;
      _containerWidth = containerWidth;

      _stopAnimation();
      if (shouldScroll != _needsScroll) {
        setState(() {
          _needsScroll = shouldScroll;
        });
      }
      if (shouldScroll) {
        _pauseTimer = Timer(_pauseDuration, _startScroll);
      }
    }
  }

  void _stopAnimation() {
    _pauseTimer?.cancel();
    _pauseTimer = null;
    _controller.stop();
    _controller.value = 0;
  }

  void _startScroll() {
    if (_disposed || !mounted || !_needsScroll) {
      return;
    }

    final scrollDistance = _textWidth + _gap;
    final durationMs = (scrollDistance / _scrollSpeed * 1000).round();
    _controller.duration = Duration(milliseconds: durationMs);
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_disposed && mounted) {
            _measure(constraints.maxWidth);
          }
        });

        if (!_needsScroll) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: widget.horizontalPadding),
            child: Text(
              widget.text,
              style: widget.style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
            ),
          );
        }

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
                    SizedBox(width: widget.horizontalPadding),
                    Text(widget.text, style: widget.style, maxLines: 1),
                    const SizedBox(width: _gap),
                    Text(widget.text, style: widget.style, maxLines: 1),
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
