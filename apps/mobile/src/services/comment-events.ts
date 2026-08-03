/**
 * Cross-screen signal that a comment was posted or deleted while the comments
 * screen was not focused (e.g. from the comment-compose bottom sheet).
 *
 * The comments screen consumes this on focus: it only refreshes when a comment
 * actually changed, so opening the composer and dismissing it without posting
 * causes no refresh and no re-render churn.
 */

let pendingCommentsChange = false;

export function markCommentsChanged(): void {
  pendingCommentsChange = true;
}

export function consumeCommentsChanged(): boolean {
  const pending = pendingCommentsChange;
  pendingCommentsChange = false;
  return pending;
}
