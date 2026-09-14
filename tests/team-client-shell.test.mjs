import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

test('the app exposes the email login and invitation actions required for team sharing', async () => {
  const html = await readFile(new URL('../dist/index.html', import.meta.url), 'utf8');

  assert.match(html, /@supabase\/supabase-js@2/);
  assert.match(html, /async function signInWithEmail\(/);
  assert.match(html, /async function createTeam\(/);
  assert.match(html, /async function joinTeamFromInvite\(/);
  assert.match(html, /async function rotateInvite\(/);
});
