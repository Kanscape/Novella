import 'package:flutter/material.dart';
import 'package:material_loading_indicator/loading_indicator.dart';

const _packageContainerSize = 48.0;
const _packageActiveIndicatorSize = 38.0;
const _packageActiveIndicatorScale =
    _packageActiveIndicatorSize / _packageContainerSize;

/// App-wide Material 3 loading indicator.
///
/// Kept as a compatibility wrapper so existing loading states can switch to
/// `material_loading_indicator` without changing all call sites.
class M3ELoadingIndicator extends StatelessWidget {
  const M3ELoadingIndicator({
    super.key,
    this.size,
    this.color,
    this.containerColor,
    this.semanticsLabel,
  }) : contained = false;

  const M3ELoadingIndicator.contained({
    super.key,
    this.size,
    this.color,
    this.containerColor,
    this.semanticsLabel,
  }) : contained = true;

  /// Component box size. Defaults to the Material 3 48dp container.
  final double? size;

  /// Active indicator color.
  ///
  /// Defaults to `colorScheme.primary`, or `colorScheme.onPrimaryContainer`
  /// for the contained variant.
  final Color? color;

  /// Container color for the contained variant.
  final Color? containerColor;

  /// Accessibility label.
  final String? semanticsLabel;

  /// Whether to render the Material 3 contained variant.
  final bool contained;

  @override
  Widget build(BuildContext context) {
    final dimension = size ?? _packageContainerSize;
    final packageDimension = dimension / _packageActiveIndicatorScale;
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor =
        color ??
        (contained ? colorScheme.onPrimaryContainer : colorScheme.primary);

    final indicator = contained
        ? LoadingIndicator.contained(
            activeIndicatorColor: activeColor,
            containerColor: containerColor ?? colorScheme.primaryContainer,
            semanticsLabel: semanticsLabel ?? 'Loading',
          )
        : LoadingIndicator(
            activeIndicatorColor: activeColor,
            semanticsLabel: semanticsLabel ?? 'Loading',
          );

    return SizedBox.square(
      dimension: dimension,
      child: OverflowBox(
        minWidth: packageDimension,
        maxWidth: packageDimension,
        minHeight: packageDimension,
        maxHeight: packageDimension,
        child: SizedBox.square(dimension: packageDimension, child: indicator),
      ),
    );
  }
}
