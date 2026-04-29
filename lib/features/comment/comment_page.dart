import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:novella/core/theme/app_color_profiles.dart';
import 'package:novella/core/utils/cover_url_utils.dart';
import 'package:novella/core/widgets/m3e_loading_indicator.dart';
import 'package:novella/data/models/comment.dart';
import 'package:novella/data/services/comment_service.dart';
import 'package:novella/features/comment/widgets/comment_input_sheet.dart';
import 'package:novella/features/comment/widgets/comment_item.dart';
import 'package:novella/features/settings/settings_provider.dart';

class CommentPage extends ConsumerStatefulWidget {
  final CommentType type;
  final int id;
  final String title; // 关联对象标题，用于 AppBar
  final String? coverUrl;

  const CommentPage({
    super.key,
    required this.type,
    required this.id,
    required this.title,
    this.coverUrl,
  });

  @override
  ConsumerState<CommentPage> createState() => _CommentPageState();
}

class _CommentPageState extends ConsumerState<CommentPage> {
  static final Logger _logger = Logger('CommentPage');
  static final Map<String, ColorScheme> _schemeCache = {};
  final CommentService _service = CommentService();
  final ScrollController _scrollController = ScrollController();

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  ColorScheme? _dynamicColorScheme;

  int _currentPage = 1;
  int _totalPages = 1;
  final List<CommentItem> _items = [];

  @override
  void initState() {
    super.initState();
    // 延迟加载，防止卡住页面转场动画 (Hero/Slide transition)
    // 等待动画结束后再发起请求和渲染列表
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        _loadData();
      }
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dynamicColorScheme == null) {
      _extractColors();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _currentPage < _totalPages) {
      _loadMore();
    }
  }

  void _extractColors() {
    final coverUrl = widget.coverUrl;
    if (coverUrl == null || coverUrl.isEmpty) {
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
    final cacheKey = '${widget.id}_$colorProfile';

    if (_schemeCache.containsKey(cacheKey)) {
      if (mounted) {
        setState(() {
          _dynamicColorScheme = _schemeCache[cacheKey]!;
        });
      }
      return;
    }

    final seedColor = CoverUrlUtils.extractSeedColor(coverUrl);
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

  ColorScheme _effectiveColorScheme(AppSettings settings) {
    return (settings.coverColorExtraction ? _dynamicColorScheme : null) ??
        Theme.of(context).colorScheme;
  }

  ThemeData _effectiveThemeData(BuildContext context, AppSettings settings) {
    final baseTheme = Theme.of(context);
    final colorScheme = _effectiveColorScheme(settings);
    return baseTheme.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      canvasColor: colorScheme.surface,
      appBarTheme: baseTheme.appBarTheme.copyWith(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButtonTheme: baseTheme.floatingActionButtonTheme.copyWith(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
      ),
    );
  }

  Future<void> _loadData({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _error = null;
      });
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final data = await _service.getComments(
        type: widget.type,
        id: widget.id,
        page: _currentPage,
      );

      if (mounted) {
        setState(() {
          _loading = false;
          _totalPages = data.totalPages;
          if (refresh || _currentPage == 1) {
            _items.clear();
          }
          _items.addAll(data.items);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _loadMore() async {
    setState(() {
      _loadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final data = await _service.getComments(
        type: widget.type,
        id: widget.id,
        page: nextPage,
      );

      if (mounted) {
        setState(() {
          _currentPage = nextPage;
          _totalPages = data.totalPages;
          _items.addAll(data.items);
          _loadingMore = false;
        });
      }
    } catch (e) {
      _logger.warning('Failed to load more comments: $e');
      if (mounted) {
        setState(() {
          _loadingMore = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载更多失败: $e')));
      }
    }
  }

  // 显示回复输入框
  void _showReplySheet({
    required String hintText,
    int? replyId,
    int? parentId,
  }) {
    final theme = _effectiveThemeData(context, ref.read(settingsProvider));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 允许全屏高度以便键盘顶起
      builder:
          (context) => Theme(
            data: theme,
            child: CommentInputSheet(
              hintText: hintText,
              onSubmit:
                  (content) => _postComment(
                    content,
                    replyId: replyId,
                    parentId: parentId,
                  ),
            ),
          ),
    );
  }

  Future<void> _postComment(
    String content, {
    int? replyId,
    int? parentId,
  }) async {
    try {
      // 显示全屏 Loading 这里暂用 SnackBar 过渡
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('正在发布...'),
          duration: Duration(milliseconds: 500),
        ),
      );

      if (replyId != null || parentId != null) {
        await _service.replyComment(
          PostCommentRequest(
            type: widget.type,
            id: widget.id,
            content: content,
            replyId: replyId,
            parentId: parentId,
          ),
        );
      } else {
        await _service.postComment(
          PostCommentRequest(
            type: widget.type,
            id: widget.id,
            content: content,
          ),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('发布成功')));
        // 刷新列表
        _loadData(refresh: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发布失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteComment(int id) async {
    final theme = _effectiveThemeData(context, ref.read(settingsProvider));
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder:
          (context) => Theme(
            data: theme,
            child: Builder(
              builder: (context) {
                final colorScheme = Theme.of(context).colorScheme;
                final textTheme = Theme.of(context).textTheme;
                return SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Text(
                          '删除评论',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Text(
                          '确定要删除这条评论吗？此操作无法撤销。',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      ListTile(
                        leading: Icon(Icons.delete, color: colorScheme.error),
                        title: Text(
                          '确认删除',
                          style: TextStyle(
                            color: colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () => Navigator.pop(context, true),
                      ),
                      ListTile(
                        leading: Icon(
                          Icons.close,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        title: const Text('取消'),
                        onTap: () => Navigator.pop(context, false),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            ),
          ),
    );

    if (confirm == true) {
      try {
        await _service.deleteComment(id);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('删除成功')));
          _loadData(refresh: true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
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

    final pageTheme = _effectiveThemeData(context, settings);

    return Theme(
      data: pageTheme,
      child: Scaffold(
        resizeToAvoidBottomInset: false, // Prevent FAB jumping
        appBar: AppBar(title: const Text('评论')),
        body:
            _loading
                ? const Center(child: M3ELoadingIndicator())
                : _error != null
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('加载失败: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _loadData(refresh: true),
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
                : _items.isEmpty
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 64,
                        color: pageTheme.disabledColor,
                      ),
                      const SizedBox(height: 16),
                      const Text('暂无评论，快来抢沙发吧~'),
                    ],
                  ),
                )
                : RefreshIndicator(
                  onRefresh: () async => _loadData(refresh: true),
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _items.length + (_loadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _items.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0), // Simplified padding
                          child: Center(child: M3ELoadingIndicator()),
                        );
                      }

                      final item = _items[index];
                      return CommentItemWidget(
                        item: item,
                        onReply:
                            () => _showReplySheet(
                              hintText: '回复 ${item.user.userName}',
                              parentId: item.id, // 一级 ID 即为 ParentId
                            ),
                        onDelete: () => _deleteComment(item.id),
                        onReplyToReply:
                            (reply) => _showReplySheet(
                              hintText: '回复 ${reply.user.userName}',
                              parentId: item.id, // ParentId 始终是一级评论 ID
                              replyId: reply.id, // 指向具体的回复 ID
                            ),
                        onDeleteReply: (replyId) => _deleteComment(replyId),
                      );
                    },
                  ),
                ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showReplySheet(hintText: '发表评论...'),
          label: const Text('写评论'),
          icon: const Icon(Icons.edit),
        ),
        bottomNavigationBar: null, // 移除底部固定栏
      ),
    );
  }
}
