import 'package:flutter/material.dart';
import 'package:novella/data/models/book.dart';

@immutable
class BookTypeBadgeDefinition {
  final String label;
  final String meaning;
  final IconData icon;
  final Color backgroundColor;
  final Set<String> names;
  final Set<String> shortNames;

  const BookTypeBadgeDefinition({
    required this.label,
    required this.meaning,
    required this.icon,
    required this.backgroundColor,
    required this.names,
    required this.shortNames,
  });

  bool matches(BookCategory category) {
    final name = category.name.trim();
    final shortName = category.shortName.trim();
    return names.contains(name) || shortNames.contains(shortName);
  }
}

const _recordedColor = Color(0xFFEC1282);
const _translatedColor = Color(0xFF1976D2);
const _repostColor = Color(0xFFF1570E);
const _originalColor = Color(0xFF7B1FA2);
const _japaneseColor = Color(0xFFC62828);
const _aiColor = Color(0xFF2EAF5D);
const _inProgressColor = Color(0xFF9E9E9E);
const _level6Color = Color(0xFFE0A106);

const List<BookTypeBadgeDefinition> bookTypeBadgeDefinitions = [
  BookTypeBadgeDefinition(
    label: '录入',
    meaning: '人工录入已完成',
    icon: Icons.edit_note,
    backgroundColor: _recordedColor,
    names: {'录入完成'},
    shortNames: {'录入', '录入完成'},
  ),
  BookTypeBadgeDefinition(
    label: '翻译',
    meaning: '人工翻译已完成',
    icon: Icons.translate,
    backgroundColor: _translatedColor,
    names: {'翻译完成'},
    shortNames: {'翻译', '翻译完成'},
  ),
  BookTypeBadgeDefinition(
    label: '转载',
    meaning: '转载作品',
    icon: Icons.reply,
    backgroundColor: _repostColor,
    names: {'转载'},
    shortNames: {'转载'},
  ),
  BookTypeBadgeDefinition(
    label: '原创',
    meaning: '原创作品',
    icon: Icons.history_edu,
    backgroundColor: _originalColor,
    names: {'原创'},
    shortNames: {'原创'},
  ),
  BookTypeBadgeDefinition(
    label: '日文',
    meaning: '日文原版内容',
    icon: Icons.menu_book,
    backgroundColor: _japaneseColor,
    names: {'日文原版'},
    shortNames: {'日文', '日原', '日文原版'},
  ),
  BookTypeBadgeDefinition(
    label: 'AI',
    meaning: '机器参与生成或翻译',
    icon: Icons.smart_toy,
    backgroundColor: _aiColor,
    names: {'AI翻译'},
    shortNames: {'AI', 'AI翻译'},
  ),
  BookTypeBadgeDefinition(
    label: '录入中',
    meaning: '仍在录入中',
    icon: Icons.edit_note,
    backgroundColor: _inProgressColor,
    names: {'录入中'},
    shortNames: {'录入中'},
  ),
  BookTypeBadgeDefinition(
    label: '翻译中',
    meaning: '仍在翻译中',
    icon: Icons.translate,
    backgroundColor: _inProgressColor,
    names: {'翻译中'},
    shortNames: {'翻译中'},
  ),
];

const BookTypeBadgeDefinition level6BookBadgeDefinition =
    BookTypeBadgeDefinition(
      label: 'Level6',
      meaning: '权限内容',
      icon: Icons.token,
      backgroundColor: _level6Color,
      names: {},
      shortNames: {},
    );

const List<BookTypeBadgeDefinition> bookBadgeLegendDefinitions = [
  ...bookTypeBadgeDefinitions,
  level6BookBadgeDefinition,
];

BookTypeBadgeDefinition? resolveBookTypeBadgeDefinition(BookCategory category) {
  for (final definition in bookTypeBadgeDefinitions) {
    if (definition.matches(category)) {
      return definition;
    }
  }
  return null;
}

class BookTypeBadgeIcon extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final double iconSize;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const BookTypeBadgeIcon({
    super.key,
    required this.icon,
    required this.backgroundColor,
    this.iconSize = 14,
    this.padding = const EdgeInsets.all(4),
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(icon, size: iconSize, color: Colors.white),
    );
  }
}

class _AnimatedBookCornerBadge extends StatelessWidget {
  final bool visible;
  final Duration duration;
  final Widget child;

  const _AnimatedBookCornerBadge({
    required this.visible,
    required this.duration,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: duration,
      curve: Curves.easeOutCubic,
      child: AnimatedScale(
        scale: visible ? 1 : 0.92,
        duration: duration,
        curve: Curves.easeOutCubic,
        child: child,
      ),
    );
  }
}

/// Displays the book type badge at the bottom-right and the Level6 badge at
/// the top-right of the cover.
class BookTypeBadge extends StatelessWidget {
  final BookCategory? category;
  final int? level;
  final bool visible;
  final bool reserveSpaceWhenHidden;
  final Duration duration;

  const BookTypeBadge({
    super.key,
    this.category,
    this.level,
    this.visible = true,
    this.reserveSpaceWhenHidden = false,
    this.duration = const Duration(milliseconds: 180),
  });

  @override
  Widget build(BuildContext context) {
    final typeDefinition =
        category == null ? null : resolveBookTypeBadgeDefinition(category!);
    final hasTypeBadge = typeDefinition != null;
    final hasLevel6Badge = level == 6;
    final hasAnyBadge = hasTypeBadge || hasLevel6Badge;

    if (!reserveSpaceWhenHidden && !hasAnyBadge) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !visible || !hasAnyBadge,
        child: Stack(
          children: [
            if (hasLevel6Badge || reserveSpaceWhenHidden)
              Positioned(
                right: 4,
                top: 4,
                child: _AnimatedBookCornerBadge(
                  visible: visible && hasLevel6Badge,
                  duration: duration,
                  child:
                      hasLevel6Badge
                          ? BookTypeBadgeIcon(
                            icon: level6BookBadgeDefinition.icon,
                            backgroundColor:
                                level6BookBadgeDefinition.backgroundColor,
                          )
                          : const SizedBox(width: 22, height: 22),
                ),
              ),
            if (hasTypeBadge || reserveSpaceWhenHidden)
              Positioned(
                right: 4,
                bottom: 4,
                child: _AnimatedBookCornerBadge(
                  visible: visible && hasTypeBadge,
                  duration: duration,
                  child:
                      hasTypeBadge
                          ? BookTypeBadgeIcon(
                            icon: typeDefinition.icon,
                            backgroundColor: typeDefinition.backgroundColor,
                          )
                          : const SizedBox(width: 22, height: 22),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
