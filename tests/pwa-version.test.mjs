import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

test('the team collaboration release invalidates the old application shell cache', async () => {
  const [html, serviceWorker] = await Promise.all([
    readFile(new URL('../dist/index.html', import.meta.url), 'utf8'),
    readFile(new URL('../dist/sw.js', import.meta.url), 'utf8')
  ]);

  assert.match(html, /window\.__APP_VERSION__ = '1\.1\.0'/);
  assert.match(serviceWorker, /property-record-shell-v1\.1\.0/);
});
