import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

test('the app includes cloud listing, media, and deletion synchronization actions', async () => {
  const html = await readFile(new URL('../dist/index.html', import.meta.url), 'utf8');

  assert.match(html, /async function syncProperty\(/);
  assert.match(html, /async function loadTeamProperties\(/);
  assert.match(html, /async function deleteTeamProperty\(/);
  assert.match(html, /\.channel\('team-properties-'/);
});
