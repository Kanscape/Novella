import { useCallback, useEffect, useState } from 'react';

import { ApiError } from '@novella/api-client';
import type { ShelfSnapshot } from '@novella/client-core';

import { shelf } from '@/services/client';

export type ShelfState =
  | { status: 'loading'; snapshot: null; error: null }
  | { status: 'refreshing'; snapshot: ShelfSnapshot; error: null }
  | { status: 'ready'; snapshot: ShelfSnapshot; error: null }
  | { status: 'error'; snapshot: null; error: string };

export function useShelf() {
  const [state, setState] = useState<ShelfState>({
    status: 'loading',
    snapshot: null,
    error: null,
  });

  const load = useCallback(async (refresh = false) => {
    setState((current) =>
      refresh && current.snapshot
        ? { status: 'refreshing', snapshot: current.snapshot, error: null }
        : { status: 'loading', snapshot: null, error: null },
    );

    try {
      const snapshot = await shelf.load();
      setState({ status: 'ready', snapshot, error: null });
    } catch (error) {
      setState({
        status: 'error',
        snapshot: null,
        error: getShelfErrorMessage(error),
      });
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  return {
    error: state.status === 'error' ? state.error : null,
    isLoading: state.status === 'loading',
    isRefreshing: state.status === 'refreshing',
    reload: () => load(state.status === 'ready' || state.status === 'refreshing'),
    snapshot: state.snapshot,
  };
}

function getShelfErrorMessage(error: unknown): string {
  if (error instanceof ApiError) {
    if (error.category === 'auth') {
      return 'Your session has expired. Sign in again to continue.';
    }
    if (error.category === 'network') {
      return 'LightNovelShelf is unreachable. Check your connection and try again.';
    }
    return error.message;
  }
  return 'Your shelf could not be loaded.';
}
