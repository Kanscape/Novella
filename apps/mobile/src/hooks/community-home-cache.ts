import { useSyncExternalStore } from 'react';

import type { CommunityHomePayload } from '@novella/api-client';

/**
 * Module-level cache of the last successful Community home payload. The
 * community home screen publishes it after `loadHome` succeeds so that
 * standalone routes (e.g. the Discover page with hot discussions and active
 * members) can render the same data without re-fetching.
 */
let home: CommunityHomePayload | null = null;
const listeners = new Set<() => void>();

function emit() {
  listeners.forEach((listener) => listener());
}

export function setCachedCommunityHome(value: CommunityHomePayload | null): void {
  if (value === home) return;
  home = value;
  emit();
}

export function getCachedCommunityHome(): CommunityHomePayload | null {
  return home;
}

function subscribe(listener: () => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

export function useCachedCommunityHome(): CommunityHomePayload | null {
  return useSyncExternalStore(subscribe, getCachedCommunityHome);
}
