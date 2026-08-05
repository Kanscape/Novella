/**
 * Cross-screen signal that a community reply was posted while the thread
 * screen was not focused (e.g. from the reply compose bottom sheet).
 *
 * The thread screen consumes this on focus: it only refreshes when a reply
 * actually landed, so opening the composer and dismissing it without posting
 * causes no refresh and no re-render churn.
 */

let pendingThreadChange = false;

export function markCommunityThreadChanged(): void {
  pendingThreadChange = true;
}

export function consumeCommunityThreadChanged(): boolean {
  const pending = pendingThreadChange;
  pendingThreadChange = false;
  return pending;
}
