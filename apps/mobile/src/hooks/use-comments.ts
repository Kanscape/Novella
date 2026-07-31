import { useCallback, useEffect, useState } from 'react';

import { ApiError, type CommentPage, type PostCommentRequest } from '@novella/api-client';

import { comments } from '@/services/client';

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

  const load = useCallback(async (pageNumber = 1, append = false) => {
    setState((current) => ({
      ...current,
      error: null,
      isLoading: !append,
      isLoadingMore: append,
    }));
    try {
      const next = await comments.load({ type: 'Book', id: bookId, page: pageNumber });
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
    } catch (error) {
      setState((current) => ({
        ...current,
        error: getCommentErrorMessage(error),
        isLoading: false,
        isLoadingMore: false,
      }));
    }
  }, [bookId]);

  useEffect(() => {
    void load();
  }, [load]);

  const mutate = useCallback(async (operation: () => Promise<void>) => {
    setState((current) => ({ ...current, error: null, isMutating: true }));
    try {
      await operation();
      await load();
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

  return {
    ...state,
    deleteComment: (commentId: number) => mutate(() => comments.delete(commentId)),
    loadMore: () => {
      if (!state.page || state.isLoadingMore || state.page.page >= state.page.totalPages) return;
      void load(state.page.page + 1, true);
    },
    postComment: (content: string) =>
      mutate(() => comments.post({ type: 'Book', id: bookId, content })),
    refresh: load,
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
