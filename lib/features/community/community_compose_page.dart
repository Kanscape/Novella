import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:novella/data/models/community.dart';
import 'package:novella/data/services/community_service.dart';
import 'package:novella/features/community/community_board_icon.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

class CommunityComposePage extends StatefulWidget {
  const CommunityComposePage({super.key});

  @override
  State<CommunityComposePage> createState() => _CommunityComposePageState();
}

class _CommunityComposePageState extends State<CommunityComposePage> {
  final CommunityService _communityService = CommunityService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final QuillController _quillController = QuillController.basic();

  bool _loadingCatalog = true;
  bool _submitting = false;
  String? _errorMessage;
  List<CommunityCatalogBoard> _catalogBoards = const <CommunityCatalogBoard>[];
  String? _selectedBoardKey;
  String _selectedSubCategoryKey = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_loadCatalogBoards());
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _quillController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalogBoards() async {
    setState(() {
      _loadingCatalog = true;
      _errorMessage = null;
    });

    try {
      final payload = await _communityService.getCommunityHome();
      if (!mounted) {
        return;
      }

      final boards = payload.catalogBoards;
      final initialBoardKey =
          boards.isNotEmpty ? boards.first.key : _selectedBoardKey;
      final initialSubCategoryKey = _pickDefaultSubCategory(
        boards,
        initialBoardKey,
      );

      setState(() {
        _catalogBoards = boards;
        _selectedBoardKey = initialBoardKey;
        _selectedSubCategoryKey = initialSubCategoryKey;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = _formatError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingCatalog = false;
        });
      }
    }
  }

  String _pickDefaultSubCategory(
    List<CommunityCatalogBoard> boards,
    String? boardKey,
  ) {
    if (boardKey == null || boardKey.isEmpty) {
      return '';
    }

    final board = _findBoardByKey(boards, boardKey);
    if (board == null || board.subCategories.isEmpty) {
      return '';
    }

    return board.subCategories.first.key;
  }

  CommunityCatalogBoard? _findBoardByKey(
    List<CommunityCatalogBoard> boards,
    String boardKey,
  ) {
    for (final board in boards) {
      if (board.key == boardKey) {
        return board;
      }
    }
    return null;
  }

  CommunityCatalogBoard? get _selectedBoard {
    final boardKey = _selectedBoardKey;
    if (boardKey == null || boardKey.isEmpty) {
      return null;
    }
    return _findBoardByKey(_catalogBoards, boardKey);
  }

  List<CommunityCatalogSubCategory> get _selectedSubCategories {
    return _selectedBoard?.subCategories ??
        const <CommunityCatalogSubCategory>[];
  }

  CommunityCatalogSubCategory? get _selectedSubCategory {
    for (final item in _selectedSubCategories) {
      if (item.key == _selectedSubCategoryKey) {
        return item;
      }
    }
    return null;
  }

  int get _bodyLength {
    return _quillController.document
        .toPlainText()
        .replaceAll(RegExp(r'\s+'), '')
        .length;
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    if (_selectedBoardKey == null || _selectedBoardKey!.isEmpty) {
      _showSnack('请先选择板块。');
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_bodyLength < 20) {
      _showSnack('正文至少 20 个字。');
      return;
    }

    final htmlContent = _convertDeltaToHtml();
    if (htmlContent.isEmpty) {
      _showSnack('正文不能为空。');
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final createdThread = await _communityService.createCommunityThread(
        CreateCommunityThreadRequest(
          boardKey: _selectedBoardKey!,
          subCategoryKey: _selectedSubCategoryKey,
          title: _titleController.text.trim(),
          contentHtml: htmlContent,
        ),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(createdThread);
    } catch (error) {
      _showSnack(_formatError(error));
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  String _convertDeltaToHtml() {
    final rawOps = _quillController.document.toDelta().toJson();
    final normalizedOps = rawOps
        .whereType<Map>()
        .map((op) => Map<String, dynamic>.from(op))
        .toList(growable: false);

    if (normalizedOps.isEmpty) {
      return '';
    }

    final converter = QuillDeltaToHtmlConverter(
      normalizedOps,
      ConverterOptions.forEmail(),
    );
    return converter.convert().trim();
  }

  void _onBoardChanged(String? value) {
    if (value == null || value.isEmpty || value == _selectedBoardKey) {
      return;
    }

    final nextSubCategoryKey = _pickDefaultSubCategory(_catalogBoards, value);
    setState(() {
      _selectedBoardKey = value;
      _selectedSubCategoryKey = nextSubCategoryKey;
    });
  }

  void _onSubCategoryChanged(String? value) {
    if (value == null) {
      return;
    }

    setState(() {
      _selectedSubCategoryKey = value;
    });
  }

  Future<void> _openBoardPicker() async {
    if (_catalogBoards.isEmpty || _submitting) {
      return;
    }

    final selected = await _showPickerSheet(
      title: '选择板块',
      items: _catalogBoards
          .map(
            (board) => _PickerItemData(
              value: board.key,
              title: board.title,
              subtitle: board.description,
              accent: _boardAccentColor(context, board.key),
              iconName: board.icon,
              fallbackText: board.title,
            ),
          )
          .toList(growable: false),
      selectedValue: _selectedBoardKey,
    );

    if (!mounted || selected == null) {
      return;
    }
    _onBoardChanged(selected);
  }

  Future<void> _openSubCategoryPicker() async {
    if (_selectedSubCategories.isEmpty || _submitting) {
      return;
    }

    final selected = await _showPickerSheet(
      title: '选择子分类',
      items: <_PickerItemData>[
        const _PickerItemData(value: '', title: '不选择'),
        ..._selectedSubCategories.map(
          (item) => _PickerItemData(value: item.key, title: item.label),
        ),
      ],
      selectedValue: _selectedSubCategoryKey,
    );

    if (!mounted || selected == null) {
      return;
    }
    _onSubCategoryChanged(selected);
  }

  Future<String?> _showPickerSheet({
    required String title,
    required List<_PickerItemData> items,
    required String? selectedValue,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: colorScheme.surface,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                child: Text(
                  title,
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              for (final item in items)
                _PickerSheetItem(
                  title: item.title,
                  subtitle: item.subtitle,
                  iconName: item.iconName,
                  fallbackText: item.fallbackText,
                  accent: item.accent,
                  selected: item.value == selectedValue,
                  onTap: () => Navigator.of(sheetContext).pop(item.value),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatError(Object error) {
    final message = error.toString().trim();
    if (message.isEmpty) {
      return '发布帖子失败，请稍后重试。';
    }
    return message.startsWith('Exception:')
        ? message.substring('Exception:'.length).trim()
        : message;
  }

  Color _boardAccentColor(BuildContext context, String key) {
    final colorScheme = Theme.of(context).colorScheme;
    return colorScheme.primary;
  }

  QuillSimpleToolbarConfig _buildToolbarConfig(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconTheme = QuillIconTheme(
      iconButtonUnselectedData: IconButtonData(
        style: IconButton.styleFrom(
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurfaceVariant,
          minimumSize: const Size(34, 34),
          padding: const EdgeInsets.all(6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
        visualDensity: VisualDensity.compact,
      ),
      iconButtonSelectedData: IconButtonData(
        style: IconButton.styleFrom(
          backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.72),
          foregroundColor: colorScheme.primary,
          minimumSize: const Size(34, 34),
          padding: const EdgeInsets.all(6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
        visualDensity: VisualDensity.compact,
      ),
    );

    return QuillSimpleToolbarConfig(
      multiRowsDisplay: false,
      showDividers: true,
      toolbarSize: 26,
      toolbarSectionSpacing: 6,
      sectionDividerSpace: 10,
      sectionDividerColor: colorScheme.outlineVariant.withValues(alpha: 0.24),
      color: Colors.transparent,
      iconTheme: iconTheme,
      showFontFamily: false,
      showFontSize: false,
      showBoldButton: true,
      showItalicButton: true,
      showSmallButton: false,
      showUnderLineButton: false,
      showLineHeightButton: false,
      showStrikeThrough: false,
      showInlineCode: false,
      showColorButton: false,
      showBackgroundColorButton: false,
      showClearFormat: false,
      showAlignmentButtons: false,
      showHeaderStyle: true,
      showListNumbers: true,
      showListBullets: true,
      showListCheck: false,
      showCodeBlock: true,
      showQuote: true,
      showIndent: false,
      showLink: true,
      showUndo: true,
      showRedo: true,
      showDirection: false,
      showSearchButton: false,
      showSubscript: false,
      showSuperscript: false,
    );
  }

  Widget _buildContextStrip(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final board = _selectedBoard;
    final accent =
        board == null
            ? colorScheme.primary
            : _boardAccentColor(context, board.key);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CommunityBoardIconBadge(
                accent: accent,
                iconName: board?.icon ?? '',
                fallbackText: board?.title ?? '社区',
                size: 40,
                iconSize: 18,
                borderRadius: 14,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      board?.title ?? '选择一个板块开始写作',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      board?.description.isNotEmpty == true
                          ? board!.description
                          : '这里更像一个连续的编辑器，而不是拆成很多格子的表单页。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              const _HintChip(label: '标题至少 6 个字', icon: Icons.title_rounded),
              const _HintChip(label: '正文至少 20 个字', icon: Icons.notes_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComposerSurface(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final board = _selectedBoard;
    final accent =
        board == null
            ? colorScheme.primary
            : _boardAccentColor(context, board.key);
    final subCategory = _selectedSubCategory;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 28),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
              child: TextFormField(
                controller: _titleController,
                maxLength: 60,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: '给这篇帖子起一个清晰的标题',
                  hintStyle: theme.textTheme.headlineSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
                    fontWeight: FontWeight.w600,
                  ),
                  border: InputBorder.none,
                  counterText: '',
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                  height: 1.22,
                ),
                validator: (value) {
                  final title = value?.trim() ?? '';
                  if (title.isEmpty) {
                    return '请输入标题。';
                  }
                  if (title.length < 6) {
                    return '标题至少 6 个字。';
                  }
                  return null;
                },
              ),
            ),
            Divider(
              height: 22,
              color: colorScheme.outlineVariant.withValues(alpha: 0.28),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _ComposePickerChip(
                    label: board?.title ?? '选择板块',
                    icon: Icons.dashboard_outlined,
                    accent: accent,
                    iconName: board?.icon,
                    fallbackText: board?.title,
                    onTap: _openBoardPicker,
                  ),
                  if (_selectedSubCategories.isNotEmpty)
                    _ComposePickerChip(
                      label: subCategory?.label ?? '子分类',
                      icon: Icons.tune_rounded,
                      onTap: _openSubCategoryPicker,
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
              child: Row(
                children: [
                  Text(
                    '正文',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  AnimatedBuilder(
                    animation: _quillController,
                    builder: (context, _) {
                      return Text(
                        '$_bodyLength 字',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.26),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Theme(
                data: theme.copyWith(
                  dividerColor: colorScheme.outlineVariant.withValues(
                    alpha: 0.18,
                  ),
                ),
                child: QuillSimpleToolbar(
                  controller: _quillController,
                  config: _buildToolbarConfig(context),
                ),
              ),
            ),
            Divider(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.26),
            ),
            SizedBox(
              height: 420,
              child: QuillEditor.basic(
                controller: _quillController,
                config: const QuillEditorConfig(
                  placeholder: '写下你的内容，正文至少 20 个字...',
                  padding: EdgeInsets.fromLTRB(18, 16, 18, 18),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '发布后会直接进入社区帖子页，建议先检查标题、板块和正文节奏。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.42,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStateCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.76,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  if (onAction != null && actionLabel != null) ...[
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: onAction,
                      child: Text(actionLabel),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCatalog = _catalogBoards.isNotEmpty;
    final canSubmit =
        !_submitting &&
        !_loadingCatalog &&
        _selectedBoardKey != null &&
        _selectedBoardKey!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('发布帖子'),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: canSubmit ? _submit : null,
              child:
                  _submitting
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text('发布'),
            ),
          ),
        ],
      ),
      body:
          _loadingCatalog && !hasCatalog
              ? const Center(child: CircularProgressIndicator())
              : Form(
                key: _formKey,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 12),
                  children: [
                    _buildContextStrip(context),
                    if (_errorMessage != null && !hasCatalog)
                      _buildStateCard(
                        context,
                        icon: Icons.error_outline_rounded,
                        title: '加载失败',
                        message: _errorMessage!,
                        actionLabel: '重试',
                        onAction: _loadCatalogBoards,
                      )
                    else if (!hasCatalog)
                      _buildStateCard(
                        context,
                        icon: Icons.forum_outlined,
                        title: '当前没有可用板块',
                        message: '请稍后再试，或者刷新后重新加载社区数据。',
                      )
                    else
                      _buildComposerSurface(context),
                    if (_errorMessage != null && hasCatalog)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
    );
  }
}

class _HintChip extends StatelessWidget {
  const _HintChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposePickerChip extends StatelessWidget {
  const _ComposePickerChip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.accent,
    this.iconName,
    this.fallbackText,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? accent;
  final String? iconName;
  final String? fallbackText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground = accent ?? colorScheme.onSurface;
    final background =
        accent == null
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.58)
            : accent!.withValues(alpha: 0.12);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  accent == null
                      ? colorScheme.outlineVariant.withValues(alpha: 0.22)
                      : accent!.withValues(alpha: 0.26),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if ((iconName?.isNotEmpty ?? false) ||
                  (fallbackText?.isNotEmpty ?? false)) ...[
                CommunityBoardIconBadge(
                  accent: foreground,
                  iconName: iconName ?? '',
                  fallbackText: fallbackText ?? label,
                  size: 18,
                  iconSize: 11,
                  borderRadius: 6,
                ),
                const SizedBox(width: 8),
              ] else ...[
                Icon(icon, size: 16, color: foreground),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.expand_more_rounded, size: 18, color: foreground),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerItemData {
  const _PickerItemData({
    required this.value,
    required this.title,
    this.subtitle,
    this.accent,
    this.iconName,
    this.fallbackText,
  });

  final String value;
  final String title;
  final String? subtitle;
  final Color? accent;
  final String? iconName;
  final String? fallbackText;
}

class _PickerSheetItem extends StatelessWidget {
  const _PickerSheetItem({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.accent,
    this.iconName,
    this.fallbackText,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Color? accent;
  final String? iconName;
  final String? fallbackText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveAccent = accent ?? colorScheme.primary;
    final background =
        selected
            ? effectiveAccent.withValues(alpha: 0.1)
            : colorScheme.surfaceContainerLow;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color:
                    selected
                        ? effectiveAccent.withValues(alpha: 0.34)
                        : colorScheme.outlineVariant.withValues(alpha: 0.24),
              ),
            ),
            child: Row(
              children: [
                if ((iconName?.isNotEmpty ?? false) ||
                    (fallbackText?.isNotEmpty ?? false))
                  CommunityBoardIconBadge(
                    accent: effectiveAccent,
                    iconName: iconName ?? '',
                    fallbackText: fallbackText ?? title,
                    size: 32,
                    iconSize: 16,
                    borderRadius: 10,
                  )
                else
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color:
                        selected
                            ? effectiveAccent
                            : colorScheme.onSurfaceVariant,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (selected) Icon(Icons.check_rounded, color: effectiveAccent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
