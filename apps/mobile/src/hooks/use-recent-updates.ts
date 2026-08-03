import { useCallback, useEffect, useRef, useState } from 'react';

import {
  ApiError,
  RequestCancelledError,
  type BookListItem,
} from '@novella/api-client';

import { discovery } from '@/services/client';
import { filterBooksByContentSettings } from '@/services/content-filter';
import { useAppSettings } from '@/services/settings';

export type RecentUpdatesStatus = 'loading' | 'loadingMore' | 'ready' | 'error' | 'refreshing';

export interface RecentUpdatesState {
  books: BookListItem[];
  error: string | null;
  page: number;
  status: RecentUpdatesStatus;
  totalPages: number;
}

const INITIAL_STATE: RecentUpdatesState = {
  books: [],
  error: null,
  page: 0,
  status: 'loading',
  totalPages: 0,
};

const PAGE_SIZE = 24; // matches the Flutter recently-updated page size

export function useRecentUpdates() {
  const settings = useAppSettings();
  const [state, setState] = useState<RecentUpdatesState>(INITIAL_STATE);
  const generation = useRef(0);
  const controller = useRef<AbortController | null>(null);

  const run = useCallback(async (page: number, append: boolean, preserveData = false) => {
    const requestGeneration = ++generation.current;
    controller.current?.abort();
    const nextController = new AbortController();
    controller.current = nextController;
    setState((current) => {
      // A user-initiated pull refresh keeps the visible list and shows the
      // RefreshControl spinner ('refreshing'). Initial loads and retries
      // replace the content, clearing books so the skeleton shows instead.
      const keepData = preserveData && current.books.length > 0;
      return {
        ...current,
        error: null,
        status: append ? 'loadingMore' : keepData ? 'refreshing' : 'loading',
        ...(append || keepData ? {} : { books: [], page: 0, totalPages: 0 }),
      };
    });

    try {
      const response = await discovery.loadLatestBooksPage({
        page,
        size: PAGE_SIZE,
        ignoreAI: settings.ignoreAI,
        ignoreJapanese: settings.ignoreJapanese,
      });
      if (requestGeneration !== generation.current || nextController.signal.aborted) return;
      const books = filterBooksByContentSettings(response.items, {
        ignoreAI: settings.ignoreAI,
        ignoreJapanese: settings.ignoreJapanese,
        ignoreLevel6: settings.ignoreLevel6,
      });
      setState((current) => ({
        ...current,
        books: append ? dedupeById([...current.books, ...books]) : books,
        page: response.page,
        status: 'ready',
        totalPages: response.totalPages,
      }));
    } catch (error) {
      if (
        requestGeneration !== generation.current ||
        nextController.signal.aborted ||
        error instanceof RequestCancelledError
      ) return;
      setState((current) => ({
        ...current,
        error: recentUpdatesErrorMessage(error),
        status: 'error',
      }));
    }
  }, [settings.ignoreAI, settings.ignoreJapanese, settings.ignoreLevel6]);

  const refresh = useCallback(() => {
    void run(1, false, true);
  }, [run]);

  const loadMore = useCallback(() => {
    if (
      state.status === 'loading' ||
      state.status === 'loadingMore' ||
      state.status === 'refreshing' ||
      state.page >= state.totalPages
    ) return;
    void run(state.page + 1, true);
  }, [run, state.page, state.status, state.totalPages]);

  const retry = useCallback(() => {
    void run(1, false);
  }, [run]);

  useEffect(() => {
    refresh();
    return () => {
      generation.current += 1;
      controller.current?.abort();
    };
  }, [refresh]);

  return {
    books: state.books,
    error: state.error,
    loadMore,
    page: state.page,
    refresh,
    retry,
    status: state.status,
    totalPages: state.totalPages,
  };
}

function dedupeById(items: BookListItem[]): BookListItem[] {
  const seen = new Set<number>();
  return items.filter((item) => {
    if (seen.has(item.id)) return false;
    seen.add(item.id);
    return true;
  });
}

function recentUpdatesErrorMessage(error: unknown): string {
  if (error instanceof ApiError) {
    if (error.category === 'auth') {
      return 'Your session has expired. Sign in again to continue.';
    }
    if (error.category === 'network') {
      return 'LightNovelShelf is unreachable. Check your connection and try again.';
    }
    return error.message;
  }
  return 'LightNovelShelf returned an unexpected response.';
}
