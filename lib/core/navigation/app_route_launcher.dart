import 'package:flutter/material.dart';

import 'package:novella/core/layout/app_window_class.dart';

typedef AppPageBuilder = Widget Function(BuildContext context);

class AppPaneCoordinator {
  AppPaneCoordinator({required int tabCount})
    : _navigatorKeys = List<GlobalKey<NavigatorState>>.generate(
        tabCount,
        (_) => GlobalKey<NavigatorState>(),
      );

  final List<GlobalKey<NavigatorState>> _navigatorKeys;

  GlobalKey<NavigatorState> navigatorKeyFor(int tabIndex) {
    return _navigatorKeys[tabIndex];
  }

  NavigatorState? navigatorStateFor(int tabIndex) {
    return navigatorKeyFor(tabIndex).currentState;
  }

  bool canPop(int tabIndex) {
    return navigatorStateFor(tabIndex)?.canPop() ?? false;
  }

  void pop<T extends Object?>(int tabIndex, [T? result]) {
    final navigatorState = navigatorStateFor(tabIndex);
    if (navigatorState == null || !navigatorState.canPop()) {
      return;
    }
    navigatorState.pop<T>(result);
  }

  Future<T?> push<T>(
    int tabIndex,
    Route<T> route,
    BuildContext fallbackContext,
  ) {
    final navigatorState = navigatorStateFor(tabIndex);
    if (navigatorState == null) {
      return Navigator.of(fallbackContext).push<T>(route);
    }
    return navigatorState.push<T>(route);
  }

  Future<T?> pushReplacement<T extends Object?, TO extends Object?>(
    int tabIndex,
    Route<T> newRoute,
    BuildContext fallbackContext, {
    TO? result,
  }) {
    final navigatorState = navigatorStateFor(tabIndex);
    if (navigatorState == null) {
      return Navigator.of(
        fallbackContext,
      ).pushReplacement<T, TO>(newRoute, result: result);
    }
    return navigatorState.pushReplacement<T, TO>(newRoute, result: result);
  }
}

class AppWindowScope extends InheritedWidget {
  const AppWindowScope({
    super.key,
    required this.windowClass,
    required this.paneCoordinator,
    required super.child,
  });

  final AppWindowClass windowClass;
  final AppPaneCoordinator paneCoordinator;

  bool get isSecondaryPaneEnabled => windowClass.supportsSecondaryPane;

  static AppWindowScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppWindowScope>();
  }

  @override
  bool updateShouldNotify(AppWindowScope oldWidget) {
    return windowClass != oldWidget.windowClass ||
        paneCoordinator != oldWidget.paneCoordinator;
  }
}

class AppPaneTabScope extends InheritedWidget {
  const AppPaneTabScope({
    super.key,
    required this.tabIndex,
    required super.child,
  });

  final int tabIndex;

  static AppPaneTabScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppPaneTabScope>();
  }

  @override
  bool updateShouldNotify(AppPaneTabScope oldWidget) {
    return tabIndex != oldWidget.tabIndex;
  }
}

class AppRouteLauncher {
  const AppRouteLauncher._();

  static bool isExpandedWindow(BuildContext context) {
    final windowScope = AppWindowScope.maybeOf(context);
    return (windowScope?.windowClass ?? AppWindowClass.of(context)) ==
        AppWindowClass.expanded;
  }

  static Future<T?> pushDetail<T>(
    BuildContext context,
    AppPageBuilder builder, {
    RouteSettings? settings,
    bool maintainState = true,
    bool fullscreenDialog = false,
  }) {
    final route = MaterialPageRoute<T>(
      builder: builder,
      settings: settings,
      maintainState: maintainState,
      fullscreenDialog: fullscreenDialog,
    );

    final windowScope = AppWindowScope.maybeOf(context);
    final tabScope = AppPaneTabScope.maybeOf(context);

    if (windowScope != null &&
        tabScope != null &&
        windowScope.isSecondaryPaneEnabled) {
      return windowScope.paneCoordinator.push<T>(
        tabScope.tabIndex,
        route,
        context,
      );
    }

    return Navigator.of(context).push<T>(route);
  }

  static Future<T?>
  pushReplacementDetail<T extends Object?, TO extends Object?>(
    BuildContext context,
    AppPageBuilder builder, {
    RouteSettings? settings,
    TO? result,
    bool maintainState = true,
    bool fullscreenDialog = false,
  }) {
    final route = MaterialPageRoute<T>(
      builder: builder,
      settings: settings,
      maintainState: maintainState,
      fullscreenDialog: fullscreenDialog,
    );

    final windowScope = AppWindowScope.maybeOf(context);
    final tabScope = AppPaneTabScope.maybeOf(context);

    if (windowScope != null &&
        tabScope != null &&
        windowScope.isSecondaryPaneEnabled) {
      return windowScope.paneCoordinator.pushReplacement<T, TO>(
        tabScope.tabIndex,
        route,
        context,
        result: result,
      );
    }

    return Navigator.of(context).pushReplacement<T, TO>(route, result: result);
  }

  static Future<T?> pushTopLevel<T>(
    BuildContext context,
    AppPageBuilder builder, {
    RouteSettings? settings,
    bool maintainState = true,
    bool fullscreenDialog = false,
    bool onlyWhenExpanded = true,
  }) {
    final route = MaterialPageRoute<T>(
      builder: builder,
      settings: settings,
      maintainState: maintainState,
      fullscreenDialog: fullscreenDialog,
    );

    final useRootNavigator =
        !onlyWhenExpanded || AppRouteLauncher.isExpandedWindow(context);
    return Navigator.of(
      context,
      rootNavigator: useRootNavigator,
    ).push<T>(route);
  }
}

class AppSecondaryPaneNavigator extends StatelessWidget {
  const AppSecondaryPaneNavigator({
    super.key,
    required this.coordinator,
    required this.tabIndex,
    required this.title,
    required this.subtitle,
    this.onStackChanged,
  });

  final AppPaneCoordinator coordinator;
  final int tabIndex;
  final String title;
  final String subtitle;
  final VoidCallback? onStackChanged;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: coordinator.navigatorKeyFor(tabIndex),
      observers: <NavigatorObserver>[_PaneNavigatorObserver(onStackChanged)],
      onGenerateInitialRoutes:
          (_, __) => <Route<dynamic>>[
            MaterialPageRoute<void>(
              builder:
                  (_) => _SecondaryPanePlaceholder(
                    title: title,
                    subtitle: subtitle,
                  ),
              settings: RouteSettings(name: 'secondary-pane-root-$tabIndex'),
            ),
          ],
    );
  }
}

class _PaneNavigatorObserver extends NavigatorObserver {
  _PaneNavigatorObserver(this.onStackChanged);

  final VoidCallback? onStackChanged;

  void _notify() {
    if (onStackChanged == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onStackChanged?.call();
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _notify();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _notify();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _notify();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _notify();
  }
}

class _SecondaryPanePlaceholder extends StatelessWidget {
  const _SecondaryPanePlaceholder({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ColoredBox(
      color: colorScheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.splitscreen_outlined,
                  size: 42,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
