export interface ReaderPosition {
  bookId: string;
  chapterId: string;
  characterOffset: number;
  updatedAt: string;
}

export interface ReaderProgress {
  completed: number;
  ratio: number;
  total: number;
}

export function calculateReaderProgress(
  completed: number,
  total: number,
): ReaderProgress {
  const safeTotal = Math.max(0, Math.trunc(total));
  const safeCompleted = Math.min(
    safeTotal,
    Math.max(0, Math.trunc(completed)),
  );

  return {
    completed: safeCompleted,
    ratio: safeTotal === 0 ? 0 : safeCompleted / safeTotal,
    total: safeTotal,
  };
}
