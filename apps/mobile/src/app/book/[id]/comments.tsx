import { useLocalSearchParams } from 'expo-router';

import { BookCommentsScreen } from '@/screens/book-comments-screen';

export default function BookCommentsRoute() {
  const { id } = useLocalSearchParams<{ id: string }>();
  return <BookCommentsScreen bookId={Number(id)} />;
}
