import 'package:flutter/material.dart';

const bookDetailRouteSettleFallbackDelay = Duration(milliseconds: 360);

bool shouldDeferBookDetailContentApply({
  required bool forceRefresh,
  required bool usedCache,
  required bool routeTransitionActive,
}) {
  return routeTransitionActive && !usedCache && !forceRefresh;
}

bool isRouteTransitionActive(Animation<double>? animation) {
  return animation?.status == AnimationStatus.forward ||
      animation?.status == AnimationStatus.reverse;
}
