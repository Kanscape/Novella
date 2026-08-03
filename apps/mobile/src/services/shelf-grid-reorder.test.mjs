import assert from 'node:assert/strict';
import test from 'node:test';

import {
  moveShelfGridItem,
  resolveShelfGridTargetIndex,
} from './shelf-grid-reorder.ts';

test('shelf grid resolves three-column drag targets and clamps partial rows', () => {
  assert.equal(resolveShelfGridTargetIndex({
    itemCount: 8,
    localX: 5,
    localY: 5,
    tileWidth: 100,
  }), 0);
  assert.equal(resolveShelfGridTargetIndex({
    itemCount: 8,
    localX: 230,
    localY: 200,
    tileWidth: 100,
  }), 5);
  assert.equal(resolveShelfGridTargetIndex({
    itemCount: 8,
    localX: 999,
    localY: 999,
    tileWidth: 100,
  }), 7);
});

test('shelf grid reorder moves one sibling without losing any keys', () => {
  assert.deepEqual(moveShelfGridItem(['a', 'b', 'c', 'd'], 1, 3), ['a', 'c', 'd', 'b']);
  assert.deepEqual(moveShelfGridItem(['a', 'b', 'c', 'd'], 3, 0), ['d', 'a', 'b', 'c']);
});
