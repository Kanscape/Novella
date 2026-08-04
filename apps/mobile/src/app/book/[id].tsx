import { useLocalSearchParams } from 'expo-router';

import { BookDetailScreen } from '@/screens/book-detail-screen';

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
  const bookType = type === 'Comic' ? 'Comic' : type === 'Novel' ? 'Novel' : undefined;
  return (
    <BookDetailScreen
      bookId={Number(rawId)}
      {...initialCover}
      {...(bookType === undefined ? {} : { bookType })}
    />
  );
}
