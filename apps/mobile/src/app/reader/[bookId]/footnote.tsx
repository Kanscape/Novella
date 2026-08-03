import { useLocalSearchParams } from 'expo-router';

import { NativeRouteBottomSheet } from '@/components/native-route-bottom-sheet';
import { ReaderFootnoteSheetScreen } from '@/screens/reader-footnote-sheet-screen';
import { consumeReaderFootnote } from '@/services/reader-footnote-session';

export default function ReaderFootnoteRoute() {
  const { bookId } = useLocalSearchParams<{ bookId: string }>();
  const payload = consumeReaderFootnote();
  return (
    <NativeRouteBottomSheet bookId={Number(bookId)} snapPoints={['50%', '100%']}>
      <ReaderFootnoteSheetScreen bookId={Number(bookId)} payload={payload} />
    </NativeRouteBottomSheet>
  );
}
