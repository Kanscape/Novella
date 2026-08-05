import assert from 'node:assert/strict';
import test from 'node:test';

import {
  addSearchHistoryItem,
  mergeSearchHistory,
  normalizeSearchHistory,
  SEARCH_HISTORY_LIMIT,
} from './search-history-utils.ts';

test('search history puts the latest query first without duplicates', () => {
  assert.deepEqual(
    addSearchHistoryItem(['older', 'same'], '  same  '),
    ['same', 'older'],
  );
  assert.deepEqual(
    mergeSearchHistory([' first ', 'shared'], ['shared', 'second']),
    ['first', 'shared', 'second'],
  );
});

test('search history trims, drops blanks, and keeps its limit', () => {
  const values = Array.from({ length: SEARCH_HISTORY_LIMIT + 2 }, (_, index) => `item-${index}`);
  assert.equal(normalizeSearchHistory(['  ', ...values, 'item-0']).length, SEARCH_HISTORY_LIMIT);
  assert.deepEqual(normalizeSearchHistory(['  first  ', '', 'first', 'second']), ['first', 'second']);
});
