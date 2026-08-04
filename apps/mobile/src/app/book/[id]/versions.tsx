import { useLocalSearchParams } from 'expo-router';

import { NativeRouteBottomSheet } from '@/components/native-route-bottom-sheet';
import { BookVersionsScreen } from '@/screens/book-versions-screen';

export default function BookVersionsRoute() {
  const { id, title } = useLocalSearchParams<{ id: string; title?: string }>();
  const bookId = Number(id);
  const seriesTitle = typeof title === 'string' && title.trim() ? title : '';
  return (
    <NativeRouteBottomSheet bookId={bookId} snapPoints={['50%', '100%']}>
      <BookVersionsScreen bookId={bookId} seriesTitle={seriesTitle} />
    </NativeRouteBottomSheet>
  );
}
