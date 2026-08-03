import { useCallback, useEffect, useRef } from 'react';
import { useFocusEffect } from 'expo-router';

import {
  registerClientBackgroundTask,
  subscribeClientLifecycle,
} from '@/services/client';

export function useReaderLifecycleSave(save: () => void | Promise<void>): void {
  const saveRef = useRef(save);
  saveRef.current = save;

  useEffect(() => {
    const unregisterBackgroundTask = registerClientBackgroundTask(() => saveRef.current());
    const unsubscribeLifecycle = subscribeClientLifecycle((state) => {
      if (state === 'foreground') void saveRef.current();
    });
    return () => {
      unsubscribeLifecycle();
      unregisterBackgroundTask();
    };
  }, []);

  useFocusEffect(useCallback(() => () => {
    void saveRef.current();
  }, []));
}
