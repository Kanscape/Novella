import { useCallback, useEffect, useRef, useState } from 'react';

import {
  ApiError,
  type AnnouncementPage,
  type BookListPage,
  type OnlineInfo,
} from '@novella/api-client';

import { discovery } from '@/services/client';

export type DiscoverySectionState<T> =
  | { status: 'loading'; data: null; error: null }
  | { status: 'refreshing'; data: T; error: null }
  | { status: 'ready'; data: T; error: null }
  | { status: 'error'; data: T | null; error: string };

interface DiscoveryState {
  announcements: DiscoverySectionState<AnnouncementPage>;
  latestBooks: DiscoverySectionState<BookListPage>;
  onlineInfo: DiscoverySectionState<OnlineInfo>;
}

type DiscoverySection = keyof DiscoveryState;

const INITIAL_STATE: DiscoveryState = {
  announcements: { status: 'loading', data: null, error: null },
  latestBooks: { status: 'loading', data: null, error: null },
  onlineInfo: { status: 'loading', data: null, error: null },
};

export function useDiscovery() {
  const [state, setState] = useState<DiscoveryState>(INITIAL_STATE);
  const mounted = useRef(true);
  const epochs = useRef<Record<DiscoverySection, number>>({
    announcements: 0,
    latestBooks: 0,
    onlineInfo: 0,
  });

  useEffect(() => {
    mounted.current = true;
    return () => {
      mounted.current = false;
    };
  }, []);

  const loadAnnouncements = useCallback(async (preserveData = true) => {
    const epoch = ++epochs.current.announcements;
    setState((current) => ({
      ...current,
      announcements: beginLoad(current.announcements, preserveData),
    }));
    try {
      const data = await discovery.loadAnnouncements();
      if (!mounted.current || epoch !== epochs.current.announcements) return;
      setState((current) => ({
        ...current,
        announcements: { status: 'ready', data, error: null },
      }));
    } catch (error) {
      if (!mounted.current || epoch !== epochs.current.announcements) return;
      setState((current) => ({
        ...current,
        announcements: {
          status: 'error',
          data: current.announcements.data,
          error: getDiscoveryErrorMessage(error),
        },
      }));
    }
  }, []);

  const loadLatestBooks = useCallback(async (preserveData = true) => {
    const epoch = ++epochs.current.latestBooks;
    setState((current) => ({
      ...current,
      latestBooks: beginLoad(current.latestBooks, preserveData),
    }));
    try {
      const data = await discovery.loadLatestBooks();
      if (!mounted.current || epoch !== epochs.current.latestBooks) return;
      setState((current) => ({
        ...current,
        latestBooks: { status: 'ready', data, error: null },
      }));
    } catch (error) {
      if (!mounted.current || epoch !== epochs.current.latestBooks) return;
      setState((current) => ({
        ...current,
        latestBooks: {
          status: 'error',
          data: current.latestBooks.data,
          error: getDiscoveryErrorMessage(error),
        },
      }));
    }
  }, []);

  const loadOnlineInfo = useCallback(async (preserveData = true) => {
    const epoch = ++epochs.current.onlineInfo;
    setState((current) => ({
      ...current,
      onlineInfo: beginLoad(current.onlineInfo, preserveData),
    }));
    try {
      const data = await discovery.loadOnlineInfo();
      if (!mounted.current || epoch !== epochs.current.onlineInfo) return;
      setState((current) => ({
        ...current,
        onlineInfo: { status: 'ready', data, error: null },
      }));
    } catch (error) {
      if (!mounted.current || epoch !== epochs.current.onlineInfo) return;
      setState((current) => ({
        ...current,
        onlineInfo: {
          status: 'error',
          data: current.onlineInfo.data,
          error: getDiscoveryErrorMessage(error),
        },
      }));
    }
  }, []);

  const loadAll = useCallback(async (preserveData = true) => {
    await Promise.allSettled([
      loadLatestBooks(preserveData),
      loadAnnouncements(preserveData),
      loadOnlineInfo(preserveData),
    ]);
  }, [loadAnnouncements, loadLatestBooks, loadOnlineInfo]);

  useEffect(() => {
    void loadAll(false);
  }, [loadAll]);

  return {
    announcements: state.announcements,
    isRefreshing: Object.values(state).some(
      (section) => section.status === 'refreshing',
    ),
    latestBooks: state.latestBooks,
    onlineInfo: state.onlineInfo,
    reload: () => loadAll(true),
    retryAnnouncements: () => loadAnnouncements(true),
    retryLatestBooks: () => loadLatestBooks(true),
    retryOnlineInfo: () => loadOnlineInfo(true),
  };
}

function beginLoad<T>(
  current: DiscoverySectionState<T>,
  preserveData: boolean,
): DiscoverySectionState<T> {
  if (preserveData && current.data !== null) {
    return { status: 'refreshing', data: current.data, error: null };
  }
  return { status: 'loading', data: null, error: null };
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
