import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import vm from 'node:vm';

test('the browser inline script has valid JavaScript syntax', async () => {
  const html = await readFile(new URL('../dist/index.html', import.meta.url), 'utf8');
  const scripts = [...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)]
    .map((match) => match[1])
    .filter((script) => script.trim());

  assert.equal(scripts.length, 1, 'expected one executable inline script');
  assert.doesNotThrow(() => new vm.Script(scripts[0]));
});
