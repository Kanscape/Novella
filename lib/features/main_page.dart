import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novella/core/network/request_queue.dart';
import 'package:novella/core/network/signalr_service.dart';
import 'package:novella/core/services/update_service.dart';
import 'package:novella/core/widgets/m3e_loading_indicator.dart';
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
  int _currentIndex = 0;
  final _homeKey = GlobalKey<HomePageState>();
  final _shelfKey = GlobalKey<ShelfPageState>();
  final _historyKey = GlobalKey<HistoryPageState>();
  final _signalRService = SignalRService();
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
      default:
        return null;
    }
  }

  void _updateTabActivity(int activeIndex) {
    _homeKey.currentState?.setTabActive(activeIndex == 0);
    _shelfKey.currentState?.setTabActive(activeIndex == 1);
    _historyKey.currentState?.setTabActive(activeIndex == 2);
  }

  void _cancelInactiveTabRequests(int activeIndex) {
    for (var index = 0; index < 4; index++) {
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
        return const SettingsPage();
      default:
        return const SizedBox.shrink();
    }
  }

  void _handleTabChanged(int index) {
    if (_currentIndex == index) {
      if (index == 1) {
        _shelfKey.currentState?.refresh();
      } else if (index == 2) {
        _historyKey.currentState?.refresh();
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

    return AdaptiveScaffold(
      minimizeBehavior: TabBarMinimizeBehavior.never,
      body: IndexedStack(
        index: _currentIndex,
        children: List<Widget>.generate(4, _buildPage),
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
            label: '发现',
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
            label: '书架',
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
            label: '历史',
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
            label: '设置',
          ),
        ],
      ),
    );
  }
}
