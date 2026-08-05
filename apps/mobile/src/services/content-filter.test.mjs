import assert from 'node:assert/strict';
import test from 'node:test';

import { filterBooksByContentSettings } from './content-filter.ts';

const book = (id, { category = null, level = 1 } = {}) => ({
  category,
  coverPlaceholder: null,
  coverUrl: `https://example.com/${id}.jpg`,
  id,
  interiorLevel: null,
  lastUpdatedAt: '2026-01-01T00:00:00.000Z',
  level,
  seriesTitle: null,
  title: `Book ${id}`,
  type: 'Novel',
  authorName: null,
});

test('content filter matches Flutter Level 6 and category rules', () => {
  const items = [
    book(1),
    book(2, { level: 6 }),
    book(3, { category: { color: '', name: '日文原版', shortName: '' } }),
    book(4, { category: { color: '', name: 'Other', shortName: 'AI' } }),
    book(5, { category: { color: '', name: 'Other', shortName: 'Other' } }),
  ];

  assert.deepEqual(
    filterBooksByContentSettings(items, {
      ignoreAI: true,
      ignoreJapanese: true,
      ignoreLevel6: true,
    }).map(({ id }) => id),
    [1, 5],
  );
});

test('content filter preserves items without a category', () => {
  const items = [book(1), book(2, { category: null, level: 6 })];

  assert.deepEqual(
    filterBooksByContentSettings(items, {
      ignoreAI: false,
      ignoreJapanese: false,
      ignoreLevel6: false,
    }),
    items,
  );
});
