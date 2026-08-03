import { useCallback, useEffect, useRef, useState } from 'react';

import { ApiError, type CommentPage, type PostCommentRequest } from '@novella/api-client';

import { comments } from '@/services/client';
import { waitForMinimumDisplay } from '@/services/min-skeleton-display';

interface CommentsState {
  error: string | null;
  isLoading: boolean;
  isLoadingMore: boolean;
  isMutating: boolean;
  page: CommentPage | null;
}

const initialState: CommentsState = {
  error: null,
  isLoading: true,
  isLoadingMore: false,
  isMutating: false,
  page: null,
};

export function useComments(bookId: number) {
  const [state, setState] = useState<CommentsState>(initialState);
  // Kept up to date so load() (stabilized on [bookId]) can decide whether the
  // skeleton is on screen without being recreated on every state change.
  const stateRef = useRef(state);
  stateRef.current = state;

  const load = useCallback(async (pageNumber = 1, append = false, silent = false) => {
    const startedAt = Date.now();
    const showSkeleton = !append && !(silent && stateRef.current.page !== null);
    setState((current) => ({
      ...current,
      error: null,
      // Silent reloads (focus return, pull-to-refresh, post-refresh) keep the
      // existing list visible instead of flashing the loading skeleton.
      isLoading: showSkeleton,
      isLoadingMore: append,
    }));
    try {
      const next = await comments.load({ type: 'Book', id: bookId, page: pageNumber });
      if (showSkeleton) await waitForMinimumDisplay(startedAt);
      setState((current) => ({
        ...current,
        error: null,
        isLoading: false,
        isLoadingMore: false,
        page:
          append && current.page
            ? { ...next, items: [...current.page.items, ...next.items] }
            : next,
      }));
      return next;
    } catch (error) {
      if (showSkeleton) await waitForMinimumDisplay(startedAt);
      setState((current) => ({
        ...current,
        error: getCommentErrorMessage(error),
        isLoading: false,
        isLoadingMore: false,
      }));
      return null;
    }
  }, [bookId]);

  useEffect(() => {
    void load();
  }, [load]);

  const mutate = useCallback(async (operation: () => Promise<void>) => {
    setState((current) => ({ ...current, error: null, isMutating: true }));
    try {
      await operation();
      await load(1, false, true);
      setState((current) => ({ ...current, isMutating: false }));
      return true;
    } catch (error) {
      setState((current) => ({
        ...current,
        error: getCommentErrorMessage(error),
        isMutating: false,
      }));
      return false;
    }
  }, [load]);

  const refresh = useCallback(() => load(1, false, true), [load]);

  // Deletes go through their own reconcile flow because the server's
  // DeleteComment hub method is void: it deletes the comment, then answers with
  // an empty payload that @microsoft/signalr-protocol-msgpack rejects with a
  // raw error (misclassified as offline). The invoke error is therefore NOT
  // proof the delete failed — always reconcile with a silent reload and only
  // surface an error when the comment is still present (real failure) or the
  // reload itself cannot reach the server.
  const deleteComment = useCallback((commentId: number) => {
    setState((current) => ({ ...current, error: null, isMutating: true }));
    void (async () => {
      let operationError: unknown = null;
      try {
        await comments.delete(commentId);
      } catch (error) {
        operationError = error;
      }
      let reloadedPage: CommentPage | null = null;
      try {
        reloadedPage = await load(1, false, true);
      } catch {
        reloadedPage = null;
      }
      if (reloadedPage === null) {
        // Reload failed too — show the operation error (if any) as the cause.
        setState((current) => ({
          ...current,
          error: operationError === null
            ? getCommentErrorMessage(new Error('The comment list could not be refreshed.'))
            : getCommentErrorMessage(operationError),
          isMutating: false,
        }));
        return;
      }
      const stillPresent = reloadedPage !== null
        && reloadedPage.items.some((item) => item.id === commentId);
      setState((current) => ({
        ...current,
        // The reloaded list is the server truth: if the comment is gone the
        // delete succeeded (ignore the bogus invoke error); if it is still
        // there the delete really failed.
        error: operationError !== null && stillPresent
          ? getCommentErrorMessage(operationError)
          : null,
        isMutating: false,
      }));
    })();
  }, [load]);

  return {
    ...state,
    deleteComment,
    loadMore: () => {
      if (!state.page || state.isLoadingMore || state.page.page >= state.page.totalPages) return;
      void load(state.page.page + 1, true);
    },
    postComment: (content: string) =>
      mutate(() => comments.post({ type: 'Book', id: bookId, content })),
    refresh,
    replyToComment: (
      content: string,
      parentId: number,
      replyId?: number,
    ) => {
      const request: PostCommentRequest = {
        type: 'Book',
        id: bookId,
        content,
        parentId,
        ...(replyId === undefined ? {} : { replyId }),
      };
      return mutate(() => comments.reply(request));
    },
  };
}

function getCommentErrorMessage(error: unknown): string {
  if (error instanceof ApiError) {
    if (error.category === 'auth') return 'Sign in again to use comments.';
    if (error.category === 'network') return 'Comments are unavailable while offline.';
    return error.message;
  }
  return 'Comments could not be loaded.';
}
