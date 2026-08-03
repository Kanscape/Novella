import { useEffect, useState } from 'react';

import {
  invisibleCodepointsForReaderFont,
  loadReaderFont,
  readerFontFamilyForUrl,
  resolveReaderFontUrl,
} from '@/services/reader-font-loader';

/**
 * Loads the optional chapter font into a native RN font family.
 *
 * The chapter content remains HTML, but the font is registered with the
 * native text system so `react-native-render-html` can render it without a
 * WebView. Failed font downloads intentionally fall back to the platform
 * font instead of blocking the chapter.
 */
export type ReaderFontState =
  | { status: 'idle'; family: undefined; error: undefined; invisibleCodepoints: ReadonlySet<number> }
  | { status: 'loading'; family: undefined; error: undefined; invisibleCodepoints: ReadonlySet<number> }
  | { status: 'loaded'; family: string; error: undefined; invisibleCodepoints: ReadonlySet<number> }
  | { status: 'error'; family: undefined; error: string; invisibleCodepoints: ReadonlySet<number> };

const EMPTY_CODEPOINTS: ReadonlySet<number> = new Set();
const IDLE_STATE: ReaderFontState = {
  status: 'idle',
  family: undefined,
  error: undefined,
  invisibleCodepoints: EMPTY_CODEPOINTS,
};

export function useReaderFont(fontUrl: string | null | undefined): ReaderFontState & { retry: () => void } {
  const [state, setState] = useState<ReaderFontState>(IDLE_STATE);
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    let cancelled = false;
    const resolvedUrl = resolveReaderFontUrl(fontUrl);
    if (!resolvedUrl) {
      setState(IDLE_STATE);
      return () => {
        cancelled = true;
      };
    }

    const family = readerFontFamilyForUrl(resolvedUrl);
    setState({ status: 'loading', family: undefined, error: undefined, invisibleCodepoints: EMPTY_CODEPOINTS });
    void loadReaderFont(family, resolvedUrl)
      .then((loadedFamily) => {
        if (!cancelled) {
          setState({
            status: 'loaded',
            family: loadedFamily,
            error: undefined,
            invisibleCodepoints: invisibleCodepointsForReaderFont(loadedFamily),
          });
        }
      })
      .catch((error: unknown) => {
        if (!cancelled) {
          setState({
            status: 'error',
            family: undefined,
            error: error instanceof Error ? error.message : String(error),
            invisibleCodepoints: EMPTY_CODEPOINTS,
          });
        }
      });

    return () => {
      cancelled = true;
    };
  }, [attempt, fontUrl]);

  return { ...state, retry: () => setAttempt((value) => value + 1) };
}
