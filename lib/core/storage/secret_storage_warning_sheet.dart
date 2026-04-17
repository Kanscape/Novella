import 'package:flutter/material.dart';
import 'package:novella/core/storage/secret_storage_service.dart';

Future<bool> ensureSecretStorageReady(
  BuildContext context, {
  bool alwaysPromptOnFallback = true,
}) async {
  final secretStorage = SecretStorageService();
  if (await secretStorage.isSecureStorageAvailable(forceRefresh: true)) {
    return true;
  }

  if (!alwaysPromptOnFallback && await secretStorage.isFallbackApproved()) {
    return true;
  }

  if (!context.mounted) {
    return false;
  }

  final confirmed =
      await showModalBottomSheet<bool>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheetContext) {
          final colorScheme = Theme.of(sheetContext).colorScheme;
          final textTheme = Theme.of(sheetContext).textTheme;

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
                    '无法写入 SecureStorage',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    '由于设备环境原因，无法安全写入，是否继续？',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetContext, false),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(sheetContext, true),
                          child: const Text('继续'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ) ??
      false;

  if (!confirmed) {
    return false;
  }

  await secretStorage.approveFallback();
  return true;
}
