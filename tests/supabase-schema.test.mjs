import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

test('team collaboration schema protects all three tables with RLS', async () => {
  const schema = await readFile(new URL('../supabase/schema.sql', import.meta.url), 'utf8');

  for (const table of ['teams', 'team_members', 'properties']) {
    assert.match(schema, new RegExp(`create table(?: if not exists)? public\\.${table}`, 'i'));
    assert.match(schema, new RegExp(`alter table public\\.${table} enable row level security`, 'i'));
  }
  assert.match(schema, /create or replace function public\.join_team_by_code/i);
  assert.match(schema, /create or replace function public\.rotate_invite_code/i);
});

test('storage policies restrict the private property-media bucket to team members', async () => {
  const policies = await readFile(new URL('../supabase/storage-policies.sql', import.meta.url), 'utf8');

  assert.match(policies, /insert into storage\.buckets/i);
  assert.match(policies, /property-media/);
  assert.match(policies, /public\.is_team_member/i);
});
