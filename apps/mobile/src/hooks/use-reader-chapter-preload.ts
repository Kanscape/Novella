import { useEffect, useRef, useState } from 'react';
import { InteractionManager } from 'react-native';
import type { TextConversionMode } from '@novella/api-client';

import {
  subscribeClientLifecycle,
} from '@/services/client';
import {
  clearPreloadedReaderChapters,
  preloadReaderChapterWindow,
} from '@/services/reader-chapter-preload';

export function useReaderChapterPreload({
  bookId,
  convert,
  currentSortNum,
  enabled,
  totalChapters,
  windowSize,
}: {
  bookId: number;
  convert?: TextConversionMode;
  currentSortNum: number;
  enabled: boolean;
  totalChapters: number;
  windowSize: number;
}) {
  const [lifecycleState, setLifecycleState] = useState<'background' | 'foreground'>('foreground');
  const preloadControllerRef = useRef<AbortController | null>(null);

  useEffect(
    () => subscribeClientLifecycle((state) => {
      if (state === 'background') preloadControllerRef.current?.abort();
      setLifecycleState(state);
    }),
    [],
  );

  useEffect(() => {
    if (
      !enabled ||
      lifecycleState !== 'foreground' ||
      windowSize <= 0 ||
      currentSortNum >= totalChapters
    ) return;

    const controller = new AbortController();
    preloadControllerRef.current = controller;
    const interaction = InteractionManager.runAfterInteractions(() => {
      void preloadReaderChapterWindow({
        bookId,
        currentSortNum,
        signal: controller.signal,
        totalChapters,
        windowSize,
        ...(convert === undefined ? {} : { convert }),
      }).catch(() => undefined);
    });
    return () => {
      interaction.cancel();
      controller.abort();
      if (preloadControllerRef.current === controller) {
        preloadControllerRef.current = null;
      }
    };
  }, [
    bookId,
    convert,
    currentSortNum,
    enabled,
    lifecycleState,
    totalChapters,
    windowSize,
  ]);

  useEffect(
    () => () => clearPreloadedReaderChapters(bookId),
    [bookId],
  );
}
