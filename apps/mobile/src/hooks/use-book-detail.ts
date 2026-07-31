import { useCallback, useEffect, useState } from 'react';

import { ApiError } from '@novella/api-client';
import type { BookDetail } from '@novella/api-client';

import { bookDetails, shelf } from '@/services/client';

type BookDetailState =
  | { status: 'loading'; book: null; error: null }
  | {
      status: 'ready';
      book: BookDetail;
      error: null;
      isInShelf: boolean;
      isShelfLoading: boolean;
      shelfError: string | null;
    }
  | { status: 'error'; book: null; error: string; requiresAuth: boolean };

export function useBookDetail(bookId: number) {
  const [state, setState] = useState<BookDetailState>({
    status: 'loading',
    book: null,
    error: null,
  });

  const load = useCallback(async () => {
    setState({ status: 'loading', book: null, error: null });
    try {
      const [book, isInShelf] = await Promise.all([
        bookDetails.load(bookId),
        shelf.contains(bookId),
      ]);
      setState({
        status: 'ready',
        book,
        error: null,
        isInShelf,
        isShelfLoading: false,
        shelfError: null,
      });
    } catch (error) {
      setState({
        status: 'error',
        book: null,
        error: getBookDetailErrorMessage(error),
        requiresAuth: error instanceof ApiError && error.category === 'auth',
      });
    }
  }, [bookId]);

  useEffect(() => {
    void load();
  }, [load]);

  const toggleShelf = useCallback(async () => {
    setState((current) =>
      current.status === 'ready'
        ? { ...current, isShelfLoading: true, shelfError: null }
        : current,
    );
    try {
      const isInShelf = await shelf.toggleBook(bookId);
      setState((current) =>
        current.status === 'ready'
          ? { ...current, isInShelf, isShelfLoading: false, shelfError: null }
          : current,
      );
    } catch (error) {
      setState((current) =>
        current.status === 'ready'
          ? {
              ...current,
              isShelfLoading: false,
              shelfError: getShelfActionErrorMessage(error),
            }
          : current,
      );
    }
  }, [bookId]);

  return {
    book: state.book,
    error: state.status === 'error' ? state.error : null,
    isInShelf: state.status === 'ready' && state.isInShelf,
    isLoading: state.status === 'loading',
    isShelfLoading: state.status === 'ready' && state.isShelfLoading,
    requiresAuth: state.status === 'error' && state.requiresAuth,
    reload: load,
    shelfError: state.status === 'ready' ? state.shelfError : null,
    toggleShelf,
  };
}

function getBookDetailErrorMessage(error: unknown): string {
  if (error instanceof ApiError) {
    if (error.category === 'auth') {
      return 'Sign in is required to open this book.';
    }
    if (error.category === 'network') {
      return 'LightNovelShelf is unreachable. Check your connection and try again.';
    }
    return error.message;
  }
  return 'The book details could not be loaded.';
}

function getShelfActionErrorMessage(error: unknown): string {
  if (error instanceof ApiError) {
    if (error.category === 'auth') return 'Sign in again to update your shelf.';
    if (error.category === 'network') return 'Your shelf could not be updated while offline.';
    return error.message;
  }
  return 'Your shelf could not be updated.';
}
