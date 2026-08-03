import {
  createContext,
  use,
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react';

import { bookDetails } from '@/services/client';
import {
  useAnimatedBookDetailTheme,
  useBookDetailTheme,
} from '@/hooks/use-book-detail-theme';
import type { BookDetailTheme } from '@/theme/book-detail-theme';

interface ActiveBookTheme {
  animateChanges: boolean;
  bookId: number | null;
  coverPlaceholder: string | null;
  coverUrl: string | null;
}

interface BookDetailThemeContextValue {
  activate: (
    bookId: number,
    coverUrl: string | null,
    coverPlaceholder: string | null,
    resolveIfMissing: boolean,
  ) => void;
  activeBookId: number | null;
  baseTheme: BookDetailTheme;
  theme: BookDetailTheme;
}

const BookDetailThemeContext = createContext<BookDetailThemeContextValue | null>(null);

export function BookDetailThemeProvider({ children }: { children: ReactNode }) {
  const coverUrls = useRef(new Map<number, string>());
  const coverPlaceholders = useRef(new Map<number, string>());
  const pendingBookIds = useRef(new Set<number>());
  const activeBookId = useRef<number | null>(null);
  const [active, setActive] = useState<ActiveBookTheme>({
    animateChanges: false,
    bookId: null,
    coverPlaceholder: null,
    coverUrl: null,
  });
  const baseTheme = useBookDetailTheme(null, null);
  const targetTheme = useBookDetailTheme(active.coverUrl, active.coverPlaceholder);
  const theme = useAnimatedBookDetailTheme(targetTheme, active.animateChanges);

  const activate = useCallback((
    bookId: number,
    coverUrl: string | null,
    coverPlaceholder: string | null,
    resolveIfMissing: boolean,
  ) => {
    if (coverUrl) coverUrls.current.set(bookId, coverUrl);
    if (coverPlaceholder) coverPlaceholders.current.set(bookId, coverPlaceholder);
    const resolvedCoverUrl = coverUrl ?? coverUrls.current.get(bookId) ?? null;
    const resolvedCoverPlaceholder = coverPlaceholder
      ?? coverPlaceholders.current.get(bookId)
      ?? null;
    const isSameBook = activeBookId.current === bookId;
    activeBookId.current = bookId;
    setActive((current) => {
      if (
        current.bookId === bookId
        && current.coverUrl === resolvedCoverUrl
        && current.coverPlaceholder === resolvedCoverPlaceholder
      ) return current;
      return {
        animateChanges: isSameBook && current.coverUrl === null && resolvedCoverUrl !== null,
        bookId,
        coverPlaceholder: resolvedCoverPlaceholder,
        coverUrl: resolvedCoverUrl,
      };
    });

    if (!resolveIfMissing || resolvedCoverUrl || pendingBookIds.current.has(bookId)) return;
    pendingBookIds.current.add(bookId);
    void bookDetails.load(bookId).then((book) => {
      if (!book.coverUrl) return;
      coverUrls.current.set(bookId, book.coverUrl);
      if (book.coverPlaceholder) coverPlaceholders.current.set(bookId, book.coverPlaceholder);
      if (activeBookId.current !== bookId) return;
      setActive((current) => ({
        animateChanges: current.bookId === bookId && current.coverUrl === null,
        bookId,
        coverPlaceholder: book.coverPlaceholder ?? current.coverPlaceholder,
        coverUrl: book.coverUrl,
      }));
    }).catch(() => undefined).finally(() => {
      pendingBookIds.current.delete(bookId);
    });
  }, []);

  const value = useMemo<BookDetailThemeContextValue>(() => ({
    activate,
    activeBookId: active.bookId,
    baseTheme,
    theme,
  }), [activate, active.bookId, baseTheme, theme]);

  return (
    <BookDetailThemeContext value={value}>
      {children}
    </BookDetailThemeContext>
  );
}

export function useBookDetailRouteTheme(
  bookId: number,
  coverUrl: string | null = null,
  coverPlaceholder: string | null = null,
  resolveIfMissing = false,
): BookDetailTheme {
  const context = use(BookDetailThemeContext);
  if (!context) throw new Error('useBookDetailRouteTheme requires BookDetailThemeProvider');

  useEffect(() => {
    context.activate(bookId, coverUrl, coverPlaceholder, resolveIfMissing);
  }, [bookId, context.activate, coverPlaceholder, coverUrl, resolveIfMissing]);

  return context.activeBookId === bookId ? context.theme : context.baseTheme;
}
