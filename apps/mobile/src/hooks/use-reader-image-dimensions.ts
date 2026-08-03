import { useEffect, useMemo, useState } from 'react';

import {
  extractReaderImageSources,
  getKnownReaderImageDimensions,
  hydrateReaderImageDimensions,
  type ReaderImageDimensions,
} from '@/services/reader-image-dimensions';

/**
 * Hydrates geometry metadata only. Image pixels are loaded by visible
 * `expo-image` instances and never gate paged chapter display.
 */
export function useReaderImageDimensions(html: string) {
  const sources = useMemo(() => extractReaderImageSources(html), [html]);
  const immediateDimensions = useMemo(() => getKnownReaderImageDimensions(html), [html]);
  const [state, setState] = useState<{
    dimensions: Record<string, ReaderImageDimensions>;
    html: string;
    ready: boolean;
  }>({ dimensions: {}, html: '', ready: false });

  useEffect(() => {
    let cancelled = false;
    if (sources.length === 0) {
      setState({ dimensions: {}, html, ready: true });
      return () => {
        cancelled = true;
      };
    }

    setState({ dimensions: immediateDimensions, html, ready: false });
    void hydrateReaderImageDimensions().then(() => {
      if (cancelled) return;
      setState({
        dimensions: getKnownReaderImageDimensions(html),
        html,
        ready: true,
      });
    });
    return () => {
      cancelled = true;
    };
  }, [html, immediateDimensions, sources.length]);

  return {
    dimensions: state.html === html ? state.dimensions : immediateDimensions,
    hasImages: sources.length > 0,
    isReady: state.html === html && state.ready,
    total: sources.length,
  };
}
