import { useLocalSearchParams } from 'expo-router';

import { BookDetailScreen } from '@/screens/book-detail-screen';

export default function BookDetailRoute() {
  const { id: rawId } = useLocalSearchParams<{ id: string }>();
  return <BookDetailScreen bookId={Number(rawId)} />;
}
