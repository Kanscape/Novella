/**
 * Minimum skeleton/loading display time for screens whose data loads fast.
 *
 * A quick network would otherwise flash the skeleton for a few milliseconds.
 * Screens opt in by holding their loading state for at least this long before
 * swapping in content (or an error). Only opt in where the flash is jarring —
 * other screens stay untouched.
 */

export const MIN_LOADING_SKELETON_MS = 500;

export function waitForMinimumDisplay(startedAt: number): Promise<void> {
  const remaining = MIN_LOADING_SKELETON_MS - (Date.now() - startedAt);
  if (remaining <= 0) return Promise.resolve();
  return new Promise((resolve) => {
    setTimeout(resolve, remaining);
  });
}
