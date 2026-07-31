import type { BookDetailPalette } from '@/theme/book-detail-theme';

export interface BookCommentsNavigationProps {
  onCompose: () => void;
  palette: BookDetailPalette;
}
