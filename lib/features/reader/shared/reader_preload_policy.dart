const readerAdjacentPreloadDelay = Duration(milliseconds: 180);

List<int> readerInitialDisplaySortNums({required int sortNum}) {
  return [sortNum];
}

bool shouldAwaitAdjacentChaptersForInitialDisplay() {
  return false;
}

List<int> readerAdjacentPreloadTargets({
  required int sortNum,
  required int totalChapters,
}) {
  if (totalChapters <= 1) {
    return const [];
  }

  return [
    if (sortNum > 1) sortNum - 1,
    if (sortNum < totalChapters) sortNum + 1,
  ];
}
