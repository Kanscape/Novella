import { ReaderChapterBar } from '@/components/reader-chrome';
import type { ReaderChapterNavigationProps } from '@/components/reader-navigation.types';

export function ReaderChapterNavigation(props: ReaderChapterNavigationProps) {
  return <ReaderChapterBar {...props} />;
}
