import 'package:logging/logging.dart';
import 'package:novella/core/network/request_queue.dart';
import 'package:novella/core/network/signalr_service.dart';
import 'package:novella/data/models/book.dart';
import 'package:novella/data/services/book_cover_hint_service.dart';
import 'package:novella/features/book/book_detail_page.dart';

class BookService {
  static final Logger _logger = Logger('BookService');
  final SignalRService _signalRService = SignalRService();
  final BookCoverHintService _bookCoverHintService = BookCoverHintService();

  Future<List<Book>> getLatestBooks({
    int page = 1,
    int size = 20,
    bool ignoreJapanese = false,
    bool ignoreAI = false,
    String? requestScope,
    RequestPriority priority = RequestPriority.normal,
  }) async {
    try {
      final result = await _signalRService.invoke<Map<dynamic, dynamic>>(
        'GetLatestBookList',
        requestScope: requestScope,
        priority: priority,
        args: [
          // 请求参数
          {
            'Page': page,
            'Size': size,
            'Order': 'latest',
            'IgnoreJapanese': ignoreJapanese,
            'IgnoreAI': ignoreAI,
          },
          // 选项（参考 defaultRequestOptions）
          {'UseGzip': true},
        ],
      );

      if (result['Data'] is List) {
        final List<dynamic> list = result['Data'];
        _logger.info('Parsed ${list.length} books from server');
        final books = list.map((e) => Book.fromJson(e)).toList();
        _bookCoverHintService.rememberBooks(books);
        return books;
      }
      return [];
    } catch (e) {
      if (isRequestCancelledError(e)) rethrow;
      _logger.severe('Failed to get latest books: $e');
      rethrow;
    }
  }

  /// 获取书籍列表（分页/排序/过滤）
  Future<SearchResult> getBookList({
    int page = 1,
    int size = 20,
    String order = 'latest',
    bool ignoreJapanese = false,
    bool ignoreAI = false,
    String? requestScope,
    RequestPriority priority = RequestPriority.normal,
  }) async {
    try {
      final result = await _signalRService.invoke<Map<dynamic, dynamic>>(
        'GetBookList',
        requestScope: requestScope,
        priority: priority,
        args: [
          {
            'Page': page,
            'Size': size,
            'Order': order,
            'IgnoreJapanese': ignoreJapanese,
            'IgnoreAI': ignoreAI,
          },
          {'UseGzip': true},
        ],
      );

      final List<dynamic> data = result['Data'] ?? [];
      final int totalPages = result['TotalPages'] ?? 0;

      final books = data.map((e) => Book.fromJson(e)).toList();
      _bookCoverHintService.rememberBooks(books);

      return SearchResult(
        books: books,
        totalPages: totalPages,
        currentPage: page,
      );
    } catch (e) {
      if (isRequestCancelledError(e)) rethrow;
      _logger.severe('Failed to get book list: $e');
      rethrow;
    }
  }

  Future<List<Book>> getBooksByIds(
    List<int> ids, {
    String? requestScope,
    RequestPriority priority = RequestPriority.normal,
  }) async {
    if (ids.isEmpty) return [];

    // 分块加载，每块最多 24 个（参考 PRD）
    final List<Book> allBooks = [];
    final int chunkSize = 24;

    for (var i = 0; i < ids.length; i += chunkSize) {
      final end = (i + chunkSize < ids.length) ? i + chunkSize : ids.length;
      final chunk = ids.sublist(i, end);

      try {
        final result = await _signalRService.invoke<List<dynamic>>(
          'GetBookListByIds',
          requestScope: requestScope,
          priority: priority,
          args: [
            // Request params
            {'Ids': chunk},
            // 选项
            {'UseGzip': true},
          ],
        );

        // 过滤 null 元素（服务端对权限受限书籍可能返回 null）
        final books =
            result
                .whereType<Map<dynamic, dynamic>>()
                .map((e) => Book.fromJson(e))
                .toList();
        _bookCoverHintService.rememberBooks(books);
        allBooks.addAll(books);
      } catch (e) {
        if (isRequestCancelledError(e)) rethrow;
        _logger.severe('Failed to get books chunk $i-$end: $e');
        // 跳过失败分块，继续处理其他分块
      }
    }

    return allBooks;
  }

  /// 获取详细书籍信息（含章节）
  /// 参考 services/book/index.ts
  Future<BookInfo> getBookInfo(
    int id, {
    String? requestScope,
    RequestPriority priority = RequestPriority.normal,
  }) async {
    try {
      final result = await _signalRService.invoke<Map<dynamic, dynamic>>(
        'GetBookInfo',
        requestScope: requestScope,
        priority: priority,
        args: [
          {'Id': id},
          {'UseGzip': true},
        ],
      );

      _logger.info('Got book info for id=$id');
      return BookInfo.fromJson(result);
    } catch (e) {
      if (isRequestCancelledError(e)) rethrow;
      _logger.severe('Failed to get book info: $e');
      rethrow;
    }
  }

  /// 获取指定周期的排行榜
  /// 参考 services/book/index.ts
  /// [days]: 1=日榜, 7=周榜, 31=月榜
  Future<List<Book>> getRank(
    int days, {
    String? requestScope,
    RequestPriority priority = RequestPriority.normal,
  }) async {
    try {
      final result = await _signalRService.invoke<List<dynamic>>(
        'GetRank',
        requestScope: requestScope,
        priority: priority,
        args: [
          {'Days': days},
          {'UseGzip': true},
        ],
      );

      _logger.info('Got ${result.length} books from ranking (days=$days)');
      final books = result.map((e) => Book.fromJson(e)).toList();
      _bookCoverHintService.rememberBooks(books);
      return books;
    } catch (e) {
      if (isRequestCancelledError(e)) rethrow;
      _logger.severe('Failed to get ranking: $e');
      rethrow;
    }
  }

  /// 关键词搜索书籍
  /// 参考 services/book/index.ts
  Future<SearchResult> searchBooks(
    String keywords, {
    int page = 1,
    int size = 10,
    bool ignoreJapanese = false,
    bool ignoreAI = false,
  }) async {
    try {
      final result = await _signalRService.invoke<Map<dynamic, dynamic>>(
        'GetBookList',
        args: [
          {
            'Page': page,
            'Size': size,
            'KeyWords': keywords,
            'IgnoreJapanese': ignoreJapanese,
            'IgnoreAI': ignoreAI,
          },
          {'UseGzip': true},
        ],
      );

      final List<dynamic> data = result['Data'] ?? [];
      final int totalPages = result['TotalPages'] ?? 0;

      _logger.info(
        'Search "$keywords" page $page: ${data.length} results, $totalPages pages',
      );

      return SearchResult(
        books: data.map((e) => Book.fromJson(e)).toList(),
        totalPages: totalPages,
        currentPage: page,
      );
    } catch (e) {
      _logger.severe('Failed to search books: $e');
      rethrow;
    }
  }
}

/// 带分页信息的搜索结果
class SearchResult {
  final List<Book> books;
  final int totalPages;
  final int currentPage;

  SearchResult({
    required this.books,
    required this.totalPages,
    required this.currentPage,
  });
}
