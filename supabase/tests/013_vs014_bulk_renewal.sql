begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

insert into auth.users (id, email, aud, role) values
  ('b5000000-0000-0000-0000-000000000001', 'admin14@test.com', 'authenticated', 'authenticated'),
  ('b5000000-0000-0000-0000-000000000002', 'ana14@test.com', 'authenticated', 'authenticated'),
  ('b5000000-0000-0000-0000-000000000003', 'marta14@test.com', 'authenticated', 'authenticated'),
  ('b5000000-0000-0000-0000-000000000004', 'pedro14@test.com', 'authenticated', 'authenticated'),
  ('b5000000-0000-0000-0000-000000000005', 'debe14@test.com', 'authenticated', 'authenticated');
insert into public.clubs (id, name, code) values
  ('d5000000-0000-0000-0000-000000000001', 'Catorce TEST', 'CATORCETEST');
insert into public.seasons (id, club_id, name, starts_on, ends_on, default_fee_cents, status) values
  ('a5000000-0000-0000-0000-000000000026', 'd5000000-0000-0000-0000-000000000001', '2026/2027', '2026-09-01', '2027-08-31', 5000, 'closed'),
  ('a5000000-0000-0000-0000-000000000027', 'd5000000-0000-0000-0000-000000000001', '2027/2028', '2027-09-01', '2028-08-31', 5500, 'active');
alter table public.club_memberships disable trigger club_memberships_join_active_season;
insert into public.club_memberships (id, user_id, club_id, role, member_number, status) values
  ('e5000000-0000-0000-0000-000000000001', 'b5000000-0000-0000-0000-000000000001', 'd5000000-0000-0000-0000-000000000001', 'club_admin', 1, 'active'),
  ('e5000000-0000-0000-0000-000000000002', 'b5000000-0000-0000-0000-000000000002', 'd5000000-0000-0000-0000-000000000001', 'member', 2, 'active'),
  ('e5000000-0000-0000-0000-000000000003', 'b5000000-0000-0000-0000-000000000003', 'd5000000-0000-0000-0000-000000000001', 'member', 3, 'active'),
  ('e5000000-0000-0000-0000-000000000004', 'b5000000-0000-0000-0000-000000000004', 'd5000000-0000-0000-0000-000000000001', 'member', 4, 'inactive'),
  ('e5000000-0000-0000-0000-000000000005', 'b5000000-0000-0000-0000-000000000005', 'd5000000-0000-0000-0000-000000000001', 'member', 5, 'active');
alter table public.club_memberships enable trigger club_memberships_join_active_season;
insert into public.season_memberships (club_membership_id, season_id, fee_cents, status) values
  ('e5000000-0000-0000-0000-000000000001', 'a5000000-0000-0000-0000-000000000026', 0, 'active'),
  ('e5000000-0000-0000-0000-000000000002', 'a5000000-0000-0000-0000-000000000026', 5000, 'active'),
  ('e5000000-0000-0000-0000-000000000003', 'a5000000-0000-0000-0000-000000000026', 5000, 'active'),
  ('e5000000-0000-0000-0000-000000000004', 'a5000000-0000-0000-0000-000000000026', 5000, 'active'),
  ('e5000000-0000-0000-0000-000000000005', 'a5000000-0000-0000-0000-000000000026', 5000, 'pending_payment');

set local role authenticated;
set local request.jwt.claims = '{"sub":"b5000000-0000-0000-0000-000000000001","role":"authenticated"}';

select results_eq(
  $$select member_number from public.get_renewal_candidates('a5000000-0000-0000-0000-000000000027')$$,
  array[1, 2, 3],
  'renewable: active members of the previous season, not deactivated nor unpaid'
);
select results_eq(
  $$select member_number, proposed_fee_cents, previous_was_custom
    from public.get_renewal_candidates('a5000000-0000-0000-0000-000000000027', true)$$,
  $$values (1, 0, true), (2, 5500, false), (3, 5500, false)$$,
  'keeping custom fees: the exempt admin stays at 0 €, the rest at the new ordinary fee'
);
select results_eq(
  $$select proposed_fee_cents from public.get_renewal_candidates('a5000000-0000-0000-0000-000000000027', false)$$,
  array[5500, 5500, 5500],
  'without custom fees everybody gets the ordinary fee'
);

select is(
  public.bulk_renew('a5000000-0000-0000-0000-000000000027',
    '[{"membership_id":"e5000000-0000-0000-0000-000000000001","fee_cents":0},
      {"membership_id":"e5000000-0000-0000-0000-000000000002","fee_cents":2500}]'::jsonb),
  2,
  'renew two members, excluding Marta and with 25 € for Ana'
);
reset role;
select results_eq(
  $$select m.member_number, sm.fee_cents, sm.status
    from public.season_memberships sm
    join public.club_memberships m on m.id = sm.club_membership_id
    where sm.season_id = 'a5000000-0000-0000-0000-000000000027' order by 1$$,
  $$values (1, 0, 'active'::text), (2, 2500, 'pending_payment'::text)$$,
  '0 € renews as member; the rest is pending payment'
);
set local role authenticated;
set local request.jwt.claims = '{"sub":"b5000000-0000-0000-0000-000000000001","role":"authenticated"}';
select results_eq(
  $$select member_number, already_renewed from public.get_renewal_candidates('a5000000-0000-0000-0000-000000000027')$$,
  $$values (1, true), (2, true), (3, false)$$,
  'renewed members are flagged'
);
select is(
  public.bulk_renew('a5000000-0000-0000-0000-000000000027',
    '[{"membership_id":"e5000000-0000-0000-0000-000000000001","fee_cents":0},
      {"membership_id":"e5000000-0000-0000-0000-000000000002","fee_cents":2500},
      {"membership_id":"e5000000-0000-0000-0000-000000000003","fee_cents":5500}]'::jsonb),
  1,
  'running it again does not duplicate (only Marta is new)'
);
select throws_ok(
  $$select public.bulk_renew('a5000000-0000-0000-0000-000000000027',
    '[{"membership_id":"e5000000-0000-0000-0000-000000000004","fee_cents":5500}]'::jsonb)$$,
  'P0001', null, 'deactivated members cannot be renewed'
);
select throws_ok(
  $$select public.bulk_renew('a5000000-0000-0000-0000-000000000027',
    '[{"membership_id":"e5000000-0000-0000-0000-000000000005","fee_cents":5500}]'::jsonb)$$,
  'P0001', null, 'members who did not pay the previous season are not renewed in bulk'
);
select throws_ok(
  $$select public.bulk_renew('a5000000-0000-0000-0000-000000000027',
    '[{"membership_id":"e5000000-0000-0000-0000-000000000003","fee_cents":-1}]'::jsonb)$$,
  '22023', null, 'negative fees are rejected'
);
select throws_ok(
  $$select public.bulk_renew('a5000000-0000-0000-0000-000000000026', '[]'::jsonb)$$,
  'P0001', null, 'closed seasons cannot receive renewals'
);

set local request.jwt.claims = '{"sub":"b5000000-0000-0000-0000-000000000002","role":"authenticated"}';
select throws_ok(
  $$select * from public.get_renewal_candidates('a5000000-0000-0000-0000-000000000027')$$,
  '42501', null, 'members cannot see or run renewals'
);

reset role;
select is(
  (select sum((payload ->> 'renewed')::int)::int from public.audit_log where action = 'season_renewed'),
  3,
  'renewals are audited with their counts'
);

select * from finish();
rollback;
