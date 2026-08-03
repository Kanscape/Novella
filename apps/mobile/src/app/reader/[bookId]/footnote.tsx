import { useLocalSearchParams } from 'expo-router';
import { useEffect } from 'react';

import { NativeRouteBottomSheet } from '@/components/native-route-bottom-sheet';
import { ReaderFootnoteSheetScreen } from '@/screens/reader-footnote-sheet-screen';
import {
  getReaderFootnoteSession,
  releaseReaderFootnoteSession,
} from '@/services/reader-footnote-session';

export default function ReaderFootnoteRoute() {
  const { bookId: rawBookId, token = '' } = useLocalSearchParams<{
    bookId: string;
    token?: string;
  }>();
  const bookId = Number(rawBookId);
  const session = getReaderFootnoteSession(token);

  useEffect(() => () => releaseReaderFootnoteSession(token), [token]);

  return (
    <NativeRouteBottomSheet bookId={bookId} snapPoints={['50%', '100%']}>
      <ReaderFootnoteSheetScreen bookId={bookId} session={session} />
    </NativeRouteBottomSheet>
  );
}
