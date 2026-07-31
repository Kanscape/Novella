import { useSyncExternalStore } from 'react';

import { authentication } from '@/services/client';

export function useAuthentication() {
  return useSyncExternalStore(
    authentication.subscribe,
    authentication.getSnapshot,
    authentication.getSnapshot,
  );
}
