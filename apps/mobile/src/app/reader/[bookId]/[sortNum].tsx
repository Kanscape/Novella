import { useLocalSearchParams } from 'expo-router';

import { ReaderScreen } from '@/screens/reader-screen';
import { ComicReaderScreen } from '@/screens/comic-reader-screen';
import type { ReaderOpenPosition } from '@novella/reader-engine';

export default function ReaderRoute() {
  const { bookId: rawBookId, sortNum: rawSortNum, type, position } = useLocalSearchParams<{
    bookId: string;
    sortNum: string;
    type?: string;
    position?: string;
  }>();
  const openPosition: ReaderOpenPosition = position === 'start' || position === 'end' ? position : 'saved';

  if (type === 'Comic') {
    return <ComicReaderScreen bookId={Number(rawBookId)} sortNum={Number(rawSortNum)} openPosition={openPosition} />;
  }
  return <ReaderScreen bookId={Number(rawBookId)} sortNum={Number(rawSortNum)} openPosition={openPosition} />;
}
