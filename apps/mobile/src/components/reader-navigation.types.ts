import type { ReaderMode } from '@novella/reader-engine';

export interface ReaderNavigationProps {
  backgroundColor: string;
  foregroundColor: string;
  mode: ReaderMode;
  onModeChange: (mode: ReaderMode) => void;
  onOpenChapters: () => void;
  onOpenSettings: () => void;
  title: string;
}

export interface ReaderChapterNavigationProps {
  bottomInset: number;
  current: number;
  onNext: (() => void) | null;
  onPrevious: (() => void) | null;
  total: number;
}
