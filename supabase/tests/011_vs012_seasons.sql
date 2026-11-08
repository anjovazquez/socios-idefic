begin;
create extension if not exists pgtap with schema extensions;
select plan(15);

insert into auth.users (id, email, aud, role) values
  ('b3000000-0000-0000-0000-000000000001', 'admin12@test.com', 'authenticated', 'authenticated'),
  ('b3000000-0000-0000-0000-000000000002', 'socio12@test.com', 'authenticated', 'authenticated'),
  ('b3000000-0000-0000-0000-000000000003', 'ajeno12@test.com', 'authenticated', 'authenticated');
insert into public.clubs (id, name, code) values
  ('d3000000-0000-0000-0000-000000000001', 'Doce TEST', 'DOCETEST'),
  ('d3000000-0000-0000-0000-000000000002', 'Ajeno TEST', 'AJENO12TEST');
insert into public.club_memberships (user_id, club_id, role, member_number) values
  ('b3000000-0000-0000-0000-000000000001', 'd3000000-0000-0000-0000-000000000001', 'club_admin', 1),
  ('b3000000-0000-0000-0000-000000000002', 'd3000000-0000-0000-0000-000000000001', 'member', 2),
  ('b3000000-0000-0000-0000-000000000003', 'd3000000-0000-0000-0000-000000000002', 'member', 1);

set local role authenticated;
set local request.jwt.claims = '{"sub":"b3000000-0000-0000-0000-000000000001","role":"authenticated"}';

select lives_ok(
  $$select public.create_season('d3000000-0000-0000-0000-000000000001', '2026/2027')$$,
  'the admin creates 2026/2027'
);
select results_eq(
  $$select status, starts_on, ends_on from public.seasons where name = '2026/2027'$$,
  $$values ('draft'::text, '2026-09-01'::date, '2027-08-31'::date)$$,
  'new seasons start as draft from 1 September to 31 August'
);
select throws_ok(
  $$select public.activate_season((select id from public.seasons where name = '2026/2027'), null)$$,
  '22023', null, 'the fee is required to activate'
);
select lives_ok(
  $$select public.activate_season((select id from public.seasons where name = '2026/2027'), 5000)$$,
  'activate 2026/2027 at 50 €'
);
select lives_ok(
  $$select public.create_season('d3000000-0000-0000-0000-000000000001', '2027/2028')$$,
  'create 2027/2028'
);
select lives_ok(
  $$select public.activate_season((select id from public.seasons where name = '2027/2028'), 5500)$$,
  'activate 2027/2028 at 55 €'
);
select results_eq(
  $$select name, status, default_fee_cents from public.seasons order by name$$,
  $$values ('2026/2027'::text, 'closed'::text, 5000), ('2027/2028'::text, 'active'::text, 5500)$$,
  'only the new season is active; the previous one is closed with its fee'
);
select throws_ok(
  $$select public.activate_season((select id from public.seasons where name = '2026/2027'), 5000)$$,
  'P0001', null, 'a closed season cannot be activated again'
);
select lives_ok(
  $$select public.activate_season((select id from public.seasons where name = '2027/2028'), 6000)$$,
  'activating the active season updates its fee'
);
select throws_ok(
  $$select public.create_season('d3000000-0000-0000-0000-000000000001', '2027/2028')$$,
  '23505', null, 'duplicate season names are rejected'
);
select throws_ok(
  $$select public.create_season('d3000000-0000-0000-0000-000000000001', '2027/2029')$$,
  '22023', null, 'names must be consecutive years'
);

reset role;
select throws_ok(
  $$insert into public.seasons (club_id, name, starts_on, ends_on, default_fee_cents, status)
    values ('d3000000-0000-0000-0000-000000000001', '2030/2031', '2030-09-01', '2031-08-31', 1, 'active')$$,
  '23505', null, 'the database never allows two active seasons in a club'
);

-- Member of the club
set local role authenticated;
set local request.jwt.claims = '{"sub":"b3000000-0000-0000-0000-000000000002","role":"authenticated"}';
select results_eq(
  $$select active_season_name from public.get_my_clubs()$$,
  array['2027/2028'],
  'members see the active season of their club'
);
select throws_ok(
  $$select public.create_season('d3000000-0000-0000-0000-000000000001', '2028/2029')$$,
  '42501', null, 'members cannot create seasons'
);

-- Member of another club
set local request.jwt.claims = '{"sub":"b3000000-0000-0000-0000-000000000003","role":"authenticated"}';
select is_empty(
  $$select 1 from public.seasons where club_id = 'd3000000-0000-0000-0000-000000000001'$$,
  'seasons of other clubs are not visible'
);

select * from finish();
rollback;
