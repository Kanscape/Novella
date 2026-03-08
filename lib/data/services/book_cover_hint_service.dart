import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:novella/data/models/book.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BookDisplayHint {
  const BookDisplayHint({this.title, this.coverUrl});

  final String? title;
  final String? coverUrl;
}

class BookCoverHintService {
  static final BookCoverHintService _instance =
      BookCoverHintService._internal();
  factory BookCoverHintService() => _instance;
  BookCoverHintService._internal();

  static const String _prefsKey = 'book_cover_hints_v1';
  static const int _maxEntries = 1200;

  final LinkedHashMap<int, BookDisplayHint> _displayHints =
      LinkedHashMap<int, BookDisplayHint>();
  Future<void>? _initialization;
  SharedPreferences? _prefs;
  Timer? _persistTimer;

  Future<void> ensureInitialized() {
    return _initialization ??= _loadFromPrefs();
  }

  String? getCoverUrl(int bookId) {
    return _touch(bookId)?.coverUrl;
  }

  String? getTitle(int bookId) {
    return _touch(bookId)?.title;
  }

  void rememberBooks(Iterable<Book> books) {
    var changed = false;
    for (final book in books) {
      changed =
          _put(
            book.id,
            BookDisplayHint(
              title: book.title.isEmpty ? null : book.title,
              coverUrl: book.cover.isEmpty ? null : book.cover,
            ),
          ) ||
          changed;
    }

    if (!changed) {
      return;
    }

    if (_prefs != null) {
      _schedulePersist();
      return;
    }

    unawaited(
      ensureInitialized().then((_) {
        _schedulePersist();
      }),
    );
  }

  Future<void> _loadFromPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return;
      }

      for (final entry in decoded.entries) {
        final bookId = int.tryParse(entry.key.toString());
        if (bookId == null) {
          continue;
        }

        if (entry.value is String) {
          final coverUrl = entry.value.toString();
          if (coverUrl.isEmpty) {
            continue;
          }
          _put(bookId, BookDisplayHint(coverUrl: coverUrl));
          continue;
        }

        if (entry.value is! Map) {
          continue;
        }

        final value = Map<String, dynamic>.from(entry.value as Map);
        final coverUrl = value['coverUrl']?.toString();
        final title = value['title']?.toString();
        _put(
          bookId,
          BookDisplayHint(
            title: title?.isNotEmpty == true ? title : null,
            coverUrl: coverUrl?.isNotEmpty == true ? coverUrl : null,
          ),
        );
      }
    } catch (_) {
      // Ignore corrupted persisted hints and rebuild from future requests.
    }
  }

  BookDisplayHint? _touch(int bookId) {
    final hint = _displayHints.remove(bookId);
    if (hint == null) {
      return null;
    }

    _displayHints[bookId] = hint;
    return hint;
  }

  bool _put(int bookId, BookDisplayHint next) {
    if ((next.title == null || next.title!.isEmpty) &&
        (next.coverUrl == null || next.coverUrl!.isEmpty)) {
      return false;
    }

    final previous = _displayHints.remove(bookId);
    final merged = BookDisplayHint(
      title: next.title?.isNotEmpty == true ? next.title : previous?.title,
      coverUrl:
          next.coverUrl?.isNotEmpty == true
              ? next.coverUrl
              : previous?.coverUrl,
    );
    _displayHints[bookId] = merged;

    while (_displayHints.length > _maxEntries) {
      _displayHints.remove(_displayHints.keys.first);
    }

    return previous?.title != merged.title ||
        previous?.coverUrl != merged.coverUrl;
  }

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(_persist());
    });
  }

  Future<void> _persist() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    final payload = <String, Map<String, String>>{
      for (final entry in _displayHints.entries)
        '${entry.key}': {
          if (entry.value.title?.isNotEmpty == true)
            'title': entry.value.title!,
          if (entry.value.coverUrl?.isNotEmpty == true)
            'coverUrl': entry.value.coverUrl!,
        },
    };
    await prefs.setString(_prefsKey, jsonEncode(payload));
  }
}
