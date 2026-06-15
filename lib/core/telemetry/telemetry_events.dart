class TelemetryEvents {
  const TelemetryEvents._();

  static const appDayType = 'app_day_type';
  static const appSession = 'app_session';
  static const settingsSnapshot = 'settings_snapshot';
  static const settingPreferenceChanged = 'setting_preference_changed';
  static const tabClicked = 'tab_clicked';
  static const bookDetailOpened = 'book_detail_opened';
  static const tagFeatureUsed = 'tag_feature_used';
  static const homeRecommendationClicked = 'home_recommendation_clicked';
  static const bookDetailQuickSearchClicked =
      'book_detail_quick_search_clicked';
  static const externalLinkClicked = 'external_link_clicked';
}

class TelemetryProperties {
  const TelemetryProperties._();

  static const action = 'action';
  static const buildChannel = 'build_channel';
  static const buildLabel = 'build_label';
  static const buildNumber = 'build_number';
  static const dayType = 'day_type';
  static const enabledHomeModules = 'enabled_home_modules';
  static const endedBy = 'ended_by';
  static const homeModuleOrder = 'home_module_order';
  static const homeRankType = 'home_rank_type';
  static const ignoreAI = 'ignore_ai';
  static const ignoreJapanese = 'ignore_japanese';
  static const ignoreLevel6 = 'ignore_level6';
  static const item = 'item';
  static const localDate = 'local_date';
  static const localHourBucket = 'local_hour_bucket';
  static const module = 'module';
  static const platform = 'platform';
  static const readerViewMode = 'reader_view_mode';
  static const seriesSearchMode = 'series_search_mode';
  static const screenName = 'screen_name';
  static const sessionDurationBucket = 'session_duration_bucket';
  static const source = 'source';
  static const startupTab = 'startup_tab';
  static const tab = 'tab';
  static const target = 'target';
  static const appVersion = 'app_version';
}

class TelemetryScreens {
  const TelemetryScreens._();

  static const home = 'home';
  static const shelf = 'shelf';
  static const history = 'history';
  static const community = 'community';
  static const settings = 'settings';
  static const bookDetail = 'book_detail';
  static const reader = 'reader';
  static const search = 'search';
  static const ranking = 'ranking';
  static const recentlyUpdated = 'recently_updated';
  static const shelfFolder = 'shelf_folder';
  static const announcement = 'announcement';
  static const communityThread = 'community_thread';
  static const communityNotifications = 'community_notifications';
}

class TelemetryTabs {
  const TelemetryTabs._();

  static const home = 'home';
  static const shelf = 'shelf';
  static const history = 'history';
  static const community = 'community';
  static const settings = 'settings';

  static String fromIndex(int index) {
    return switch (index) {
      0 => home,
      1 => shelf,
      2 => history,
      3 => community,
      4 => settings,
      _ => home,
    };
  }
}

class TelemetryDayTypes {
  const TelemetryDayTypes._();

  static const weekday = 'weekday';
  static const weekend = 'weekend';
}

class TelemetryModules {
  const TelemetryModules._();

  static const ranking = 'ranking';
  static const recentlyUpdated = 'recently_updated';
  static const continueReading = 'continue_reading';
}

class TelemetryActions {
  const TelemetryActions._();

  static const more = 'more';
  static const bookCard = 'book_card';
}

class TelemetryBookDetailSources {
  const TelemetryBookDetailSources._();

  static const homeContinueReading = 'home_continue_reading';
  static const homeRanking = 'home_ranking';
  static const homeRecentlyUpdated = 'home_recently_updated';
  static const ranking = 'ranking';
  static const search = 'search';
  static const shelf = 'shelf';
  static const shelfFolder = 'shelf_folder';
  static const history = 'history';
  static const communityNotification = 'community_notification';
}

class TelemetryQuickSearchTargets {
  const TelemetryQuickSearchTargets._();

  static const title = 'title';
  static const author = 'author';
}

class TelemetryExternalLinkItems {
  const TelemetryExternalLinkItems._();

  static const projectSite = 'project_site';
  static const githubRepository = 'github_repository';
  static const githubDiscussions = 'github_discussions';
  static const githubIssues = 'github_issues';
  static const lightnovelGroup = 'lightnovel_group';
  static const developerGroup = 'developer_group';
}
