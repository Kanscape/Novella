import 'dart:async';
import 'dart:collection';

import 'package:flutter/scheduler.dart';
import 'package:novella/core/network/request_queue.dart';
import 'package:novella/data/models/book.dart';
import 'package:novella/data/services/book_service.dart';

class ShelfBookDetailQueue {
  ShelfBookDetailQueue({
    BookService? bookService,
    required this.hasBook,
    required this.onBooksLoaded,
    this.onError,
    this.requestScope = RequestScopes.shelf,
    this.priority = RequestPriority.high,
    this.batchSize = 24,
  }) : _bookService = bookService ?? BookService();

  final BookService _bookService;
  final bool Function(int id) hasBook;
  final void Function(List<Book> books) onBooksLoaded;
  final void Function(Object error)? onError;
  final String? requestScope;
  final RequestPriority priority;
  final int batchSize;

  final LinkedHashSet<int> _pendingIds = LinkedHashSet<int>();
  final Set<int> _requestedIds = <int>{};

  bool _frameFlushScheduled = false;
  bool _disposed = false;

  void enqueue(Iterable<int> ids) {
    if (_disposed) {
      return;
    }

    var added = false;
    for (final id in ids) {
      if (hasBook(id) || _requestedIds.contains(id)) {
        continue;
      }

      _pendingIds.add(id);
      _requestedIds.add(id);
      added = true;
    }

    if (!added) {
      return;
    }

    _scheduleFrameFlush();
  }

  void resetRetriableState() {
    if (_disposed) {
      return;
    }

    _frameFlushScheduled = false;
    _pendingIds.clear();
    _requestedIds.removeWhere((id) => !hasBook(id));
  }

  void cancelPending() {
    if (_disposed) {
      return;
    }

    _frameFlushScheduled = false;
    for (final id in _pendingIds) {
      _requestedIds.remove(id);
    }
    _pendingIds.clear();
  }

  void dispose() {
    _disposed = true;
    _frameFlushScheduled = false;
    _pendingIds.clear();
  }

  void _scheduleFrameFlush() {
    if (_disposed || _frameFlushScheduled) {
      return;
    }

    _frameFlushScheduled = true;
    SchedulerBinding.instance.ensureVisualUpdate();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _frameFlushScheduled = false;
      if (_disposed) {
        return;
      }
      unawaited(_flushPendingGroups());
    });
  }

  Future<void> _flushPendingGroups() async {
    if (_disposed || _pendingIds.isEmpty) {
      return;
    }

    final ids = _pendingIds.toList(growable: false);
    _pendingIds.clear();

    final groups = <List<int>>[];
    for (var index = 0; index < ids.length; index += batchSize) {
      final end = (index + batchSize).clamp(0, ids.length);
      groups.add(ids.sublist(index, end));
    }

    await Future.wait(groups.map(_fetchGroup));

    if (!_disposed && _pendingIds.isNotEmpty) {
      _scheduleFrameFlush();
    }
  }

  Future<void> _fetchGroup(List<int> batch) async {
    try {
      final books = await _bookService.getBooksByIds(
        batch,
        requestScope: requestScope,
        priority: priority,
      );
      if (_disposed) {
        return;
      }
      onBooksLoaded(books);
    } catch (error) {
      if (_disposed) {
        return;
      }

      if (isRequestCancelledError(error)) {
        for (final id in batch) {
          _requestedIds.remove(id);
        }
        return;
      }

      for (final id in batch) {
        _requestedIds.remove(id);
      }
      onError?.call(error);
    }
  }
}
