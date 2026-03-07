import 'package:flutter/material.dart';

enum ShelfEditAction { move, delete, rename }

class ShelfMoveDestination {
  final String title;
  final String? subtitle;
  final List<String> parents;
  final bool isRoot;

  const ShelfMoveDestination({
    required this.title,
    required this.parents,
    this.subtitle,
    this.isRoot = false,
  });
}

String _buildSelectionSummary({
  required int selectedBookCount,
  required int selectedFolderCount,
}) {
  final folderSummary = '$selectedFolderCount 个文件夹';
  if (selectedFolderCount > 0 && selectedBookCount > 0) {
    return '$selectedBookCount 本书，$folderSummary';
  }
  if (selectedFolderCount > 0) {
    return folderSummary;
  }
  return '$selectedBookCount 本书';
}

Future<ShelfEditAction?> showShelfEditActionSheet({
  required BuildContext context,
  required int selectedBookCount,
  required int selectedFolderCount,
  required int selectedFolderBookCount,
  required bool canMove,
  bool showRenameOption = false,
  bool canRename = false,
  String? moveDisabledReason,
  String? renameDisabledReason,
}) {
  return showModalBottomSheet<ShelfEditAction>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final colorScheme = Theme.of(sheetContext).colorScheme;
      final textTheme = Theme.of(sheetContext).textTheme;
      final selectionSummary = _buildSelectionSummary(
        selectedBookCount: selectedBookCount,
        selectedFolderCount: selectedFolderCount,
      );
      final selectionHint =
          selectedFolderCount > 0
              ? '选择要对这些项目执行的操作'
              : '选择要对这些书籍执行的操作';
      final nestedFolderHint =
          selectedFolderCount > 0 && selectedFolderBookCount > 0
              ? '此外，文件夹内包含 $selectedFolderBookCount 本'
              : null;

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                '已选 $selectionSummary',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectionHint,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (nestedFolderHint != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      nestedFolderHint,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ListTile(
              enabled: canMove,
              leading: Icon(
                Icons.drive_file_move_outline,
                color:
                    canMove
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
              ),
              title: const Text('移动'),
              subtitle: Text(
                canMove
                    ? '移动到根文件夹或其它文件夹'
                    : (moveDisabledReason ??
                        '当前选择不支持移动'),
              ),
              onTap:
                  canMove
                      ? () {
                        Navigator.pop(sheetContext, ShelfEditAction.move);
                      }
                      : null,
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: colorScheme.error),
              title: Text(
                '删除',
                style: TextStyle(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                selectedFolderCount > 0
                    ? '从书架删除所选书籍和文件夹内容'
                    : '从书架移出所选书籍',
              ),
              onTap: () {
                Navigator.pop(sheetContext, ShelfEditAction.delete);
              },
            ),
            if (showRenameOption)
              ListTile(
                enabled: canRename,
                leading: Icon(
                  Icons.drive_file_rename_outline,
                  color:
                      canRename
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                ),
                title: const Text('重命名'),
                subtitle: Text(
                  canRename
                      ? '修改选中文件夹名称'
                      : (renameDisabledReason ??
                          '仅支持单选文件夹重命名'),
                ),
                onTap:
                    canRename
                        ? () {
                          Navigator.pop(sheetContext, ShelfEditAction.rename);
                        }
                        : null,
              ),
            const SizedBox(height: 16),
          ],
        ),
      );
    },
  );
}

Future<bool> showShelfDeleteConfirmSheet({
  required BuildContext context,
  required int selectedBookCount,
  required int selectedFolderCount,
  required int selectedFolderBookCount,
}) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isDismissible: false,
    builder: (sheetContext) {
      final colorScheme = Theme.of(sheetContext).colorScheme;
      final textTheme = Theme.of(sheetContext).textTheme;
      final selectionSummary = _buildSelectionSummary(
        selectedBookCount: selectedBookCount,
        selectedFolderCount: selectedFolderCount,
      );
      final deleteHint =
          selectedFolderCount > 0 && selectedFolderBookCount > 0
              ? '确定要从书架删除所选的 $selectionSummary 吗？文件夹内含 $selectedFolderBookCount 本书也会一并删除。'
              : null;

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                selectedFolderCount > 0
                    ? '删除所选项目'
                    : '移出书架',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                selectedFolderCount > 0
                    ? (deleteHint ??
                        '确定要从书架删除所选的 $selectionSummary 吗？')
                    : '确定要将选中的 $selectionSummary 移出书架吗？',
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
                  fontWeight: FontWeight.w700,
                ),
              ),
              onTap: () => Navigator.pop(sheetContext, true),
            ),
            ListTile(
              leading: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
              title: const Text('取消'),
              onTap: () => Navigator.pop(sheetContext, false),
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    },
  );

  return confirmed == true;
}

Future<List<String>?> showShelfMoveDestinationSheet({
  required BuildContext context,
  required int selectedBookCount,
  required List<ShelfMoveDestination> destinations,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final colorScheme = Theme.of(sheetContext).colorScheme;
      final textTheme = Theme.of(sheetContext).textTheme;
      return DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.6,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Text(
                  '移动 $selectedBookCount 本书到...',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  '可以移到根文件夹或其它文件夹',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child:
                    destinations.isEmpty
                        ? Center(
                          child: Text(
                            '当前没有可移动的目标',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                        : ListView.builder(
                          controller: scrollController,
                          itemCount: destinations.length,
                          itemBuilder: (context, index) {
                            final destination = destinations[index];
                            return ListTile(
                              leading: Icon(
                                destination.isRoot
                                    ? Icons.home_outlined
                                    : Icons.folder_copy_outlined,
                                color:
                                    destination.isRoot
                                        ? colorScheme.primary
                                        : colorScheme.onSurfaceVariant,
                              ),
                              title: Text(destination.title),
                              subtitle:
                                  destination.subtitle == null ||
                                          destination.subtitle!.isEmpty
                                      ? null
                                      : Text(destination.subtitle!),
                              onTap: () {
                                Navigator.pop(
                                  sheetContext,
                                  destination.parents,
                                );
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

Future<String?> _showShelfFolderNameSheet({
  required BuildContext context,
  required String title,
  required String subtitle,
  required String hintText,
  required String confirmLabel,
  required IconData icon,
  String initialValue = '',
}) {
  final controller = TextEditingController(text: initialValue);
  controller.selection = TextSelection(
    baseOffset: 0,
    extentOffset: controller.text.length,
  );

  return showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final colorScheme = Theme.of(sheetContext).colorScheme;
      final textTheme = Theme.of(sheetContext).textTheme;
      var folderName = initialValue;

      return StatefulBuilder(
        builder: (context, setSheetState) {
          final trimmedName = folderName.trim();

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
              ),
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
                      title,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      onChanged: (value) {
                        setSheetState(() {
                          folderName = value;
                        });
                      },
                      onSubmitted: (value) {
                        final nextName = value.trim();
                        if (nextName.isNotEmpty) {
                          Navigator.pop(sheetContext, nextName);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: hintText,
                        prefixIcon: Icon(icon),
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Text('取消'),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed:
                              trimmedName.isEmpty
                                  ? null
                                  : () =>
                                      Navigator.pop(sheetContext, trimmedName),
                          icon: Icon(icon),
                          label: Text(confirmLabel),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  ).then((value) {
    controller.dispose();
    return value;
  });
}

Future<String?> showShelfCreateFolderSheet({required BuildContext context}) {
  return _showShelfFolderNameSheet(
    context: context,
    title: '新建文件夹',
    subtitle: '输入文件夹名称',
    hintText: '例如：待整理',
    confirmLabel: '新建',
    icon: Icons.create_new_folder_outlined,
  );
}

Future<String?> showShelfRenameFolderSheet({
  required BuildContext context,
  required String initialName,
}) {
  return _showShelfFolderNameSheet(
    context: context,
    title: '重命名文件夹',
    subtitle: '输入新的文件夹名称',
    hintText: '例如：待整理',
    confirmLabel: '确认',
    icon: Icons.drive_file_rename_outline,
    initialValue: initialName,
  );
}
