begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

insert into auth.users (id, email, aud, role) values
  ('b4000000-0000-0000-0000-000000000001', 'admin13@test.com', 'authenticated', 'authenticated'),
  ('b4000000-0000-0000-0000-000000000002', 'ana13@test.com', 'authenticated', 'authenticated'),
  ('b4000000-0000-0000-0000-000000000003', 'marta13@test.com', 'authenticated', 'authenticated'),
  ('b4000000-0000-0000-0000-000000000004', 'luis13@test.com', 'authenticated', 'authenticated'),
  ('b4000000-0000-0000-0000-000000000005', 'ajeno13@test.com', 'authenticated', 'authenticated');
insert into public.clubs (id, name, code) values
  ('d4000000-0000-0000-0000-000000000001', 'Trece TEST', 'TRECETEST'),
  ('d4000000-0000-0000-0000-000000000002', 'Sin temporada TEST', 'SINTEMP13TEST');
insert into public.seasons (id, club_id, name, starts_on, ends_on, default_fee_cents, status) values
  ('a4000000-0000-0000-0000-000000000025', 'd4000000-0000-0000-0000-000000000001', '2025/2026', '2025-09-01', '2026-08-31', 4500, 'closed'),
  ('a4000000-0000-0000-0000-000000000026', 'd4000000-0000-0000-0000-000000000001', '2026/2027', '2026-09-01', '2027-08-31', 5000, 'closed'),
  ('a4000000-0000-0000-0000-000000000027', 'd4000000-0000-0000-0000-000000000001', '2027/2028', '2027-09-01', '2028-08-31', 5000, 'active');

-- New memberships join the active season (trigger).
insert into public.club_memberships (id, user_id, club_id, role, member_number) values
  ('e4000000-0000-0000-0000-000000000001', 'b4000000-0000-0000-0000-000000000001', 'd4000000-0000-0000-0000-000000000001', 'club_admin', 1),
  ('e4000000-0000-0000-0000-000000000003', 'b4000000-0000-0000-0000-000000000003', 'd4000000-0000-0000-0000-000000000001', 'member', 3),
  ('e4000000-0000-0000-0000-000000000004', 'b4000000-0000-0000-0000-000000000004', 'd4000000-0000-0000-0000-000000000001', 'member', 4),
  ('e4000000-0000-0000-0000-000000000005', 'b4000000-0000-0000-0000-000000000005', 'd4000000-0000-0000-0000-000000000002', 'member', 1);

select results_eq(
  $$select fee_cents, status from public.season_memberships
    where club_membership_id = 'e4000000-0000-0000-0000-000000000003'$$,
  $$values (5000, 'pending_payment'::text)$$,
  'a new member joins the active season with the ordinary fee'
);
select is_empty(
  $$select 1 from public.season_memberships where club_membership_id = 'e4000000-0000-0000-0000-000000000005'$$,
  'without an active season nothing is created'
);
select throws_ok(
  $$insert into public.season_memberships (club_membership_id, season_id, fee_cents)
    values ('e4000000-0000-0000-0000-000000000005', 'a4000000-0000-0000-0000-000000000027', 100)$$,
  '22023', null, 'season and membership must be of the same club'
);

-- Ana: member in 2025/2026 and 2026/2027, not in 2027/2028 (§7 example).
alter table public.club_memberships disable trigger club_memberships_join_active_season;
insert into public.club_memberships (id, user_id, club_id, role, member_number) values
  ('e4000000-0000-0000-0000-000000000002', 'b4000000-0000-0000-0000-000000000002', 'd4000000-0000-0000-0000-000000000001', 'member', 2);
alter table public.club_memberships enable trigger club_memberships_join_active_season;
insert into public.season_memberships (club_membership_id, season_id, fee_cents, status) values
  ('e4000000-0000-0000-0000-000000000002', 'a4000000-0000-0000-0000-000000000025', 4500, 'active'),
  ('e4000000-0000-0000-0000-000000000002', 'a4000000-0000-0000-0000-000000000026', 5000, 'active');

set local role authenticated;
set local request.jwt.claims = '{"sub":"b4000000-0000-0000-0000-000000000001","role":"authenticated"}';

select results_eq(
  $$select season_name, status from public.get_member_seasons('e4000000-0000-0000-0000-000000000002')$$,
  $$values ('2027/2028'::text, 'not_renewed'::text), ('2026/2027'::text, 'active'::text), ('2025/2026'::text, 'active'::text)$$,
  'history: Socio, Socio, No renovado'
);
select results_eq(
  $$select season_fee_cents, season_status from public.get_club_members('d4000000-0000-0000-0000-000000000001', 'marta')$$,
  $$values (5000, 'pending_payment'::text)$$,
  'the members list shows the current season'
);

select lives_ok(
  $$select public.set_member_fee((select id from public.season_memberships
     where club_membership_id = 'e4000000-0000-0000-0000-000000000003'), 2500)$$,
  'the admin sets 25 € for Marta'
);
select lives_ok(
  $$select public.set_member_fee((select id from public.season_memberships
     where club_membership_id = 'e4000000-0000-0000-0000-000000000004'), 0)$$,
  'the admin sets 0 € for Luis'
);
reset role;
select results_eq(
  $$select m.member_number, sm.fee_cents, sm.status
    from public.season_memberships sm join public.club_memberships m on m.id = sm.club_membership_id
    where m.member_number in (3, 4) and m.club_id = 'd4000000-0000-0000-0000-000000000001' order by 1$$,
  $$values (3, 2500, 'pending_payment'::text), (4, 0, 'active'::text)$$,
  'Marta owes 25 €; Luis is an active member without paying'
);
set local role authenticated;
set local request.jwt.claims = '{"sub":"b4000000-0000-0000-0000-000000000001","role":"authenticated"}';
select throws_ok(
  $$select public.set_member_fee((select id from public.season_memberships
     where club_membership_id = 'e4000000-0000-0000-0000-000000000003'), -500)$$,
  '22023', null, 'negative fees are rejected'
);
select lives_ok(
  $$select public.set_season_membership_status((select id from public.season_memberships
     where club_membership_id = 'e4000000-0000-0000-0000-000000000003'), 'active')$$,
  'the admin records that Marta paid (until online payments exist)'
);
select throws_ok(
  $$select public.set_season_membership_status((select id from public.season_memberships
     where club_membership_id = 'e4000000-0000-0000-0000-000000000003'), 'cancelled')$$,
  '22023', null, 'only pending/active can be set by hand'
);

-- Marta (member)
set local request.jwt.claims = '{"sub":"b4000000-0000-0000-0000-000000000003","role":"authenticated"}';
select results_eq(
  $$select fee_cents, status from public.season_memberships$$,
  $$values (2500, 'active'::text)$$,
  'a member reads only her own season memberships'
);
select throws_ok(
  $$select public.set_member_fee((select id from public.season_memberships), 0)$$,
  '42501', null, 'members cannot change their fee'
);
select throws_ok(
  $$update public.season_memberships set fee_cents = 0$$,
  '42501', null, 'nor update it directly'
);

-- Member of another club
set local request.jwt.claims = '{"sub":"b4000000-0000-0000-0000-000000000005","role":"authenticated"}';
select is_empty('select 1 from public.season_memberships', 'other clubs see nothing');

reset role;
select is(
  (select count(*)::int from public.audit_log where action in ('member_fee_changed', 'member_season_status_changed')),
  3,
  'fee and status changes are audited'
);

select * from finish();
rollback;
