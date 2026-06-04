typedef CommunityBoardKey = String;

enum CommunityFeedOrder {
  latest,
  hot,
  featured;

  String get apiValue => name;

  static CommunityFeedOrder fromApi(String? value) {
    return values.firstWhere(
      (item) => item.apiValue == value,
      orElse: () => CommunityFeedOrder.latest,
    );
  }
}

enum CommunityFeedScope {
  all,
  today,
  week;

  String get apiValue => name;

  static CommunityFeedScope fromApi(String? value) {
    return values.firstWhere(
      (item) => item.apiValue == value,
      orElse: () => CommunityFeedScope.all,
    );
  }
}

class CommunityListQuery {
  const CommunityListQuery({
    this.boardKey = 'all',
    this.subCategoryKey = '',
    this.order = CommunityFeedOrder.latest,
    this.scope = CommunityFeedScope.all,
    this.page = 1,
    this.size = 6,
  });

  final CommunityBoardKey boardKey;
  final String subCategoryKey;
  final CommunityFeedOrder order;
  final CommunityFeedScope scope;
  final int page;
  final int size;

  Map<String, dynamic> toJson() {
    return {
      'BoardKey': boardKey,
      'SubCategoryKey': subCategoryKey,
      'Order': order.apiValue,
      'Scope': scope.apiValue,
      'Page': page < 1 ? 1 : page,
      'Size': size < 1 ? 1 : size,
    };
  }
}

class CreateCommunityThreadRequest {
  const CreateCommunityThreadRequest({
    required this.boardKey,
    required this.title,
    required this.contentHtml,
    this.subCategoryKey = '',
  });

  final CommunityBoardKey boardKey;
  final String subCategoryKey;
  final String title;
  final String contentHtml;

  Map<String, dynamic> toJson() {
    return {
      'BoardKey': boardKey,
      'SubCategoryKey': subCategoryKey,
      'Title': title,
      'ContentHtml': contentHtml,
    };
  }
}

class CreateCommunityReplyRequest {
  const CreateCommunityReplyRequest({
    required this.threadId,
    required this.content,
    this.replyToId,
  });

  final int threadId;
  final String content;
  final int? replyToId;

  Map<String, dynamic> toJson() {
    return {
      'ThreadId': threadId,
      'Content': content,
      if (replyToId != null) 'ReplyToId': replyToId,
    };
  }
}

class GetCommunityReplyChildrenRequest {
  const GetCommunityReplyChildrenRequest({
    required this.threadId,
    required this.parentReplyId,
    this.page = 1,
    this.size = 3,
  });

  final int threadId;
  final int parentReplyId;
  final int page;
  final int size;

  Map<String, dynamic> toJson() {
    return {
      'ThreadId': threadId,
      'ParentReplyId': parentReplyId,
      'Page': page < 1 ? 1 : page,
      'Size': size < 1 ? 1 : size,
    };
  }
}

class CommunityCatalogSubCategory {
  const CommunityCatalogSubCategory({
    required this.id,
    required this.key,
    required this.label,
  });

  final int id;
  final String key;
  final String label;

  factory CommunityCatalogSubCategory.fromJson(Map<dynamic, dynamic> json) {
    return CommunityCatalogSubCategory(
      id: _toInt(json['Id']),
      key: _toString(json['Key']),
      label: _toString(json['Label']),
    );
  }
}

class CommunityCatalogBoard {
  const CommunityCatalogBoard({
    required this.id,
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.subCategories,
  });

  final int id;
  final CommunityBoardKey key;
  final String title;
  final String description;
  final String icon;
  final List<CommunityCatalogSubCategory> subCategories;

  factory CommunityCatalogBoard.fromJson(Map<dynamic, dynamic> json) {
    return CommunityCatalogBoard(
      id: _toInt(json['Id']),
      key: _toString(json['Key']),
      title: _toString(json['Title']),
      description: _toString(json['Description']),
      icon: _toString(json['Icon']),
      subCategories: _toList(
        json['SubCategories'],
        CommunityCatalogSubCategory.fromJson,
      ),
    );
  }
}

class CommunitySubCategorySummary {
  const CommunitySubCategorySummary({
    required this.key,
    required this.label,
    required this.count,
  });

  final String key;
  final String label;
  final int count;

  factory CommunitySubCategorySummary.fromJson(Map<dynamic, dynamic> json) {
    return CommunitySubCategorySummary(
      key: _toString(json['Key']),
      label: _toString(json['Label']),
      count: _toInt(json['Count']),
    );
  }
}

class CommunityPagination {
  const CommunityPagination({
    required this.page,
    required this.size,
    required this.total,
    required this.totalPages,
    required this.hasMore,
  });

  final int page;
  final int size;
  final int total;
  final int totalPages;
  final bool hasMore;

  factory CommunityPagination.fromJson(Map<dynamic, dynamic>? json) {
    return CommunityPagination(
      page: _toInt(json?['Page'], fallback: 1),
      size: _toInt(json?['Size']),
      total: _toInt(json?['Total']),
      totalPages: _toInt(json?['TotalPages']),
      hasMore: _toBool(json?['HasMore']),
    );
  }
}

class CommunityBoardSummary {
  const CommunityBoardSummary({
    required this.id,
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.todayPosts,
    required this.heatLabel,
  });

  final int id;
  final CommunityBoardKey key;
  final String title;
  final String description;
  final String icon;
  final int todayPosts;
  final String heatLabel;

  factory CommunityBoardSummary.fromJson(Map<dynamic, dynamic> json) {
    return CommunityBoardSummary(
      id: _toInt(json['Id']),
      key: _toString(json['Key']),
      title: _toString(json['Title']),
      description: _toString(json['Description']),
      icon: _toString(json['Icon']),
      todayPosts: _toInt(json['TodayPosts']),
      heatLabel: _toString(json['HeatLabel']),
    );
  }
}

class CommunityFeedItem {
  const CommunityFeedItem({
    required this.id,
    required this.boardKey,
    required this.boardName,
    required this.subCategoryKey,
    required this.subCategoryLabel,
    required this.title,
    required this.excerpt,
    required this.authorName,
    required this.authorIsDeleted,
    required this.authorAvatar,
    required this.publishedAt,
    required this.replies,
    required this.views,
    required this.heat,
    required this.likes,
    required this.favorites,
    required this.tags,
    required this.featured,
    required this.pinned,
    required this.locked,
  });

  final int id;
  final CommunityBoardKey boardKey;
  final String boardName;
  final String subCategoryKey;
  final String subCategoryLabel;
  final String title;
  final String excerpt;
  final String authorName;
  final bool authorIsDeleted;
  final String authorAvatar;
  final DateTime? publishedAt;
  final int replies;
  final int views;
  final int heat;
  final int likes;
  final int favorites;
  final List<String> tags;
  final bool featured;
  final bool pinned;
  final bool locked;

  factory CommunityFeedItem.fromJson(Map<dynamic, dynamic> json) {
    return CommunityFeedItem(
      id: _toInt(json['Id']),
      boardKey: _toString(json['BoardKey']),
      boardName: _toString(json['BoardName']),
      subCategoryKey: _toString(json['SubCategoryKey']),
      subCategoryLabel: _toString(json['SubCategoryLabel']),
      title: _toString(json['Title']),
      excerpt: _toString(json['Excerpt']),
      authorName: _toString(json['AuthorName']),
      authorIsDeleted: _toBool(json['AuthorIsDeleted']),
      authorAvatar: _toString(json['AuthorAvatar']),
      publishedAt: _toDateTime(json['PublishedAt']),
      replies: _toInt(json['Replies']),
      views: _toInt(json['Views']),
      heat: _toInt(json['Heat']),
      likes: _toInt(json['Likes']),
      favorites: _toInt(json['Favorites']),
      tags: _toStringList(json['Tags']),
      featured: _toBool(json['Featured']),
      pinned: _toBool(json['Pinned']),
      locked: _toBool(json['Locked']),
    );
  }
}

class CommunityHotRankItem {
  const CommunityHotRankItem({
    required this.id,
    required this.title,
    required this.boardName,
    required this.heat,
    required this.publishedAt,
  });

  final int id;
  final String title;
  final String boardName;
  final int heat;
  final DateTime? publishedAt;

  factory CommunityHotRankItem.fromJson(Map<dynamic, dynamic> json) {
    return CommunityHotRankItem(
      id: _toInt(json['Id']),
      title: _toString(json['Title']),
      boardName: _toString(json['BoardName']),
      heat: _toInt(json['Heat']),
      publishedAt: _toDateTime(json['PublishedAt']),
    );
  }
}

class CommunityActiveUserItem {
  const CommunityActiveUserItem({
    required this.id,
    required this.name,
    required this.avatar,
    required this.badge,
    required this.score,
    required this.summary,
  });

  final int id;
  final String name;
  final String avatar;
  final String badge;
  final int score;
  final String summary;

  factory CommunityActiveUserItem.fromJson(Map<dynamic, dynamic> json) {
    return CommunityActiveUserItem(
      id: _toInt(json['Id']),
      name: _toString(json['Name']),
      avatar: _toString(json['Avatar']),
      badge: _toString(json['Badge']),
      score: _toInt(json['Score']),
      summary: _toString(json['Summary']),
    );
  }
}

class CommunityReplyTarget {
  const CommunityReplyTarget({
    required this.id,
    required this.authorName,
    required this.authorIsDeleted,
  });

  final int id;
  final String authorName;
  final bool authorIsDeleted;

  factory CommunityReplyTarget.fromJson(Map<dynamic, dynamic> json) {
    return CommunityReplyTarget(
      id: _toInt(json['Id']),
      authorName: _toString(json['AuthorName']),
      authorIsDeleted: _toBool(json['AuthorIsDeleted']),
    );
  }
}

class CommunityThreadReply {
  const CommunityThreadReply({
    required this.id,
    required this.authorName,
    required this.authorIsDeleted,
    required this.authorBadge,
    required this.authorAvatar,
    required this.publishedAt,
    required this.content,
    required this.likes,
    required this.liked,
    required this.replyTo,
    required this.childReplies,
    required this.childPage,
  });

  final int id;
  final String authorName;
  final bool authorIsDeleted;
  final String authorBadge;
  final String authorAvatar;
  final DateTime? publishedAt;
  final String content;
  final int likes;
  final bool liked;
  final CommunityReplyTarget? replyTo;
  final List<CommunityThreadReply> childReplies;
  final CommunityPagination childPage;

  factory CommunityThreadReply.fromJson(Map<dynamic, dynamic> json) {
    return CommunityThreadReply(
      id: _toInt(json['Id']),
      authorName: _toString(json['AuthorName']),
      authorIsDeleted: _toBool(json['AuthorIsDeleted']),
      authorBadge: _toString(json['AuthorBadge']),
      authorAvatar: _toString(json['AuthorAvatar']),
      publishedAt: _toDateTime(json['PublishedAt']),
      content: _toString(json['Content']),
      likes: _toInt(json['Likes']),
      liked: _toBool(json['Liked']),
      replyTo:
          json['ReplyTo'] is Map<dynamic, dynamic>
              ? CommunityReplyTarget.fromJson(
                json['ReplyTo'] as Map<dynamic, dynamic>,
              )
              : null,
      childReplies: _toList(
        json['ChildReplies'],
        CommunityThreadReply.fromJson,
      ),
      childPage: CommunityPagination.fromJson(
        json['ChildPage'] as Map<dynamic, dynamic>?,
      ),
    );
  }
}

class CommunityThreadDetail extends CommunityFeedItem {
  const CommunityThreadDetail({
    required super.id,
    required super.boardKey,
    required super.boardName,
    required super.subCategoryKey,
    required super.subCategoryLabel,
    required super.title,
    required super.excerpt,
    required super.authorName,
    required super.authorIsDeleted,
    required super.authorAvatar,
    required super.publishedAt,
    required super.replies,
    required super.views,
    required super.heat,
    required super.likes,
    required super.favorites,
    required super.tags,
    required super.featured,
    required super.pinned,
    required super.locked,
    required this.liked,
    required this.favorited,
    required this.bodyHtml,
    required this.repliesPage,
    required this.replyItems,
    required this.relatedThreads,
  });

  final bool liked;
  final bool favorited;
  final String bodyHtml;
  final CommunityPagination repliesPage;
  final List<CommunityThreadReply> replyItems;
  final List<CommunityFeedItem> relatedThreads;

  factory CommunityThreadDetail.fromJson(Map<dynamic, dynamic> json) {
    final base = CommunityFeedItem.fromJson(json);
    return CommunityThreadDetail(
      id: base.id,
      boardKey: base.boardKey,
      boardName: base.boardName,
      subCategoryKey: base.subCategoryKey,
      subCategoryLabel: base.subCategoryLabel,
      title: base.title,
      excerpt: base.excerpt,
      authorName: base.authorName,
      authorIsDeleted: base.authorIsDeleted,
      authorAvatar: base.authorAvatar,
      publishedAt: base.publishedAt,
      replies: base.replies,
      views: base.views,
      heat: base.heat,
      likes: base.likes,
      favorites: base.favorites,
      tags: base.tags,
      featured: base.featured,
      pinned: base.pinned,
      locked: base.locked,
      liked: _toBool(json['Liked']),
      favorited: _toBool(json['Favorited']),
      bodyHtml: _toString(json['BodyHtml']),
      repliesPage: CommunityPagination.fromJson(
        json['RepliesPage'] as Map<dynamic, dynamic>?,
      ),
      replyItems: _toList(json['ReplyItems'], CommunityThreadReply.fromJson),
      relatedThreads: _toList(
        json['RelatedThreads'],
        CommunityFeedItem.fromJson,
      ),
    );
  }
}

class CommunityHomePayload {
  const CommunityHomePayload({
    required this.title,
    required this.subtitle,
    required this.announcement,
    required this.announcementLink,
    required this.todayThreads,
    required this.onlineUserCount,
    required this.catalogBoards,
    required this.boards,
    required this.subCategories,
    required this.selectedSubCategoryKey,
    required this.feed,
    required this.feedPage,
    required this.hotThreads,
    required this.activeUsers,
  });

  final String title;
  final String subtitle;
  final String announcement;
  final String announcementLink;
  final int todayThreads;
  final int onlineUserCount;
  final List<CommunityCatalogBoard> catalogBoards;
  final List<CommunityBoardSummary> boards;
  final List<CommunitySubCategorySummary> subCategories;
  final String selectedSubCategoryKey;
  final List<CommunityFeedItem> feed;
  final CommunityPagination feedPage;
  final List<CommunityHotRankItem> hotThreads;
  final List<CommunityActiveUserItem> activeUsers;

  factory CommunityHomePayload.fromJson(Map<dynamic, dynamic> json) {
    return CommunityHomePayload(
      title: _toString(json['Title']),
      subtitle: _toString(json['Subtitle']),
      announcement: _toString(json['Announcement']),
      announcementLink: _toString(json['AnnouncementLink']),
      todayThreads: _toInt(json['TodayThreads']),
      onlineUserCount: _toInt(json['OnlineUserCount']),
      catalogBoards: _toList(
        json['CatalogBoards'],
        CommunityCatalogBoard.fromJson,
      ),
      boards: _toList(json['Boards'], CommunityBoardSummary.fromJson),
      subCategories: _toList(
        json['SubCategories'],
        CommunitySubCategorySummary.fromJson,
      ),
      selectedSubCategoryKey: _toString(json['SelectedSubCategoryKey']),
      feed: _toList(json['Feed'], CommunityFeedItem.fromJson),
      feedPage: CommunityPagination.fromJson(
        json['FeedPage'] as Map<dynamic, dynamic>?,
      ),
      hotThreads: _toList(json['HotThreads'], CommunityHotRankItem.fromJson),
      activeUsers: _toList(
        json['ActiveUsers'],
        CommunityActiveUserItem.fromJson,
      ),
    );
  }
}

class CommunityFeedPayload {
  const CommunityFeedPayload({
    required this.subCategories,
    required this.selectedSubCategoryKey,
    required this.feed,
    required this.feedPage,
  });

  final List<CommunitySubCategorySummary> subCategories;
  final String selectedSubCategoryKey;
  final List<CommunityFeedItem> feed;
  final CommunityPagination feedPage;

  factory CommunityFeedPayload.fromJson(Map<dynamic, dynamic> json) {
    return CommunityFeedPayload(
      subCategories: _toList(
        json['SubCategories'],
        CommunitySubCategorySummary.fromJson,
      ),
      selectedSubCategoryKey: _toString(json['SelectedSubCategoryKey']),
      feed: _toList(json['Feed'], CommunityFeedItem.fromJson),
      feedPage: CommunityPagination.fromJson(
        json['FeedPage'] as Map<dynamic, dynamic>?,
      ),
    );
  }
}

class CommunityReplyChildrenPayload {
  const CommunityReplyChildrenPayload({
    required this.items,
    required this.page,
  });

  final List<CommunityThreadReply> items;
  final CommunityPagination page;

  factory CommunityReplyChildrenPayload.fromJson(Map<dynamic, dynamic> json) {
    return CommunityReplyChildrenPayload(
      items: _toList(json['Items'], CommunityThreadReply.fromJson),
      page: CommunityPagination.fromJson(
        json['Page'] as Map<dynamic, dynamic>?,
      ),
    );
  }
}

class CommunityMyReplyItem {
  const CommunityMyReplyItem({
    required this.id,
    required this.threadId,
    required this.threadTitle,
    required this.boardName,
    required this.content,
    required this.publishedAt,
    required this.likes,
    required this.replyToName,
  });

  final int id;
  final int threadId;
  final String threadTitle;
  final String boardName;
  final String content;
  final DateTime? publishedAt;
  final int likes;
  final String replyToName;

  factory CommunityMyReplyItem.fromJson(Map<dynamic, dynamic> json) {
    return CommunityMyReplyItem(
      id: _toInt(json['Id']),
      threadId: _toInt(json['ThreadId']),
      threadTitle: _toString(json['ThreadTitle']),
      boardName: _toString(json['BoardName']),
      content: _toString(json['Content']),
      publishedAt: _toDateTime(json['PublishedAt']),
      likes: _toInt(json['Likes']),
      replyToName: _toString(json['ReplyToName']),
    );
  }
}

class CommunityMyOverview {
  const CommunityMyOverview({
    required this.authorName,
    required this.publishedThreads,
    required this.participatedReplies,
    required this.favoriteThreads,
  });

  final String authorName;
  final List<CommunityFeedItem> publishedThreads;
  final List<CommunityMyReplyItem> participatedReplies;
  final List<CommunityFeedItem> favoriteThreads;

  factory CommunityMyOverview.fromJson(Map<dynamic, dynamic> json) {
    return CommunityMyOverview(
      authorName: _toString(json['AuthorName']),
      publishedThreads: _toList(
        json['PublishedThreads'],
        CommunityFeedItem.fromJson,
      ),
      participatedReplies: _toList(
        json['ParticipatedReplies'],
        CommunityMyReplyItem.fromJson,
      ),
      favoriteThreads: _toList(
        json['FavoriteThreads'],
        CommunityFeedItem.fromJson,
      ),
    );
  }
}

class CommunityLikeToggleResult {
  const CommunityLikeToggleResult({required this.liked, required this.likes});

  final bool liked;
  final int likes;

  factory CommunityLikeToggleResult.fromJson(Map<dynamic, dynamic> json) {
    return CommunityLikeToggleResult(
      liked: _toBool(json['Liked']),
      likes: _toInt(json['Likes']),
    );
  }
}

class CommunityFavoriteToggleResult {
  const CommunityFavoriteToggleResult({
    required this.favorited,
    required this.favorites,
  });

  final bool favorited;
  final int favorites;

  factory CommunityFavoriteToggleResult.fromJson(Map<dynamic, dynamic> json) {
    return CommunityFavoriteToggleResult(
      favorited: _toBool(json['Favorited']),
      favorites: _toInt(json['Favorites']),
    );
  }
}

int _toInt(dynamic value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

bool _toBool(dynamic value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  final normalized = value?.toString().toLowerCase();
  if (normalized == 'true' || normalized == '1') {
    return true;
  }
  if (normalized == 'false' || normalized == '0') {
    return false;
  }
  return fallback;
}

String _toString(dynamic value, {String fallback = ''}) {
  final result = value?.toString();
  if (result == null || result == 'null') {
    return fallback;
  }
  return result;
}

DateTime? _toDateTime(dynamic value) {
  final raw = value?.toString();
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw);
}

List<String> _toStringList(dynamic value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .map((item) => _toString(item))
      .where((item) => item.isNotEmpty)
      .toList();
}

List<T> _toList<T>(
  dynamic value,
  T Function(Map<dynamic, dynamic> json) mapper,
) {
  if (value is! List) {
    return List<T>.empty(growable: false);
  }
  return value
      .whereType<Map<dynamic, dynamic>>()
      .map(mapper)
      .toList(growable: false);
}
