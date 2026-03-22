import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../platform/platform_info.dart';
import 'adaptive_action_group_item.dart';
import 'adaptive_blur_view.dart';
import 'adaptive_button.dart';
import 'adaptive_glass_group.dart';
import 'ios26/ios26_action_group.dart';

/// A grouped set of actions with platform-specific styling.
///
/// - iOS 26+: single native platform view
/// - iOS <26: Cupertino-style glass group
/// - Android/Windows: Material-style grouped surface
class AdaptiveActionGroup extends StatelessWidget {
  const AdaptiveActionGroup({
    super.key,
    required this.items,
    this.foregroundColor,
    this.blurStyle = BlurStyle.systemUltraThinMaterial,
    this.height = 48,
    this.buttonHeight = 36,
    this.iconButtonWidth = 40,
    this.textButtonWidth = 68,
    this.iconSize = 18,
    this.itemSpacing = 0,
    this.showDividers = true,
    this.horizontalPadding = 6,
    this.loadingBuilder,
  });

  final List<AdaptiveActionGroupItem> items;
  final Color? foregroundColor;
  final BlurStyle blurStyle;
  final double height;
  final double buttonHeight;
  final double iconButtonWidth;
  final double textButtonWidth;
  final double iconSize;
  final double itemSpacing;
  final bool showDividers;
  final double horizontalPadding;
  final WidgetBuilder? loadingBuilder;

  @override
  Widget build(BuildContext context) {
    if (PlatformInfo.isIOS26OrHigher()) {
      return IOS26ActionGroup(
        key: ValueKey(items.map((item) => item.hashCode).join('|')),
        items: items,
        foregroundColor: foregroundColor,
        height: height,
        buttonHeight: buttonHeight,
        iconButtonWidth: iconButtonWidth,
        textButtonWidth: textButtonWidth,
        iconSize: iconSize,
        itemSpacing: itemSpacing,
        showDividers: showDividers,
        horizontalPadding: horizontalPadding,
      );
    }

    if (PlatformInfo.isIOS) {
      return SizedBox(
        height: height,
        child: AdaptiveGlassGroup(
          blurStyle: blurStyle,
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: (height - buttonHeight) / 2,
          ),
          children: _buildButtons(context),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.92,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.25),
            width: 0.5,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: (height - buttonHeight) / 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: _buildButtons(context),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildButtons(BuildContext context) {
    final result = <Widget>[];
    for (var index = 0; index < items.length; index++) {
      result.add(_buildButton(context, items[index]));
      if (index == items.length - 1) {
        continue;
      }

      result.add(_buildSeparator(context));
    }
    return result;
  }

  Widget _buildSeparator(BuildContext context) {
    if (!showDividers) {
      return SizedBox(width: itemSpacing);
    }

    final color =
        foregroundColor?.withValues(alpha: 0.2) ??
        (Theme.brightnessOf(context) == Brightness.dark
            ? Colors.white.withValues(alpha: 0.18)
            : CupertinoColors.systemGrey3.withValues(alpha: 0.45));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        width: 0.5,
        height: 22,
        color: color,
      ),
    );
  }

  Widget _buildButton(BuildContext context, AdaptiveActionGroupItem item) {
    final color =
        foregroundColor ??
        (PlatformInfo.isIOS
            ? CupertinoTheme.of(context).primaryColor
            : Theme.of(context).colorScheme.onSurface);
    final enabled = item.enabled && item.onPressed != null && !item.loading;
    final buttonWidth = _buttonWidth(item);

    if (item.loading) {
      return AdaptiveButton.child(
        onPressed: null,
        enabled: false,
        style: AdaptiveButtonStyle.plain,
        padding: EdgeInsets.zero,
        color: color,
        size: AdaptiveButtonSize.medium,
        child: SizedBox(
          width: buttonWidth,
          height: buttonHeight,
          child: Center(
            child:
                loadingBuilder?.call(context) ??
                (PlatformInfo.isIOS
                    ? CupertinoActivityIndicator(color: color)
                    : CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    )),
          ),
        ),
      );
    }

    return AdaptiveButton.child(
      onPressed: enabled ? item.onPressed : null,
      enabled: enabled,
      style: AdaptiveButtonStyle.plain,
      padding: EdgeInsets.zero,
      color: color,
      size: AdaptiveButtonSize.medium,
      child: SizedBox(
        width: buttonWidth,
        height: buttonHeight,
        child: Center(
          child: _buildButtonContent(item, color),
        ),
      ),
    );
  }

  Widget _buildButtonContent(AdaptiveActionGroupItem item, Color color) {
    if (item.icon != null) {
      return Icon(item.icon, size: iconSize, color: color);
    }

    if (PlatformInfo.isIOS && item.iosSymbol != null) {
      return Icon(CupertinoIcons.circle, size: iconSize, color: color);
    }

    return Text(
      item.title ?? '',
      maxLines: 1,
      overflow: TextOverflow.fade,
      softWrap: false,
      style: TextStyle(
        color: color,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  double _buttonWidth(AdaptiveActionGroupItem item) {
    if ((item.title?.isNotEmpty ?? false) && item.icon == null) {
      return textButtonWidth;
    }
    return iconButtonWidth;
  }
}
