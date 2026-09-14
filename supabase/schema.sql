-- 房源团队协作：在 Supabase SQL Editor 中执行本文件。
-- 此脚本只使用 Auth 用户 ID 与公开 anon key；绝不需要任何管理员密钥。

create extension if not exists pgcrypto;

create table if not exists public.teams (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 1 and 80),
  owner_id uuid not null references auth.users(id) on delete cascade,
  invite_code text not null unique default encode(gen_random_bytes(18), 'hex'),
  created_at timestamptz not null default now(),
  invite_rotated_at timestamptz not null default now()
);

create table if not exists public.team_members (
  team_id uuid not null references public.teams(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (team_id, user_id)
);

create table if not exists public.properties (
  id uuid primary key,
  team_id uuid not null references public.teams(id) on delete cascade,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists properties_team_updated_idx
  on public.properties (team_id, updated_at desc);

create or replace function public.is_team_member(target_team_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid() is not null and exists (
    select 1 from public.team_members
    where team_id = target_team_id and user_id = auth.uid()
  );
$$;

create or replace function public.set_property_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists properties_updated_at on public.properties;
create trigger properties_updated_at
before update on public.properties
for each row execute function public.set_property_updated_at();

-- 创建者通过 RPC 建立团队，同时成为第一位成员。
create or replace function public.create_team(team_name text)
returns public.teams
language plpgsql
security definer
set search_path = public
as $$
declare
  new_team public.teams;
begin
  if auth.uid() is null then
    raise exception '请先登录后再创建团队';
  end if;
  insert into public.teams (name, owner_id)
  values (trim(team_name), auth.uid())
  returning * into new_team;
  insert into public.team_members (team_id, user_id)
  values (new_team.id, auth.uid());
  return new_team;
end;
$$;

-- 邀请码本身不授予权限：调用者必须先通过 Supabase Auth 登录。
create or replace function public.join_team_by_code(code text)
returns public.teams
language plpgsql
security definer
set search_path = public
as $$
declare
  joined_team public.teams;
begin
  if auth.uid() is null then
    raise exception '请先登录后再加入团队';
  end if;
  select * into joined_team from public.teams where invite_code = trim(code);
  if joined_team.id is null then
    raise exception '邀请链接无效或已失效';
  end if;
  insert into public.team_members (team_id, user_id)
  values (joined_team.id, auth.uid())
  on conflict (team_id, user_id) do nothing;
  return joined_team;
end;
$$;

-- 仅团队创建者可重新生成链接；已加入成员不会被移除。
create or replace function public.rotate_invite_code(target_team_id uuid)
returns public.teams
language plpgsql
security definer
set search_path = public
as $$
declare
  changed_team public.teams;
begin
  update public.teams
  set invite_code = encode(gen_random_bytes(18), 'hex'), invite_rotated_at = now()
  where id = target_team_id and owner_id = auth.uid()
  returning * into changed_team;
  if changed_team.id is null then
    raise exception '只有团队创建者可以重新生成邀请链接';
  end if;
  return changed_team;
end;
$$;

alter table public.teams enable row level security;
alter table public.team_members enable row level security;
alter table public.properties enable row level security;

drop policy if exists "team members can view their team" on public.teams;
create policy "team members can view their team"
on public.teams for select to authenticated
using (public.is_team_member(id));

drop policy if exists "team members can view memberships" on public.team_members;
create policy "team members can view memberships"
on public.team_members for select to authenticated
using (public.is_team_member(team_id));

drop policy if exists "team members can view properties" on public.properties;
create policy "team members can view properties"
on public.properties for select to authenticated
using (public.is_team_member(team_id));

drop policy if exists "team members can add properties" on public.properties;
create policy "team members can add properties"
on public.properties for insert to authenticated
with check (public.is_team_member(team_id));

drop policy if exists "team members can update properties" on public.properties;
create policy "team members can update properties"
on public.properties for update to authenticated
using (public.is_team_member(team_id))
with check (public.is_team_member(team_id));

drop policy if exists "team members can delete properties" on public.properties;
create policy "team members can delete properties"
on public.properties for delete to authenticated
using (public.is_team_member(team_id));

-- 允许前端通过 Realtime 订阅已保护的房源变更。
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'properties'
  ) then
    alter publication supabase_realtime add table public.properties;
  end if;
end;
$$;

grant execute on function public.create_team(text) to authenticated;
grant execute on function public.join_team_by_code(text) to authenticated;
grant execute on function public.rotate_invite_code(uuid) to authenticated;
