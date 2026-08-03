import { useEffect, useState } from 'react';

import type { BookListItem } from '@novella/api-client';

import { discovery } from '@/services/client';

export type AuthCoverMosaicState =
  | { status: 'loading'; books: [] }
  | { status: 'ready'; books: BookListItem[] }
  | { status: 'error'; books: [] };

export function useAuthCoverMosaic(): AuthCoverMosaicState {
  const [state, setState] = useState<AuthCoverMosaicState>({
    status: 'loading',
    books: [],
  });

  useEffect(() => {
    let active = true;
    void discovery.loadLatestBooks().then(
      (page) => {
        if (active) setState({ status: 'ready', books: page.items.slice(0, 6) });
      },
      () => {
        if (active) setState({ status: 'error', books: [] });
      },
    );
    return () => {
      active = false;
    };
  }, []);

  return state;
}
