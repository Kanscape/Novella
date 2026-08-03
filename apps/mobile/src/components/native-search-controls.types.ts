import type { BookSearchMode } from '@novella/api-client';

import type { NativeSelectionMenuIcon } from '../../modules/novella-ui';

import type { BookSearchFormat } from '@/hooks/use-book-search';

export const BOOK_SEARCH_MODE_OPTIONS = [
  { androidIcon: 'sparkles', iosIcon: 'sparkles', label: 'Fuzzy', value: 'fuzzy' },
  { androidIcon: 'equal', iosIcon: 'equal', label: 'Exact', value: 'exact' },
  { androidIcon: 'textSize', iosIcon: 'textformat', label: 'Title', value: 'title' },
  { androidIcon: 'user', iosIcon: 'person', label: 'Author', value: 'author' },
  { androidIcon: 'books', iosIcon: 'books.vertical', label: 'Series', value: 'name' },
  { androidIcon: 'tag', iosIcon: 'tag', label: 'Tags', value: 'tags' },
] as const satisfies ReadonlyArray<{
  androidIcon: NativeSelectionMenuIcon;
  iosIcon: string;
  label: string;
  value: BookSearchMode;
}>;

export interface NativeSearchControlsProps {
  format: BookSearchFormat;
  mode: BookSearchMode;
  onFormatChange(format: BookSearchFormat): void;
  onModeChange(mode: BookSearchMode): void;
  onQueryChange(query: string): void;
  onSubmit(query: string): void;
  query: string;
}
