import { test } from 'node:test';
import assert from 'node:assert/strict';

import { simplifyReaderChapterTitle } from './chapter-title.ts';

test('simplifies bracket-prefixed chapter titles', () => {
  assert.equal(simplifyReaderChapterTitle('【第五章 觉醒】'), '第五章 觉醒');
  assert.equal(simplifyReaderChapterTitle('【序章】开始的新生活'), '序章');
  assert.equal(simplifyReaderChapterTitle('  【第一话】 登场 '), '第一话');
});

test('simplifies prefix-before-space / quote titles', () => {
  assert.equal(simplifyReaderChapterTitle('第5章 觉醒'), '第5章');
  assert.equal(simplifyReaderChapterTitle('第一章『觉醒』'), '第一章');
  assert.equal(simplifyReaderChapterTitle('第一卷 起始之日'), '第一卷');
  assert.equal(simplifyReaderChapterTitle('第３話「再会」'), '第３話');
});

test('keeps Latin-prefixed and plain titles unchanged', () => {
  assert.equal(simplifyReaderChapterTitle('Chapter 5 The Awakening'), 'Chapter 5 The Awakening');
  assert.equal(simplifyReaderChapterTitle('The Awakening'), 'The Awakening');
  assert.equal(simplifyReaderChapterTitle('觉醒'), '觉醒');
  assert.equal(simplifyReaderChapterTitle(''), '');
  assert.equal(simplifyReaderChapterTitle('   '), '');
});
