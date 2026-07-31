import { useCallback, useEffect, useState } from 'react';

import { ApiError } from '@novella/api-client';
import type { DiscoverySnapshot } from '@novella/client-core';

import { discovery } from '@/services/client';

export type DiscoveryState =
  | { status: 'loading'; snapshot: null; error: null }
  | { status: 'refreshing'; snapshot: DiscoverySnapshot; error: null }
  | { status: 'ready'; snapshot: DiscoverySnapshot; error: null }
  | { status: 'error'; snapshot: null; error: string };

export function useDiscovery() {
  const [state, setState] = useState<DiscoveryState>({
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
      const snapshot = await discovery.load();
      setState({ status: 'ready', snapshot, error: null });
    } catch (error) {
      setState({
        status: 'error',
        snapshot: null,
        error: getDiscoveryErrorMessage(error),
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

function getDiscoveryErrorMessage(error: unknown): string {
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
