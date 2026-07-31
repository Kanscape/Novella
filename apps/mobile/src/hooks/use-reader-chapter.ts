import { useCallback, useEffect, useState } from 'react';

import { ApiError, type NovelContent, type TextConversionMode } from '@novella/api-client';

import { reader } from '@/services/client';

type ReaderChapterState =
  | { status: 'loading'; content: null; error: null }
  | { status: 'ready'; content: NovelContent; error: null }
  | { status: 'error'; content: null; error: string };

export function useReaderChapter(
  bookId: number,
  sortNum: number,
  convert: TextConversionMode | undefined,
) {
  const [state, setState] = useState<ReaderChapterState>({
    status: 'loading',
    content: null,
    error: null,
  });

  const load = useCallback(async () => {
    setState({ status: 'loading', content: null, error: null });
    try {
      const content = await reader.loadChapter({
        bookId,
        sortNum,
        ...(convert === undefined ? {} : { convert }),
      });
      setState({ status: 'ready', content, error: null });
    } catch (error) {
      setState({ status: 'error', content: null, error: getReaderErrorMessage(error) });
    }
  }, [bookId, convert, sortNum]);

  useEffect(() => {
    void load();
  }, [load]);

  return {
    content: state.content,
    error: state.error,
    isLoading: state.status === 'loading',
    reload: load,
  };
}

function getReaderErrorMessage(error: unknown): string {
  if (error instanceof ApiError) {
    if (error.category === 'auth') return 'Sign in again to read this chapter.';
    if (error.category === 'network') return 'The chapter could not be loaded while offline.';
    return error.message;
  }
  return 'The chapter could not be loaded.';
}
