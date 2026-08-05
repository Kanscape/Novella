import assert from 'node:assert/strict';
import test from 'node:test';

import { buildChapterXhtml } from './reader-xhtml-builder.ts';

test('reader image previews open on tap when long-press mode is disabled', () => {
  const html = buildChapterXhtml('<p><img src="image.png" /></p>', {
    imagePreviewEnabled: true,
    imagePreviewOpenOnLongPress: false,
  });

  assert.match(html, /initImagePreview\(false\)/);
  assert.match(html, /document\.addEventListener\('click'/);
  assert.match(html, /alt: image\.getAttribute\('alt'\)/);
});

test('reader image previews open on long press when configured', () => {
  const html = buildChapterXhtml('<p><img src="image.png" /></p>', {
    imagePreviewEnabled: true,
    imagePreviewOpenOnLongPress: true,
  });

  assert.match(html, /initImagePreview\(true\)/);
  assert.match(html, /document\.addEventListener\('touchstart'/);
});

test('images explicitly marked no-preview are ignored by the gesture handler', () => {
  const html = buildChapterXhtml('<p><img class="no-preview" src="image.png" /></p>', {
    imagePreviewEnabled: true,
    imagePreviewOpenOnLongPress: false,
  });

  assert.match(html, /classList\.contains\('no-preview'\)/);
});

test('image preview can remain disabled', () => {
  const html = buildChapterXhtml('<p><img src="image.png" /></p>', {
    imagePreviewEnabled: false,
  });

  assert.match(html, /\/\/ image preview disabled/);
  assert.doesNotMatch(html, /initImagePreview\((?:true|false)\)/);
});
