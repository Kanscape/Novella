import { useCallback, useState } from 'react';

import { ApiError, type PostCommentRequest } from '@novella/api-client';

import { comments } from '@/services/client';
import { markCommentsChanged } from '@/services/comment-events';

interface CommentReplyTarget {
  parentId: number;
  replyId?: number;
}

export function useCommentSubmission(bookId: number, replyTarget?: CommentReplyTarget) {
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const submit = useCallback(async (content: string) => {
    if (isSubmitting) return false;
    setError(null);
    setIsSubmitting(true);
    const request: PostCommentRequest = {
      type: 'Book',
      id: bookId,
      content,
      ...(replyTarget
        ? {
            parentId: replyTarget.parentId,
            ...(replyTarget.replyId === undefined ? {} : { replyId: replyTarget.replyId }),
          }
        : {}),
    };
    try {
      if (replyTarget) await comments.reply(request);
      else await comments.post(request);
      markCommentsChanged();
      return true;
    } catch (nextError) {
      setError(getCommentSubmissionError(nextError));
      return false;
    } finally {
      setIsSubmitting(false);
    }
  }, [bookId, isSubmitting, replyTarget]);

  return { error, isSubmitting, submit };
}

function getCommentSubmissionError(error: unknown): string {
  if (error instanceof ApiError) {
    if (error.category === 'auth') return 'Sign in again to post comments.';
    if (error.category === 'network') return 'Comments cannot be posted while offline.';
    return error.message;
  }
  return 'The comment could not be posted.';
}
