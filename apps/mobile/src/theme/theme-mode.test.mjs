import assert from 'node:assert/strict';
import test from 'node:test';

import { resolveAppColorScheme, resolveReaderColors } from './theme-mode.ts';

test('fixed app appearances override the system appearance', () => {
  assert.equal(resolveAppColorScheme('light', 'dark'), 'light');
  assert.equal(resolveAppColorScheme('dark', 'light'), 'dark');
});

test('system appearance follows the current system scheme', () => {
  assert.equal(resolveAppColorScheme('system', 'dark'), 'dark');
  assert.equal(resolveAppColorScheme('system', 'light'), 'light');
  assert.equal(resolveAppColorScheme('system', 'unspecified'), 'light');
});

test('OLED black applies only to the dark reader', () => {
  assert.deepEqual(
    resolveReaderColors({
      backgroundColor: '#FAFAFA',
      colorScheme: 'light',
      oledBlack: true,
      textColor: '#101010',
    }),
    { backgroundColor: '#FAFAFA', textColor: '#101010' },
  );
  assert.deepEqual(
    resolveReaderColors({
      backgroundColor: '#202020',
      colorScheme: 'dark',
      oledBlack: true,
      textColor: '#EFEFEF',
    }),
    { backgroundColor: '#000000', textColor: '#FFFFFF' },
  );
});

test('dark reader without OLED black keeps the regular dark page', () => {
  assert.deepEqual(
    resolveReaderColors({
      backgroundColor: '#1C1C1E',
      colorScheme: 'dark',
      oledBlack: false,
      textColor: '#FFFFFF',
    }),
    { backgroundColor: '#1C1C1E', textColor: '#FFFFFF' },
  );
});
