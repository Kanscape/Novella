import assert from 'node:assert/strict';
import test from 'node:test';

import {
  resolveReaderImageFormat,
} from './reader-image-format.ts';

test('content type takes precedence over a misleading URL extension', () => {
  assert.deepEqual(
    resolveReaderImageFormat('https://example.com/image.jpg?token=1', 'image/png; charset=binary'),
    { extension: '.png', mimeType: 'image/png', uti: 'public.png' },
  );
});

test('supported URL extensions are read before query parameters', () => {
  assert.deepEqual(
    resolveReaderImageFormat('https://example.com/image.webp?download=1'),
    { extension: '.webp', mimeType: 'image/webp', uti: 'org.webmproject.webp' },
  );
});

test('unknown image formats fall back to JPEG', () => {
  assert.deepEqual(
    resolveReaderImageFormat('https://example.com/image.avif'),
    { extension: '.jpg', mimeType: 'image/jpeg', uti: 'public.jpeg' },
  );
  assert.deepEqual(
    resolveReaderImageFormat('https://example.com/image'),
    { extension: '.jpg', mimeType: 'image/jpeg', uti: 'public.jpeg' },
  );
});
