-- VS-025: club news / blog (RF-022, §16 Blog).

-- Active member (or admin) of a club; used by RLS of member content.
create function public.is_club_member(p_club_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.can_admin_club(p_club_id) or exists (
    select 1 from public.club_memberships
    where club_id = p_club_id and user_id = (select auth.uid()) and status = 'active'
  );
$$;

create table public.posts (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs (id) on delete cascade,
  title text not null check (char_length(trim(title)) between 3 and 140),
  body text not null check (char_length(trim(body)) between 1 and 20000),
  image_path text,
  status text not null default 'draft' check (status in ('draft', 'published', 'archived')),
  published_at timestamptz,
  author_id uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (status <> 'published' or published_at is not null)
);
create index posts_club_published_idx on public.posts (club_id, published_at desc);

alter table public.posts enable row level security;
-- Members see published posts once their date arrives (server time); the
-- admin sees everything of the club. Writes only through the RPCs.
create policy posts_select on public.posts for select to authenticated
using (
  public.can_admin_club(club_id)
  or (status = 'published' and published_at <= now() and public.is_club_member(club_id))
);

-- Admin: creates (p_post_id null) or edits a post. [p_publish] publishes it
-- at [p_published_at] (now when null; a future date schedules it); otherwise
-- it is saved as a draft.
create function public.save_post(
  p_post_id uuid,
  p_club_id uuid,
  p_title text,
  p_body text,
  p_image_path text,
  p_publish boolean,
  p_published_at timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid := p_post_id;
  v_status text := case when p_publish then 'published' else 'draft' end;
  v_published_at timestamptz := case when p_publish then coalesce(p_published_at, now()) else p_published_at end;
begin
  if not public.can_admin_club(p_club_id) then
    raise exception 'club admin required' using errcode = '42501';
  end if;
  if char_length(trim(coalesce(p_title, ''))) not between 3 and 140 then
    raise exception 'invalid title' using errcode = '22023';
  end if;
  if char_length(trim(coalesce(p_body, ''))) not between 1 and 20000 then
    raise exception 'invalid body' using errcode = '22023';
  end if;
  if p_image_path is not null and left(p_image_path, 37) <> p_club_id::text || '/' then
    raise exception 'invalid image' using errcode = '22023';
  end if;

  if v_id is null then
    insert into public.posts (club_id, title, body, image_path, status, published_at, author_id)
    values (p_club_id, trim(p_title), trim(p_body), p_image_path, v_status, v_published_at, (select auth.uid()))
    returning id into v_id;
  else
    update public.posts
    set title = trim(p_title), body = trim(p_body), image_path = p_image_path,
        status = v_status, published_at = v_published_at, updated_at = now()
    where id = v_id and club_id = p_club_id;
    if not found then
      raise exception 'post not found' using errcode = 'P0002';
    end if;
  end if;
  perform public.audit(p_club_id, case when p_publish then 'post_published' else 'post_saved' end,
    jsonb_build_object('post', v_id, 'title', trim(p_title), 'published_at', v_published_at));
  return v_id;
end;
$$;

-- Admin: archives (withdraws) or restores as draft.
create function public.set_post_status(p_post_id uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_post public.posts;
begin
  select * into v_post from public.posts where id = p_post_id;
  if not found then
    raise exception 'post not found' using errcode = 'P0002';
  end if;
  if not public.can_admin_club(v_post.club_id) then
    raise exception 'club admin required' using errcode = '42501';
  end if;
  if p_status not in ('draft', 'archived') then
    raise exception 'invalid status' using errcode = '22023';
  end if;
  update public.posts set status = p_status, updated_at = now() where id = p_post_id;
  perform public.audit(v_post.club_id, 'post_' || p_status, jsonb_build_object('post', p_post_id, 'title', v_post.title));
end;
$$;

-- Admin: every post of the club, newest first, with whether it is visible.
create function public.get_club_posts(p_club_id uuid)
returns table (
  id uuid,
  title text,
  body text,
  image_path text,
  status text,
  published_at timestamptz,
  visible boolean,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.can_admin_club(p_club_id) then
    raise exception 'club admin required' using errcode = '42501';
  end if;
  return query
  select p.id, p.title, p.body, p.image_path, p.status, p.published_at,
         (p.status = 'published' and p.published_at <= now()), p.updated_at
  from public.posts p
  where p.club_id = p_club_id
  order by coalesce(p.published_at, p.updated_at) desc;
end;
$$;

revoke execute on function public.is_club_member(uuid) from public, anon;
revoke execute on function public.save_post(uuid, uuid, text, text, text, boolean, timestamptz) from public, anon;
revoke execute on function public.set_post_status(uuid, text) from public, anon;
revoke execute on function public.get_club_posts(uuid) from public, anon;
grant execute on function public.is_club_member(uuid) to authenticated;
grant execute on function public.save_post(uuid, uuid, text, text, text, boolean, timestamptz) to authenticated;
grant execute on function public.set_post_status(uuid, text) to authenticated;
grant execute on function public.get_club_posts(uuid) to authenticated;

-- Post images: private; members of the club read (signed URLs), the admin
-- writes inside "<club_id>/".
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('post-images', 'post-images', false, 3145728, array['image/png', 'image/jpeg', 'image/webp'])
on conflict (id) do nothing;

create policy post_images_select on storage.objects for select to authenticated
using (bucket_id = 'post-images' and public.is_club_member(((storage.foldername(name))[1])::uuid));
create policy post_images_insert on storage.objects for insert to authenticated
with check (bucket_id = 'post-images' and public.can_admin_club(((storage.foldername(name))[1])::uuid));
create policy post_images_update on storage.objects for update to authenticated
using (bucket_id = 'post-images' and public.can_admin_club(((storage.foldername(name))[1])::uuid));
create policy post_images_delete on storage.objects for delete to authenticated
using (bucket_id = 'post-images' and public.can_admin_club(((storage.foldername(name))[1])::uuid));
