begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

insert into auth.users (id, email, aud, role) values
  ('b0260000-0000-0000-0000-000000000001', 'ana26@test.com', 'authenticated', 'authenticated'),
  ('b0260000-0000-0000-0000-000000000002', 'baja26@test.com', 'authenticated', 'authenticated'),
  ('b0260000-0000-0000-0000-000000000003', 'otro26@test.com', 'authenticated', 'authenticated');
insert into public.clubs (id, name, code) values
  ('d0260000-0000-0000-0000-000000000001', 'Veintiseis TEST', 'VEINTISEISTEST'),
  ('d0260000-0000-0000-0000-000000000002', 'Otro26 TEST', 'OTRO26TEST');
alter table public.club_memberships disable trigger club_memberships_join_active_season;
insert into public.club_memberships (user_id, club_id, member_number, status) values
  ('b0260000-0000-0000-0000-000000000001', 'd0260000-0000-0000-0000-000000000001', 2, 'active'),
  ('b0260000-0000-0000-0000-000000000002', 'd0260000-0000-0000-0000-000000000001', 3, 'inactive'),
  ('b0260000-0000-0000-0000-000000000003', 'd0260000-0000-0000-0000-000000000002', 1, 'active');
alter table public.club_memberships enable trigger club_memberships_join_active_season;
insert into public.posts (club_id, title, body, status, published_at) values
  ('d0260000-0000-0000-0000-000000000001', 'Primera', 'a', 'published', now() - interval '3 days'),
  ('d0260000-0000-0000-0000-000000000001', 'Tercera', 'c', 'published', now() - interval '1 hour'),
  ('d0260000-0000-0000-0000-000000000001', 'Segunda', 'b', 'published', now() - interval '2 days'),
  ('d0260000-0000-0000-0000-000000000001', 'Borrador', 'd', 'draft', null);

set local role authenticated;
set local request.jwt.claims = '{"sub":"b0260000-0000-0000-0000-000000000001","role":"authenticated"}';
select results_eq(
  $$select title from public.posts
    where club_id = 'd0260000-0000-0000-0000-000000000001' and status = 'published' and published_at <= now()
    order by published_at desc$$,
  $$values ('Tercera'::text), ('Segunda'::text), ('Primera'::text)$$,
  'Ana sees the 3 published posts, the newest first'
);
select is(
  (select count(*)::int from public.posts where club_id = 'd0260000-0000-0000-0000-000000000001' and title = 'Borrador'),
  0, 'drafts are not part of her home'
);

set local request.jwt.claims = '{"sub":"b0260000-0000-0000-0000-000000000002","role":"authenticated"}';
select is((select count(*)::int from public.posts), 0, 'a member who left the club reads nothing');

set local request.jwt.claims = '{"sub":"b0260000-0000-0000-0000-000000000003","role":"authenticated"}';
select is((select count(*)::int from public.posts), 0, 'members of another club read nothing');

reset role;
set local role anon;
select throws_ok(
  $$select count(*) from public.posts$$,
  '42501', null, 'without a session there is no access at all'
);
select is(
  (select count(*)::int from storage.objects where bucket_id = 'post-images'),
  0, 'nor to the post images'
);

select * from finish();
rollback;
