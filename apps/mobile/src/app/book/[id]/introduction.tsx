import { useLocalSearchParams } from 'expo-router';

import { NativeRouteBottomSheet } from '@/components/native-route-bottom-sheet';
import { BookInfoSheetScreen } from '@/screens/book-info-sheet-screen';
import type { BookDetailKind } from '@/hooks/use-book-detail';

export default function BookIntroductionRoute() {
  const { id, type } = useLocalSearchParams<{ id: string; type?: string }>();
  const bookId = Number(id);
  const kind: BookDetailKind = type === 'Comic' ? 'Comic' : 'Novel';
  return (
    <NativeRouteBottomSheet bookId={bookId} snapPoints={['50%', '100%']}>
      <BookInfoSheetScreen bookId={bookId} kind={kind} variant="introduction" />
    </NativeRouteBottomSheet>
  );
}
