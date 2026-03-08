import 'package:flutter/material.dart';
import 'package:novella/data/models/book.dart';

/// A badge widget that displays book type (录入/翻译/转载) as an icon
/// 位于右下角，样式类似排名角标
class BookTypeBadge extends StatelessWidget {
  final BookCategory? category;
  final bool visible;
  final bool reserveSpaceWhenHidden;
  final Duration duration;

  const BookTypeBadge({
    super.key,
    this.category,
    this.visible = true,
    this.reserveSpaceWhenHidden = false,
    this.duration = const Duration(milliseconds: 180),
  });

  @override
  Widget build(BuildContext context) {
    final icon =
        category == null || category!.shortName.isEmpty
            ? null
            : _getIcon(category!.shortName);
    final color =
        category == null || category!.color.isEmpty
            ? null
            : _parseColor(category!.color);
    final hasBadge = icon != null;

    if (!reserveSpaceWhenHidden && !hasBadge) {
      return const SizedBox.shrink();
    }

    return Positioned(
      right: 4,
      bottom: 4,
      child: IgnorePointer(
        ignoring: !visible || !hasBadge,
        child: AnimatedOpacity(
          opacity: visible && hasBadge ? 1 : 0,
          duration: duration,
          curve: Curves.easeOutCubic,
          child: AnimatedScale(
            scale: visible && hasBadge ? 1 : 0.92,
            duration: duration,
            curve: Curves.easeOutCubic,
            child:
                hasBadge
                    ? Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: color ?? Colors.grey.shade700,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, size: 14, color: Colors.white),
                    )
                    : const SizedBox(width: 22, height: 22),
          ),
        ),
      ),
    );
  }

  IconData? _getIcon(String shortName) {
    switch (shortName) {
      case '录入':
        return Icons.edit_note;
      case '翻译':
        return Icons.translate;
      case '转载':
        return Icons.reply;
      default:
        return null;
    }
  }

  Color? _parseColor(String colorStr) {
    if (colorStr.isEmpty) return null;
    try {
      // 处理十六进制颜色，如 "#FF5733" 或 "FF5733"
      String hex = colorStr.replaceFirst('#', '');
      if (hex.length == 6) {
        hex = 'FF$hex'; // Add alpha
      }
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return null;
    }
  }
}
