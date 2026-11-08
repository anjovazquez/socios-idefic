begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

insert into auth.users (id, email, aud, role) values
  ('b9000000-0000-0000-0000-000000000001', 'ana18@test.com', 'authenticated', 'authenticated'),
  ('b9000000-0000-0000-0000-000000000002', 'luis18@test.com', 'authenticated', 'authenticated'),
  ('b9000000-0000-0000-0000-000000000003', 'otro18@test.com', 'authenticated', 'authenticated');
insert into public.clubs (id, name, code) values ('d9000000-0000-0000-0000-000000000001', 'Dieciocho TEST', 'DIECIOCHOTEST');
insert into public.seasons (id, club_id, name, starts_on, ends_on, default_fee_cents, status) values
  ('a9000000-0000-0000-0000-000000000025', 'd9000000-0000-0000-0000-000000000001', '2025/2026', '2025-09-01', '2026-08-31', 4500, 'closed'),
  ('a9000000-0000-0000-0000-000000000026', 'd9000000-0000-0000-0000-000000000001', '2026/2027', '2026-09-01', '2027-08-31', 5000, 'active');
alter table public.club_memberships disable trigger club_memberships_join_active_season;
insert into public.club_memberships (id, user_id, club_id, member_number) values
  ('e9000000-0000-0000-0000-000000000001', 'b9000000-0000-0000-0000-000000000001', 'd9000000-0000-0000-0000-000000000001', 1),
  ('e9000000-0000-0000-0000-000000000002', 'b9000000-0000-0000-0000-000000000002', 'd9000000-0000-0000-0000-000000000001', 2);
alter table public.club_memberships enable trigger club_memberships_join_active_season;
insert into public.season_memberships (id, club_membership_id, season_id, fee_cents, status) values
  ('f9000000-0000-0000-0000-000000000125', 'e9000000-0000-0000-0000-000000000001', 'a9000000-0000-0000-0000-000000000025', 4500, 'pending_payment'),
  ('f9000000-0000-0000-0000-000000000126', 'e9000000-0000-0000-0000-000000000001', 'a9000000-0000-0000-0000-000000000026', 5000, 'pending_payment'),
  ('f9000000-0000-0000-0000-000000000226', 'e9000000-0000-0000-0000-000000000002', 'a9000000-0000-0000-0000-000000000026', 5000, 'pending_payment');
insert into public.payments (season_membership_id, amount_cents, concept, status, provider, method, paid_at) values
  ('f9000000-0000-0000-0000-000000000125', 4500, 'Cuota de socio 2025/2026', 'paid', 'manual', 'cash', '2025-09-10'),
  ('f9000000-0000-0000-0000-000000000126', 5000, 'Cuota de socio 2026/2027', 'paid', 'manual', 'transfer', '2026-09-10'),
  ('f9000000-0000-0000-0000-000000000226', 5000, 'Cuota de socio 2026/2027', 'paid', 'manual', 'bizum', '2026-09-12');

set local role authenticated;
set local request.jwt.claims = '{"sub":"b9000000-0000-0000-0000-000000000001","role":"authenticated"}';
select results_eq(
  $$select season_name, fee_cents, status, payment_method, next_charge_cents
    from public.get_my_subscription('d9000000-0000-0000-0000-000000000001')$$,
  $$values ('2026/2027'::text, 5000, 'active'::text, 'transfer'::text, null::integer)$$,
  'Ana sees the active season, 50 €, paid by transfer, no scheduled charge'
);
select results_eq(
  $$select season_name, concept, amount_cents, status, method
    from public.get_my_payments('d9000000-0000-0000-0000-000000000001')$$,
  $$values ('2026/2027'::text, 'Cuota de socio 2026/2027'::text, 5000, 'paid'::text, 'transfer'::text),
           ('2025/2026'::text, 'Cuota de socio 2025/2026'::text, 4500, 'paid'::text, 'cash'::text)$$,
  'history: season, concept, amount, date order and status'
);
select is(
  (select count(*)::int from public.get_my_payments('d9000000-0000-0000-0000-000000000001')),
  2,
  'only her own payments (not Luis''s)'
);

set local request.jwt.claims = '{"sub":"b9000000-0000-0000-0000-000000000003","role":"authenticated"}';
select throws_ok(
  $$select * from public.get_my_payments('d9000000-0000-0000-0000-000000000001')$$,
  '42501', null, 'non members get nothing'
);
select throws_ok(
  $$select * from public.get_my_subscription('d9000000-0000-0000-0000-000000000001')$$,
  '42501', null, 'non members get no subscription'
);

reset role;
update public.seasons set status = 'closed' where id = 'a9000000-0000-0000-0000-000000000026';
set local role authenticated;
set local request.jwt.claims = '{"sub":"b9000000-0000-0000-0000-000000000001","role":"authenticated"}';
select results_eq(
  $$select season_name, status from public.get_my_subscription('d9000000-0000-0000-0000-000000000001')$$,
  $$values (null::text, null::text)$$,
  'without an active season there is no current subscription'
);
reset role;
set local role anon;
select throws_ok(
  $$select * from public.get_my_payments('d9000000-0000-0000-0000-000000000001')$$,
  '42501', null, 'anonymous users get nothing'
);

select * from finish();
rollback;
