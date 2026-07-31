import { useLocalSearchParams } from 'expo-router';

import { NativeRouteBottomSheet } from '@/components/native-route-bottom-sheet';
import { BookInfoSheetScreen } from '@/screens/book-info-sheet-screen';

export default function BookIntroductionRoute() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const bookId = Number(id);
  return (
    <NativeRouteBottomSheet bookId={bookId} snapPoints={['50%', '100%']}>
      <BookInfoSheetScreen bookId={bookId} variant="introduction" />
    </NativeRouteBottomSheet>
  );
}
