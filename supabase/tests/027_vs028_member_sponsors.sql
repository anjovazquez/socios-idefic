begin;
create extension if not exists pgtap with schema extensions;
select plan(5);

insert into auth.users (id, email, aud, role) values
  ('b0280000-0000-0000-0000-000000000002', 'ana28@test.com', 'authenticated', 'authenticated'),
  ('b0280000-0000-0000-0000-000000000003', 'otro28@test.com', 'authenticated', 'authenticated');
insert into public.clubs (id, name, code) values
  ('d0280000-0000-0000-0000-000000000001', 'Veintiocho TEST', 'VEINTIOCHOTEST'),
  ('d0280000-0000-0000-0000-000000000002', 'Otro28 TEST', 'OTRO28TEST');
insert into public.seasons (id, club_id, name, starts_on, ends_on, default_fee_cents, status) values
  ('a0280000-0000-0000-0000-000000000025', 'd0280000-0000-0000-0000-000000000001', '2025/2026', '2025-09-01', '2026-08-31', 4500, 'closed'),
  ('a0280000-0000-0000-0000-000000000026', 'd0280000-0000-0000-0000-000000000001', '2026/2027', '2026-09-01', '2027-08-31', 5000, 'active');
alter table public.club_memberships disable trigger club_memberships_join_active_season;
insert into public.club_memberships (user_id, club_id, member_number) values
  ('b0280000-0000-0000-0000-000000000002', 'd0280000-0000-0000-0000-000000000001', 2),
  ('b0280000-0000-0000-0000-000000000003', 'd0280000-0000-0000-0000-000000000002', 1);
alter table public.club_memberships enable trigger club_memberships_join_active_season;
insert into public.sponsors (id, club_id, name, website_url, is_active) values
  ('50280000-0000-0000-0000-000000000001', 'd0280000-0000-0000-0000-000000000001', 'Restaurante X', 'https://restaurantex.es', true),
  ('50280000-0000-0000-0000-000000000002', 'd0280000-0000-0000-0000-000000000001', 'Antiguo', null, true),
  ('50280000-0000-0000-0000-000000000003', 'd0280000-0000-0000-0000-000000000001', 'Desactivado', null, false);
insert into public.sponsor_seasons (sponsor_id, season_id) values
  ('50280000-0000-0000-0000-000000000001', 'a0280000-0000-0000-0000-000000000026'),
  ('50280000-0000-0000-0000-000000000002', 'a0280000-0000-0000-0000-000000000025'),
  ('50280000-0000-0000-0000-000000000003', 'a0280000-0000-0000-0000-000000000026');

set local role authenticated;
set local request.jwt.claims = '{"sub":"b0280000-0000-0000-0000-000000000002","role":"authenticated"}';
select results_eq(
  $$select name, website_url from public.get_club_active_sponsors('d0280000-0000-0000-0000-000000000001')$$,
  $$values ('Restaurante X'::text, 'https://restaurantex.es'::text)$$,
  'Ana sees only active sponsors of the active season, with their web'
);
select is((select count(*)::int from public.sponsors), 0, 'members still cannot read the admin table');

set local request.jwt.claims = '{"sub":"b0280000-0000-0000-0000-000000000003","role":"authenticated"}';
select throws_ok(
  $$select * from public.get_club_active_sponsors('d0280000-0000-0000-0000-000000000001')$$,
  '42501', null, 'members of another club get nothing'
);

reset role;
update public.seasons set status = 'closed' where id = 'a0280000-0000-0000-0000-000000000026';
set local role authenticated;
set local request.jwt.claims = '{"sub":"b0280000-0000-0000-0000-000000000002","role":"authenticated"}';
select is(
  (select count(*)::int from public.get_club_active_sponsors('d0280000-0000-0000-0000-000000000001')),
  0, 'without an active season there are no sponsors to show'
);

reset role;
set local role anon;
select throws_ok(
  $$select * from public.get_club_active_sponsors('d0280000-0000-0000-0000-000000000001')$$,
  '42501', null, 'anonymous users get nothing'
);

select * from finish();
rollback;
