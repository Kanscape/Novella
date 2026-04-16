import 'dart:math' as math;

import 'package:flutter/material.dart';

enum AppWindowClass {
  compact,
  medium,
  expanded;

  bool get usesRail => this != AppWindowClass.compact;

  bool get supportsSecondaryPane => this == AppWindowClass.expanded;

  static AppWindowClass fromWidth(double width) {
    if (width >= 840) {
      return AppWindowClass.expanded;
    }
    if (width >= 600) {
      return AppWindowClass.medium;
    }
    return AppWindowClass.compact;
  }

  static AppWindowClass of(BuildContext context) {
    return fromWidth(MediaQuery.sizeOf(context).width);
  }
}

extension AppWindowClassContext on BuildContext {
  AppWindowClass get appWindowClass => AppWindowClass.of(this);
}

SliverGridDelegate appBookGridDelegateForWidth(
  double availableWidth, {
  double childAspectRatio = 0.58,
  double crossAxisSpacing = 10,
  double mainAxisSpacing = 12,
  double minTileWidth = 140,
  int minColumns = 3,
}) {
  final width =
      availableWidth.isFinite ? availableWidth : minTileWidth * minColumns;
  final columns = math.max(minColumns, (width / minTileWidth).floor());

  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: columns,
    childAspectRatio: childAspectRatio,
    crossAxisSpacing: crossAxisSpacing,
    mainAxisSpacing: mainAxisSpacing,
  );
}

double appBottomContentPadding(
  BuildContext context, {
  required bool useIOS26Style,
  double compactPadding = 24,
  double largePadding = 24,
}) {
  final bottomInset = MediaQuery.paddingOf(context).bottom;
  final windowClass = AppWindowClass.of(context);

  if (windowClass == AppWindowClass.compact && useIOS26Style) {
    return math.max(bottomInset, 86);
  }

  if (windowClass == AppWindowClass.compact) {
    return math.max(bottomInset, compactPadding);
  }

  return math.max(bottomInset, largePadding);
}

double appCenteredContentHorizontalPadding(
  BuildContext context, {
  double maxContentWidth = 640,
  double minPadding = 20,
}) {
  final width = MediaQuery.sizeOf(context).width;
  return appCenteredContentHorizontalPaddingForWidth(
    width,
    maxContentWidth: maxContentWidth,
    minPadding: minPadding,
  );
}

double appCenteredContentHorizontalPaddingForWidth(
  double availableWidth, {
  double maxContentWidth = 640,
  double minPadding = 20,
}) {
  final width =
      availableWidth.isFinite
          ? availableWidth
          : maxContentWidth + minPadding * 2;
  if (width <= maxContentWidth + minPadding * 2) {
    return minPadding;
  }
  return (width - maxContentWidth) / 2;
}
