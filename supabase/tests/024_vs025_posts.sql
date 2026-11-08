begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

insert into auth.users (id, email, aud, role) values
  ('b0250000-0000-0000-0000-000000000001', 'admin25@test.com', 'authenticated', 'authenticated'),
  ('b0250000-0000-0000-0000-000000000002', 'marta25@test.com', 'authenticated', 'authenticated'),
  ('b0250000-0000-0000-0000-000000000003', 'otro25@test.com', 'authenticated', 'authenticated');
insert into public.clubs (id, name, code) values
  ('d0250000-0000-0000-0000-000000000001', 'Veinticinco TEST', 'VEINTICINCOTEST'),
  ('d0250000-0000-0000-0000-000000000002', 'Otro25 TEST', 'OTRO25TEST');
alter table public.club_memberships disable trigger club_memberships_join_active_season;
insert into public.club_memberships (user_id, club_id, member_number, role) values
  ('b0250000-0000-0000-0000-000000000001', 'd0250000-0000-0000-0000-000000000001', 1, 'club_admin'),
  ('b0250000-0000-0000-0000-000000000002', 'd0250000-0000-0000-0000-000000000001', 2, 'member'),
  ('b0250000-0000-0000-0000-000000000003', 'd0250000-0000-0000-0000-000000000002', 1, 'member');
alter table public.club_memberships enable trigger club_memberships_join_active_season;

set local role authenticated;
set local request.jwt.claims = '{"sub":"b0250000-0000-0000-0000-000000000001","role":"authenticated"}';
create temporary table t_posts (name text, id uuid);
grant all on t_posts to authenticated;
insert into t_posts values
  ('asamblea', public.save_post(null, 'd0250000-0000-0000-0000-000000000001', 'Asamblea de socios',
     'El viernes a las 20:00 en el pabellón.', 'd0250000-0000-0000-0000-000000000001/asamblea.jpg', true)),
  ('borrador', public.save_post(null, 'd0250000-0000-0000-0000-000000000001', 'Cena de Navidad', 'Pendiente de fecha.', null, false)),
  ('manana', public.save_post(null, 'd0250000-0000-0000-0000-000000000001', 'Nueva equipación',
     'La presentamos mañana.', null, true, now() + interval '1 day'));

select results_eq(
  $$select title, status, published_at::date, visible from public.get_club_posts('d0250000-0000-0000-0000-000000000001')
    where title = 'Asamblea de socios'$$,
  $$values ('Asamblea de socios'::text, 'published'::text, now()::date, true)$$,
  'a published post appears published with today''s date'
);
select is((select count(*)::int from public.posts), 3, 'the admin sees all the club posts');
select is(
  (select visible from public.get_club_posts('d0250000-0000-0000-0000-000000000001') where title = 'Nueva equipación'),
  false, 'a scheduled post is not visible yet'
);

set local request.jwt.claims = '{"sub":"b0250000-0000-0000-0000-000000000002","role":"authenticated"}';
select results_eq(
  $$select title from public.posts order by title$$,
  $$values ('Asamblea de socios'::text)$$,
  'members only see published posts whose date arrived (no drafts, no scheduled)'
);
select throws_ok(
  $$select public.save_post(null, 'd0250000-0000-0000-0000-000000000001', 'Hack', 'x', null, true)$$,
  '42501', null, 'members cannot publish'
);
select throws_ok(
  $$select * from public.get_club_posts('d0250000-0000-0000-0000-000000000001')$$,
  '42501', null, 'members cannot list drafts'
);
select is(
  (select count(*)::int from storage.objects where bucket_id = 'post-images'),
  0, 'storage policies apply (no objects yet)'
);
select ok(public.is_club_member('d0250000-0000-0000-0000-000000000001'), 'Marta is a member of the club');

set local request.jwt.claims = '{"sub":"b0250000-0000-0000-0000-000000000003","role":"authenticated"}';
select is((select count(*)::int from public.posts), 0, 'members of other clubs see nothing');
select ok(not public.is_club_member('d0250000-0000-0000-0000-000000000001'), 'nor read its post images');

-- Scheduled post: visible once its date arrives (simulated).
reset role;
update public.posts set published_at = now() - interval '1 minute' where title = 'Nueva equipación';
set local role authenticated;
set local request.jwt.claims = '{"sub":"b0250000-0000-0000-0000-000000000002","role":"authenticated"}';
select is((select count(*)::int from public.posts), 2, 'the scheduled post appears when its date arrives');

-- Archive (withdraw) and validations.
set local request.jwt.claims = '{"sub":"b0250000-0000-0000-0000-000000000001","role":"authenticated"}';
select lives_ok(
  $$select public.set_post_status((select id from t_posts where name = 'asamblea'), 'archived')$$,
  'the admin archives a post'
);
set local request.jwt.claims = '{"sub":"b0250000-0000-0000-0000-000000000002","role":"authenticated"}';
select is((select count(*)::int from public.posts where title = 'Asamblea de socios'), 0, 'archived posts disappear for members');
set local request.jwt.claims = '{"sub":"b0250000-0000-0000-0000-000000000001","role":"authenticated"}';
select throws_ok(
  $$select public.save_post(null, 'd0250000-0000-0000-0000-000000000001', 'No', 'x', null, false)$$,
  '22023', null, 'a title needs at least 3 characters'
);
select throws_ok(
  $$select public.save_post(null, 'd0250000-0000-0000-0000-000000000001', 'Imagen ajena', 'x',
      'd0250000-0000-0000-0000-000000000002/x.jpg', false)$$,
  '22023', null, 'images must be inside the club folder'
);
reset role;
select is(
  (select count(*)::int from public.audit_log where action in ('post_published', 'post_saved', 'post_archived')
     and club_id = 'd0250000-0000-0000-0000-000000000001'),
  4, 'post changes are audited'
);

select * from finish();
rollback;
