import 'package:flutter/material.dart';
import 'package:novella/data/models/book.dart';

@immutable
class BookTypeBadgeDefinition {
  final String label;
  final String meaning;
  final IconData icon;
  final IconData? trailingIcon;
  final Color backgroundColor;
  final Color iconColor;
  final Color? borderColor;
  final int? previewLevel;
  final Set<String> names;
  final Set<String> shortNames;

  const BookTypeBadgeDefinition({
    required this.label,
    required this.meaning,
    required this.icon,
    this.trailingIcon,
    required this.backgroundColor,
    this.iconColor = Colors.white,
    this.borderColor,
    this.previewLevel,
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
      label: 'Level',
      meaning: '权限内容\n图标会按实际 Level 显示',
      icon: Icons.token,
      backgroundColor: _level6Color,
      previewLevel: 6,
      names: {},
      shortNames: {},
    );

const BookTypeBadgeDefinition interiorLevelBookBadgeDefinition =
    BookTypeBadgeDefinition(
      label: 'InteriorLevel',
      meaning: '组内权限内容\n图标会按实际 InteriorLevel 显示',
      icon: Icons.token,
      backgroundColor: Colors.white,
      iconColor: _level6Color,
      borderColor: _level6Color,
      previewLevel: 6,
      names: {},
      shortNames: {},
    );

const List<BookTypeBadgeDefinition> bookBadgeLegendDefinitions = [
  ...bookTypeBadgeDefinitions,
  level6BookBadgeDefinition,
  interiorLevelBookBadgeDefinition,
];

BookTypeBadgeDefinition? resolveBookTypeBadgeDefinition(BookCategory category) {
  for (final definition in bookTypeBadgeDefinitions) {
    if (definition.matches(category)) {
      return definition;
    }
  }
  return null;
}

BookTypeBadgeDefinition? resolveBookLevelBadgeDefinition({
  int? level,
  int? interiorLevel,
}) {
  final effectiveInteriorLevel = interiorLevel ?? 0;
  final effectiveLevel = level ?? 0;
  if (effectiveInteriorLevel > 0) {
    return BookTypeBadgeDefinition(
      label: interiorLevelBookBadgeDefinition.label,
      meaning: interiorLevelBookBadgeDefinition.meaning,
      icon: interiorLevelBookBadgeDefinition.icon,
      trailingIcon: interiorLevelBookBadgeDefinition.trailingIcon,
      backgroundColor: interiorLevelBookBadgeDefinition.backgroundColor,
      iconColor: interiorLevelBookBadgeDefinition.iconColor,
      borderColor: interiorLevelBookBadgeDefinition.borderColor,
      previewLevel: effectiveInteriorLevel.clamp(1, 6),
      names: const <String>{},
      shortNames: const <String>{},
    );
  }
  if (effectiveLevel > 0) {
    return BookTypeBadgeDefinition(
      label: level6BookBadgeDefinition.label,
      meaning: level6BookBadgeDefinition.meaning,
      icon: level6BookBadgeDefinition.icon,
      trailingIcon: level6BookBadgeDefinition.trailingIcon,
      backgroundColor: level6BookBadgeDefinition.backgroundColor,
      iconColor: level6BookBadgeDefinition.iconColor,
      borderColor: level6BookBadgeDefinition.borderColor,
      previewLevel: effectiveLevel.clamp(1, 6),
      names: const <String>{},
      shortNames: const <String>{},
    );
  }
  return null;
}

IconData _resolveLevelIcon(int level) {
  switch (level.clamp(1, 6)) {
    case 1:
      return Icons.filter_1;
    case 2:
      return Icons.filter_2;
    case 3:
      return Icons.filter_3;
    case 4:
      return Icons.filter_4;
    case 5:
      return Icons.filter_5;
    case 6:
    default:
      return Icons.filter_6;
  }
}

class BookTypeBadgeIcon extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final Color? borderColor;
  final double iconSize;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const BookTypeBadgeIcon({
    super.key,
    required this.icon,
    required this.backgroundColor,
    this.iconColor = Colors.white,
    this.borderColor,
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
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: Icon(icon, size: iconSize, color: iconColor),
    );
  }
}

class BookLevelBadgeIcon extends StatelessWidget {
  final IconData icon;
  final IconData trailingIcon;
  final Color backgroundColor;
  final Color iconColor;
  final Color? borderColor;
  final double iconSize;
  final double levelIconSize;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double spacing;

  const BookLevelBadgeIcon({
    super.key,
    required this.icon,
    required this.trailingIcon,
    required this.backgroundColor,
    this.iconColor = Colors.white,
    this.borderColor,
    this.iconSize = 14,
    this.levelIconSize = 16,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    this.borderRadius = 8,
    this.spacing = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: iconColor),
          SizedBox(width: spacing),
          Icon(trailingIcon, size: levelIconSize, color: iconColor),
        ],
      ),
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

/// Displays the book type badge at the bottom-right and the book level badge
/// at the top-right of the cover. InteriorLevel takes precedence over the
/// public Level badge.
class BookTypeBadge extends StatelessWidget {
  final BookCategory? category;
  final int? level;
  final int? interiorLevel;
  final bool visible;
  final bool reserveSpaceWhenHidden;
  final Duration duration;

  const BookTypeBadge({
    super.key,
    this.category,
    this.level,
    this.interiorLevel,
    this.visible = true,
    this.reserveSpaceWhenHidden = false,
    this.duration = const Duration(milliseconds: 180),
  });

  @override
  Widget build(BuildContext context) {
    final typeDefinition =
        category == null ? null : resolveBookTypeBadgeDefinition(category!);
    final levelDefinition = resolveBookLevelBadgeDefinition(
      level: level,
      interiorLevel: interiorLevel,
    );
    final hasTypeBadge = typeDefinition != null;
    final hasLevelBadge = levelDefinition != null;
    final hasAnyBadge = hasTypeBadge || hasLevelBadge;

    if (!reserveSpaceWhenHidden && !hasAnyBadge) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !visible || !hasAnyBadge,
        child: Stack(
          children: [
            if (hasLevelBadge || reserveSpaceWhenHidden)
              Positioned(
                right: 4,
                top: 4,
                child: _AnimatedBookCornerBadge(
                  visible: visible && hasLevelBadge,
                  duration: duration,
                  child:
                      hasLevelBadge
                          ? BookLevelBadgeIcon(
                            icon: levelDefinition.icon,
                            trailingIcon:
                                levelDefinition.trailingIcon ??
                                _resolveLevelIcon(
                                  levelDefinition.previewLevel ?? 6,
                                ),
                            backgroundColor: levelDefinition.backgroundColor,
                            iconColor: levelDefinition.iconColor,
                            borderColor: levelDefinition.borderColor,
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
                            iconColor: typeDefinition.iconColor,
                            borderColor: typeDefinition.borderColor,
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
