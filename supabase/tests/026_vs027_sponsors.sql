begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

insert into auth.users (id, email, aud, role) values
  ('b0270000-0000-0000-0000-000000000001', 'admin27@test.com', 'authenticated', 'authenticated'),
  ('b0270000-0000-0000-0000-000000000002', 'ana27@test.com', 'authenticated', 'authenticated'),
  ('b0270000-0000-0000-0000-000000000003', 'otroadmin27@test.com', 'authenticated', 'authenticated');
insert into public.clubs (id, name, code) values
  ('d0270000-0000-0000-0000-000000000001', 'Veintisiete TEST', 'VEINTISIETETEST'),
  ('d0270000-0000-0000-0000-000000000002', 'Otro27 TEST', 'OTRO27TEST');
insert into public.seasons (id, club_id, name, starts_on, ends_on, default_fee_cents, status) values
  ('a0270000-0000-0000-0000-000000000026', 'd0270000-0000-0000-0000-000000000001', '2026/2027', '2026-09-01', '2027-08-31', 5000, 'active'),
  ('a0270000-0000-0000-0000-000000000027', 'd0270000-0000-0000-0000-000000000001', '2027/2028', '2027-09-01', '2028-08-31', 5000, 'draft'),
  ('a0270000-0000-0000-0000-000000000099', 'd0270000-0000-0000-0000-000000000002', '2026/2027', '2026-09-01', '2027-08-31', 3000, 'active');
alter table public.club_memberships disable trigger club_memberships_join_active_season;
insert into public.club_memberships (user_id, club_id, member_number, role) values
  ('b0270000-0000-0000-0000-000000000001', 'd0270000-0000-0000-0000-000000000001', 1, 'club_admin'),
  ('b0270000-0000-0000-0000-000000000002', 'd0270000-0000-0000-0000-000000000001', 2, 'member'),
  ('b0270000-0000-0000-0000-000000000003', 'd0270000-0000-0000-0000-000000000002', 1, 'club_admin');
alter table public.club_memberships enable trigger club_memberships_join_active_season;

set local role authenticated;
set local request.jwt.claims = '{"sub":"b0270000-0000-0000-0000-000000000001","role":"authenticated"}';
create temporary table t_sp (id uuid);
grant all on t_sp to authenticated;
insert into t_sp select public.save_sponsor(null, 'd0270000-0000-0000-0000-000000000001', 'Restaurante X',
  'd0270000-0000-0000-0000-000000000001/sponsor-x.png', 'https://restaurantex.es');
select lives_ok(
  $$select public.set_sponsor_seasons((select id from t_sp), array['a0270000-0000-0000-0000-000000000026'::uuid])$$,
  'the admin associates it with 2026/2027'
);
select results_eq(
  $$select name, website_url, is_active, season_names from public.get_club_sponsors('d0270000-0000-0000-0000-000000000001')$$,
  $$values ('Restaurante X'::text, 'https://restaurantex.es'::text, true, array['2026/2027'])$$,
  'it appears as sponsor of 2026/2027'
);
select is(
  (select count(*)::int from public.sponsor_seasons where season_id = 'a0270000-0000-0000-0000-000000000027'),
  0, 'it is not a sponsor of 2027/2028 until renewed'
);

-- Activating the next season does not carry sponsors over.
reset role;
update public.seasons set status = 'closed' where id = 'a0270000-0000-0000-0000-000000000026';
update public.seasons set status = 'active' where id = 'a0270000-0000-0000-0000-000000000027';
select is(
  (select count(*)::int from public.sponsor_seasons where season_id = 'a0270000-0000-0000-0000-000000000027'),
  0, 'activating 2027/2028 does not renew sponsors'
);
set local role authenticated;
set local request.jwt.claims = '{"sub":"b0270000-0000-0000-0000-000000000001","role":"authenticated"}';
select is(
  public.renew_sponsors('a0270000-0000-0000-0000-000000000027', array[(select id from t_sp)]),
  1, 'the admin renews it for 2027/2028'
);
select is(
  public.renew_sponsors('a0270000-0000-0000-0000-000000000027', array[(select id from t_sp)]),
  0, 'renewing twice adds nothing'
);

select lives_ok($$select public.set_sponsor_active((select id from t_sp), false)$$, 'the admin deactivates it');
select results_eq(
  $$select is_active, cardinality(season_ids) from public.get_club_sponsors('d0270000-0000-0000-0000-000000000001')$$,
  $$values (false, 2)$$,
  'deactivated, it keeps its seasons'
);

-- Validations and permissions.
select throws_ok(
  $$select public.save_sponsor(null, 'd0270000-0000-0000-0000-000000000001', 'Web insegura', null, 'http://x.es')$$,
  '22023', null, 'the website must be https'
);
select throws_ok(
  $$select public.save_sponsor(null, 'd0270000-0000-0000-0000-000000000001', 'Restaurante X', null, null)$$,
  '23505', null, 'no duplicated names in the club'
);
select throws_ok(
  $$select public.set_sponsor_seasons((select id from t_sp), array['a0270000-0000-0000-0000-000000000099'::uuid])$$,
  '22023', null, 'seasons of another club are rejected'
);

set local request.jwt.claims = '{"sub":"b0270000-0000-0000-0000-000000000002","role":"authenticated"}';
select throws_ok(
  $$select * from public.get_club_sponsors('d0270000-0000-0000-0000-000000000001')$$,
  '42501', null, 'members do not manage sponsors'
);
set local request.jwt.claims = '{"sub":"b0270000-0000-0000-0000-000000000003","role":"authenticated"}';
select throws_ok(
  $$select public.set_sponsor_active((select id from t_sp), true)$$,
  '42501', null, 'the admin of another club cannot touch them'
);
select is((select count(*)::int from public.sponsors), 0, 'nor read them');

select * from finish();
rollback;
