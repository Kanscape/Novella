import type { ReaderOpenPosition } from '@novella/reader-engine';

export type ReaderChapterKind = 'Comic' | 'Novel';

export interface ReaderChapterSelection {
  bookId: number;
  kind: ReaderChapterKind;
  openPosition: ReaderOpenPosition;
  readerKey: string;
  sortNum: number;
}

type ReaderChapterSelectionListener = (selection: ReaderChapterSelection) => void;
const listeners = new Map<string, ReaderChapterSelectionListener>();

/** Bind a chapter picker to one concrete reader route, not merely a book. */
export function subscribeReaderChapterSelection(
  readerKey: string,
  listener: ReaderChapterSelectionListener,
): () => void {
  listeners.set(readerKey, listener);
  return () => {
    if (listeners.get(readerKey) === listener) listeners.delete(readerKey);
  };
}

export function publishReaderChapterSelection(selection: ReaderChapterSelection): boolean {
  const listener = listeners.get(selection.readerKey);
  if (!listener) return false;
  listener(selection);
  return true;
}
