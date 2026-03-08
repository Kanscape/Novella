/*
 * This request queue architecture is inspired by the lightnovelshelf/web project.
 * Original Repository: https://github.com/LightNovelShelf/Web
 * Original License: AGPL-3.0
 * * Reference: src/services/internal/request/createRequestQueue.ts
 * Implements client-side rate limiting to match server expectations.
 */

import 'dart:async';

/// Scope labels used to deprioritize or cancel stale work when pages change.
class RequestScopes {
  static const String home = 'home';
  static const String shelf = 'shelf';
  static const String history = 'history';

  const RequestScopes._();
}

enum RequestPriority { low, normal, high }

class RequestCancelledException implements Exception {
  final String scope;

  const RequestCancelledException(this.scope);

  @override
  String toString() => 'RequestCancelledException(scope: $scope)';
}

bool isRequestCancelledError(Object error) =>
    error is RequestCancelledException;

class RequestQueue {
  static final RequestQueue _instance = RequestQueue._internal();

  factory RequestQueue() {
    return _instance;
  }

  RequestQueue._internal();

  static const int _maxRequests = 10;
  static const Duration _windowDuration = Duration(milliseconds: 5500);

  final List<DateTime> _requestTimestamps = <DateTime>[];
  final List<_PendingRequestBase> _pendingRequests = <_PendingRequestBase>[];

  bool _isProcessing = false;
  int _sequence = 0;

  Future<T> enqueue<T>(
    Future<T> Function() request, {
    bool bypassQueue = false,
    String? scope,
    RequestPriority priority = RequestPriority.normal,
  }) async {
    if (bypassQueue) {
      return await request();
    }

    final completer = Completer<T>();
    _pendingRequests.add(
      _PendingRequest<T>(
        request: request,
        completer: completer,
        scope: scope,
        priority: priority,
        sequence: _sequence++,
      ),
    );
    _processQueue();
    return completer.future;
  }

  void cancelScope(String scope) {
    final canceled = <_PendingRequestBase>[];

    _pendingRequests.removeWhere((pending) {
      final shouldCancel = pending.scope == scope;
      if (shouldCancel) {
        canceled.add(pending);
      }
      return shouldCancel;
    });

    for (final pending in canceled) {
      pending.cancel(RequestCancelledException(scope));
    }
  }

  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      while (_pendingRequests.isNotEmpty) {
        final now = DateTime.now();
        _requestTimestamps.removeWhere(
          (timestamp) => now.difference(timestamp) > _windowDuration,
        );

        if (_requestTimestamps.length < _maxRequests) {
          final pending = _takeNextPending();
          if (pending == null) {
            break;
          }

          _requestTimestamps.add(DateTime.now());
          _executeRequest(pending);
        } else if (_requestTimestamps.isNotEmpty) {
          final firstRequestTime = _requestTimestamps.first;
          final waitDuration =
              _windowDuration - now.difference(firstRequestTime);
          if (waitDuration > Duration.zero) {
            await Future.delayed(waitDuration);
          }
        } else {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
    } finally {
      _isProcessing = false;
    }
  }

  _PendingRequestBase? _takeNextPending() {
    if (_pendingRequests.isEmpty) {
      return null;
    }

    var bestIndex = 0;
    for (var i = 1; i < _pendingRequests.length; i++) {
      final current = _pendingRequests[i];
      final best = _pendingRequests[bestIndex];
      if (current.priority.index > best.priority.index ||
          (current.priority == best.priority &&
              current.sequence < best.sequence)) {
        bestIndex = i;
      }
    }

    return _pendingRequests.removeAt(bestIndex);
  }

  Future<void> _executeRequest(_PendingRequestBase pending) async {
    try {
      await pending.execute();
    } catch (e, stack) {
      pending.completeError(e, stack);
    }
  }
}

abstract class _PendingRequestBase {
  String? get scope;
  RequestPriority get priority;
  int get sequence;

  Future<void> execute();
  void cancel(Object error);
  void completeError(Object error, StackTrace stackTrace);
}

class _PendingRequest<T> implements _PendingRequestBase {
  final Future<T> Function() request;
  final Completer<T> completer;
  @override
  final String? scope;
  @override
  final RequestPriority priority;
  @override
  final int sequence;

  _PendingRequest({
    required this.request,
    required this.completer,
    required this.scope,
    required this.priority,
    required this.sequence,
  });

  @override
  Future<void> execute() async {
    final result = await request();
    if (!completer.isCompleted) {
      completer.complete(result);
    }
  }

  @override
  void cancel(Object error) {
    if (!completer.isCompleted) {
      completer.completeError(error);
    }
  }

  @override
  void completeError(Object error, StackTrace stackTrace) {
    if (!completer.isCompleted) {
      completer.completeError(error, stackTrace);
    }
  }
}
