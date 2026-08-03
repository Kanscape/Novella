import { useLocalSearchParams } from 'expo-router';

import { BookDetailScreen } from '@/screens/book-detail-screen';
import { ComicDetailScreen } from '@/screens/comic-detail-screen';

export default function BookDetailRoute() {
  const {
    cover: initialCoverUrl,
    id: rawId,
    placeholder: initialCoverPlaceholder,
    title: initialTitle,
    type,
  } = useLocalSearchParams<{
    cover?: string;
    id: string;
    placeholder?: string;
    title?: string;
    type?: string;
  }>();
  const initialCover = {
    ...(initialCoverUrl ? { initialCoverUrl } : {}),
    ...(initialCoverPlaceholder ? { initialCoverPlaceholder } : {}),
    ...(initialTitle ? { initialTitle } : {}),
  };
  if (type === 'Comic') {
    return <ComicDetailScreen bookId={Number(rawId)} {...initialCover} />;
  }
  const bookType = type === 'Novel' ? 'Novel' : null;
  return (
    <BookDetailScreen
      bookId={Number(rawId)}
      {...initialCover}
      {...(bookType === null ? {} : { bookType })}
    />
  );
}
