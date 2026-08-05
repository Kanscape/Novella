import { useCallback, useState } from 'react';

import { ApiError } from '@novella/api-client';

import { community } from '@/services/client';
import { markCommunityThreadChanged } from '@/services/community-reply-events';

/**
 * Submit a community reply from the reply compose bottom sheet. Mirrors the
 * book comment composer: posts through the shared use case, signals the
 * thread screen to refresh, and returns whether the post landed.
 */
export function useCommunityReplySubmission(threadId: number, replyToId?: number) {
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const submit = useCallback(async (content: string) => {
    if (isSubmitting) return false;
    setError(null);
    setIsSubmitting(true);
    try {
      await community.createReply({
        threadId,
        content,
        ...(replyToId ? { replyToId } : {}),
      });
      markCommunityThreadChanged();
      return true;
    } catch (nextError) {
      setError(getCommunityReplySubmissionError(nextError));
      return false;
    } finally {
      setIsSubmitting(false);
    }
  }, [isSubmitting, replyToId, threadId]);

  return { error, isSubmitting, submit };
}

function getCommunityReplySubmissionError(error: unknown): string {
  if (error instanceof ApiError) {
    if (error.category === 'auth') return 'Sign in again to post replies.';
    if (error.category === 'network') return 'Replies cannot be posted while offline.';
    return error.message;
  }
  return 'The reply could not be posted.';
}
