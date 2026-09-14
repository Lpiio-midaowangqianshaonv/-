-- 在执行 schema.sql 后执行本文件。bucket 为私有，必须通过登录与 RLS 才能读取。

insert into storage.buckets (id, name, public)
values ('property-media', 'property-media', false)
on conflict (id) do update set public = false;

-- 仅接受 teams/{team_uuid}/properties/{property_uuid}/{media_uuid} 这种路径。
create or replace function public.storage_team_id(object_name text)
returns uuid
language sql
immutable
set search_path = ''
as $$
  select case
    when object_name ~ '^teams/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/properties/'
      then split_part(object_name, '/', 2)::uuid
    else null
  end;
$$;

drop policy if exists "team members can read property media" on storage.objects;
create policy "team members can read property media"
on storage.objects for select to authenticated
using (
  bucket_id = 'property-media'
  and public.is_team_member(public.storage_team_id(name))
);

drop policy if exists "team members can upload property media" on storage.objects;
create policy "team members can upload property media"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'property-media'
  and public.is_team_member(public.storage_team_id(name))
);

drop policy if exists "team members can update property media" on storage.objects;
create policy "team members can update property media"
on storage.objects for update to authenticated
using (
  bucket_id = 'property-media'
  and public.is_team_member(public.storage_team_id(name))
)
with check (
  bucket_id = 'property-media'
  and public.is_team_member(public.storage_team_id(name))
);

drop policy if exists "team members can delete property media" on storage.objects;
create policy "team members can delete property media"
on storage.objects for delete to authenticated
using (
  bucket_id = 'property-media'
  and public.is_team_member(public.storage_team_id(name))
);
