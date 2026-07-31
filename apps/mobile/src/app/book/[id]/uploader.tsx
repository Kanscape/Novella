import { useLocalSearchParams } from 'expo-router';

import { NativeRouteBottomSheet } from '@/components/native-route-bottom-sheet';
import { BookInfoSheetScreen } from '@/screens/book-info-sheet-screen';

export default function BookUploaderRoute() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const bookId = Number(id);
  return (
    <NativeRouteBottomSheet bookId={bookId}>
      <BookInfoSheetScreen bookId={bookId} variant="uploader" />
    </NativeRouteBottomSheet>
  );
}
