import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novella/core/layout/app_window_class.dart';
import 'package:novella/core/network/request_queue.dart';
import 'package:novella/core/network/signalr_service.dart';
import 'package:novella/core/navigation/app_route_launcher.dart';
import 'package:novella/core/services/update_service.dart';
import 'package:novella/core/widgets/m3e_loading_indicator.dart';
import 'package:novella/features/community/community_page.dart';
import 'package:novella/features/community/notification_unread_provider.dart';
import 'package:novella/features/history/history_page.dart';
import 'package:novella/features/home/home_page.dart';
import 'package:novella/features/settings/settings_page.dart';
import 'package:novella/features/shelf/shelf_page.dart';

class MainPage extends ConsumerStatefulWidget {
  const MainPage({super.key});

  @override
  ConsumerState<MainPage> createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage> {
  static const List<String> _tabLabels = <String>['发现', '书架', '历史', '社区', '设置'];
  static const double _railMinWidth = 76;
  static const double _railExtendedWidth = 176;

  int _currentIndex = 0;
  final _homeKey = GlobalKey<HomePageState>();
  final _shelfKey = GlobalKey<ShelfPageState>();
  final _historyKey = GlobalKey<HistoryPageState>();
  final _communityKey = GlobalKey<CommunityPageState>();
  final _signalRService = SignalRService();
  final _paneCoordinator = AppPaneCoordinator(tabCount: _tabLabels.length);
  final Set<int> _loadedPages = <int>{0};
  bool _startupApplied = false;

  String? _scopeForTab(int index) {
    switch (index) {
      case 0:
        return RequestScopes.home;
      case 1:
        return RequestScopes.shelf;
      case 2:
        return RequestScopes.history;
      case 3:
        return RequestScopes.community;
      default:
        return null;
    }
  }

  void _updateTabActivity(int activeIndex) {
    _homeKey.currentState?.setTabActive(activeIndex == 0);
    _shelfKey.currentState?.setTabActive(activeIndex == 1);
    _historyKey.currentState?.setTabActive(activeIndex == 2);
    _communityKey.currentState?.setTabActive(activeIndex == 3);
  }

  void _cancelInactiveTabRequests(int activeIndex) {
    for (var index = 0; index < 5; index++) {
      if (index == activeIndex) {
        continue;
      }

      final scope = _scopeForTab(index);
      if (scope != null) {
        _signalRService.cancelPendingRequests(scope);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        UpdateService.checkUpdate(context, ref, manual: false);
      }
    });
  }

  Widget _buildPage(int index) {
    if (!_loadedPages.contains(index)) {
      return const SizedBox.shrink();
    }

    switch (index) {
      case 0:
        return HomePage(key: _homeKey);
      case 1:
        return ShelfPage(key: _shelfKey);
      case 2:
        return HistoryPage(key: _historyKey);
      case 3:
        return CommunityPage(key: _communityKey);
      case 4:
        return const SettingsPage();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildScopedPage(int index) {
    return AppPaneTabScope(tabIndex: index, child: _buildPage(index));
  }

  void _handleTabChanged(int index) {
    if (_currentIndex == index) {
      if (index == 1) {
        _shelfKey.currentState?.refresh();
      } else if (index == 2) {
        _historyKey.currentState?.refresh();
      } else if (index == 3) {
        _communityKey.currentState?.refresh();
      }
      return;
    }

    setState(() {
      _currentIndex = index;
      _loadedPages.add(index);
    });

    _updateTabActivity(index);
    _cancelInactiveTabRequests(index);

    if (index == 1) {
      _shelfKey.currentState?.refresh();
    } else if (index == 2) {
      _historyKey.currentState?.refresh();
    } else if (index == 3) {
      _communityKey.currentState?.refresh();
    }
  }

  void _applyStartupSettingsIfNeeded(AppSettings settings) {
    if (_startupApplied || !settings.isLoaded) {
      return;
    }

    _startupApplied = true;
    _currentIndex = settings.startupTabIndex;
    _loadedPages
      ..clear()
      ..add(_currentIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _updateTabActivity(_currentIndex);
      _cancelInactiveTabRequests(_currentIndex);

      if (_currentIndex == 2) {
        _historyKey.currentState?.refresh();
      } else if (_currentIndex == 3) {
        _communityKey.currentState?.refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    if (!settings.isLoaded) {
      return const Scaffold(body: Center(child: M3ELoadingIndicator()));
    }

    _applyStartupSettingsIfNeeded(settings);
    final unreadNotificationCount =
        ref.watch(notificationUnreadCountProvider).asData?.value ?? 0;
    final windowClass = context.appWindowClass;

    return AppWindowScope(
      windowClass: windowClass,
      paneCoordinator: _paneCoordinator,
      child:
          windowClass == AppWindowClass.compact
              ? _buildCompactScaffold(settings, unreadNotificationCount)
              : _buildLargeScreenScaffold(windowClass, unreadNotificationCount),
    );
  }

  Widget _buildCompactScaffold(
    AppSettings settings,
    int unreadNotificationCount,
  ) {
    return AdaptiveScaffold(
      minimizeBehavior: TabBarMinimizeBehavior.never,
      body: IndexedStack(
        index: _currentIndex,
        children: List<Widget>.generate(_tabLabels.length, _buildScopedPage),
      ),
      bottomNavigationBar: AdaptiveBottomNavigationBar(
        selectedIndex: _currentIndex,
        onTap: _handleTabChanged,
        items: [
          AdaptiveNavigationDestination(
            icon:
                settings.useIOS26Style
                    ? 'safari.fill'
                    : PlatformInfo.isIOS
                    ? CupertinoIcons.compass
                    : Icons.explore_outlined,
            selectedIcon:
                PlatformInfo.isIOS ? CupertinoIcons.compass : Icons.explore,
            label: _tabLabels[0],
          ),
          AdaptiveNavigationDestination(
            icon:
                settings.useIOS26Style
                    ? 'book.closed.fill'
                    : PlatformInfo.isIOS
                    ? CupertinoIcons.book
                    : Icons.book_outlined,
            selectedIcon:
                PlatformInfo.isIOS ? CupertinoIcons.book_solid : Icons.book,
            label: _tabLabels[1],
          ),
          AdaptiveNavigationDestination(
            icon:
                settings.useIOS26Style
                    ? 'clock.fill'
                    : PlatformInfo.isIOS
                    ? CupertinoIcons.time
                    : Icons.history,
            selectedIcon:
                PlatformInfo.isIOS ? CupertinoIcons.time : Icons.history,
            label: _tabLabels[2],
          ),
          AdaptiveNavigationDestination(
            icon:
                settings.useIOS26Style
                    ? 'text.bubble.fill'
                    : PlatformInfo.isIOS
                    ? CupertinoIcons.chat_bubble_2
                    : Icons.forum_outlined,
            selectedIcon:
                PlatformInfo.isIOS
                    ? CupertinoIcons.chat_bubble_2_fill
                    : Icons.forum,
            label: _tabLabels[3],
            badgeCount:
                unreadNotificationCount > 0
                    ? unreadNotificationCount > 99
                        ? 99
                        : unreadNotificationCount
                    : null,
          ),
          AdaptiveNavigationDestination(
            icon:
                settings.useIOS26Style
                    ? 'gearshape.fill'
                    : PlatformInfo.isIOS
                    ? CupertinoIcons.settings
                    : Icons.settings_outlined,
            selectedIcon:
                PlatformInfo.isIOS ? CupertinoIcons.settings : Icons.settings,
            label: _tabLabels[4],
          ),
        ],
      ),
    );
  }

  Widget _buildLargeScreenScaffold(
    AppWindowClass windowClass,
    int unreadNotificationCount,
  ) {
    final activePaneCanPop =
        windowClass.supportsSecondaryPane &&
        _paneCoordinator.canPop(_currentIndex);

    return PopScope(
      canPop: !activePaneCanPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && windowClass.supportsSecondaryPane) {
          _paneCoordinator.pop(_currentIndex);
          setState(() {});
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: _currentIndex,
                onDestinationSelected: _handleTabChanged,
                minWidth: _railMinWidth,
                minExtendedWidth: _railExtendedWidth,
                extended: windowClass == AppWindowClass.expanded,
                labelType:
                    windowClass == AppWindowClass.medium
                        ? NavigationRailLabelType.all
                        : NavigationRailLabelType.none,
                destinations: [
                  const NavigationRailDestination(
                    icon: Icon(Icons.explore_outlined),
                    selectedIcon: Icon(Icons.explore),
                    label: Text('发现'),
                  ),
                  const NavigationRailDestination(
                    icon: Icon(Icons.book_outlined),
                    selectedIcon: Icon(Icons.book),
                    label: Text('书架'),
                  ),
                  const NavigationRailDestination(
                    icon: Icon(Icons.history),
                    selectedIcon: Icon(Icons.history),
                    label: Text('历史'),
                  ),
                  NavigationRailDestination(
                    icon: Badge.count(
                      count:
                          unreadNotificationCount > 99
                              ? 99
                              : unreadNotificationCount,
                      isLabelVisible: unreadNotificationCount > 0,
                      child: const Icon(Icons.forum_outlined),
                    ),
                    selectedIcon: Badge.count(
                      count:
                          unreadNotificationCount > 99
                              ? 99
                              : unreadNotificationCount,
                      isLabelVisible: unreadNotificationCount > 0,
                      child: const Icon(Icons.forum),
                    ),
                    label: Text('社区'),
                  ),
                  const NavigationRailDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: Text('设置'),
                  ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: List<Widget>.generate(
                    _tabLabels.length,
                    _buildScopedPage,
                  ),
                ),
              ),
              if (windowClass.supportsSecondaryPane) ...[
                const VerticalDivider(width: 1),
                Expanded(
                  child: Container(
                    color: Theme.of(context).colorScheme.surface,
                    child: IndexedStack(
                      index: _currentIndex,
                      children: List<Widget>.generate(
                        _tabLabels.length,
                        _buildSecondaryPaneForTab,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryPaneForTab(int index) {
    return AppPaneTabScope(
      tabIndex: index,
      child: AppSecondaryPaneNavigator(
        coordinator: _paneCoordinator,
        tabIndex: index,
        title: _secondaryPaneTitleFor(index),
        subtitle: _secondaryPaneSubtitleFor(index),
        onStackChanged: () {
          if (mounted) {
            setState(() {});
          }
        },
      ),
    );
  }

  String _secondaryPaneTitleFor(int index) {
    return '平行视界';
  }

  String _secondaryPaneSubtitleFor(int index) {
    return '更多内容';
  }
}
