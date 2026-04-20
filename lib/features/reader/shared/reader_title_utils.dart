String simplifyReaderChapterTitle(String title) {
  final trimmed = title.trim();
  if (trimmed.isEmpty) {
    return '';
  }

  final regex = RegExp(
    r'^\s*(?:【([^】]*)】.*|(?![a-zA-Z]+\s)([^\s『「〈]+)[\s『「〈].*)$',
  );
  final match = regex.firstMatch(trimmed);
  if (match == null) {
    return trimmed;
  }

  final extracted = ((match.group(1) ?? '') + (match.group(2) ?? '')).trim();
  return extracted.isEmpty ? trimmed : extracted;
}

String buildReaderDisplayTitle({
  required bool loading,
  required bool cleanChapterTitle,
  String? chapterTitle,
  String? bookTitle,
  String loadingText = '加载中',
  String fallbackText = '阅读',
}) {
  if (loading) {
    return loadingText;
  }

  final rawChapterTitle = chapterTitle?.trim() ?? '';
  if (rawChapterTitle.isNotEmpty) {
    return cleanChapterTitle
        ? simplifyReaderChapterTitle(rawChapterTitle)
        : rawChapterTitle;
  }

  final rawBookTitle = bookTitle?.trim() ?? '';
  if (rawBookTitle.isNotEmpty) {
    return rawBookTitle;
  }

  return fallbackText;
}
