begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

insert into auth.users (id, email, aud, role) values
  ('bb000000-0000-0000-0000-000000000001', 'admin20@test.com', 'authenticated', 'authenticated'),
  ('bb000000-0000-0000-0000-000000000002', 'marta20@test.com', 'authenticated', 'authenticated'),
  ('bb000000-0000-0000-0000-000000000003', 'pablo20@test.com', 'authenticated', 'authenticated'),
  ('bb000000-0000-0000-0000-000000000004', 'otroadmin20@test.com', 'authenticated', 'authenticated');
update public.profiles set first_name = 'Marta', last_name = 'Gil' where id = 'bb000000-0000-0000-0000-000000000002';
update public.profiles set first_name = 'Pablo', last_name = 'Ruiz' where id = 'bb000000-0000-0000-0000-000000000003';
insert into public.clubs (id, name, code) values
  ('db000000-0000-0000-0000-000000000001', 'Veinte TEST', 'VEINTETEST'),
  ('db000000-0000-0000-0000-000000000002', 'Otro TEST', 'OTROVEINTETEST');
insert into public.seasons (id, club_id, name, starts_on, ends_on, default_fee_cents, status) values
  ('ab000000-0000-0000-0000-000000000025', 'db000000-0000-0000-0000-000000000001', '2025/2026', '2025-09-01', '2026-08-31', 4500, 'closed'),
  ('ab000000-0000-0000-0000-000000000026', 'db000000-0000-0000-0000-000000000001', '2026/2027', '2026-09-01', '2027-08-31', 5000, 'active'),
  ('ab000000-0000-0000-0000-000000000099', 'db000000-0000-0000-0000-000000000002', '2026/2027', '2026-09-01', '2027-08-31', 3000, 'active');
alter table public.club_memberships disable trigger club_memberships_join_active_season;
insert into public.club_memberships (id, user_id, club_id, member_number, role) values
  ('eb000000-0000-0000-0000-000000000001', 'bb000000-0000-0000-0000-000000000001', 'db000000-0000-0000-0000-000000000001', 1, 'club_admin'),
  ('eb000000-0000-0000-0000-000000000002', 'bb000000-0000-0000-0000-000000000002', 'db000000-0000-0000-0000-000000000001', 2, 'member'),
  ('eb000000-0000-0000-0000-000000000003', 'bb000000-0000-0000-0000-000000000003', 'db000000-0000-0000-0000-000000000001', 3, 'member'),
  ('eb000000-0000-0000-0000-000000000004', 'bb000000-0000-0000-0000-000000000004', 'db000000-0000-0000-0000-000000000002', 1, 'club_admin'),
  ('eb000000-0000-0000-0000-000000000005', 'bb000000-0000-0000-0000-000000000002', 'db000000-0000-0000-0000-000000000002', 2, 'member');
alter table public.club_memberships enable trigger club_memberships_join_active_season;
insert into public.season_memberships (id, club_membership_id, season_id, fee_cents, status) values
  ('fb000000-0000-0000-0000-000000000225', 'eb000000-0000-0000-0000-000000000002', 'ab000000-0000-0000-0000-000000000025', 4500, 'pending_payment'),
  ('fb000000-0000-0000-0000-000000000226', 'eb000000-0000-0000-0000-000000000002', 'ab000000-0000-0000-0000-000000000026', 5000, 'pending_payment'),
  ('fb000000-0000-0000-0000-000000000326', 'eb000000-0000-0000-0000-000000000003', 'ab000000-0000-0000-0000-000000000026', 5000, 'pending_payment'),
  ('fb000000-0000-0000-0000-000000000599', 'eb000000-0000-0000-0000-000000000005', 'ab000000-0000-0000-0000-000000000099', 3000, 'pending_payment');
insert into public.payments (season_membership_id, amount_cents, concept, status, provider, method, paid_at) values
  ('fb000000-0000-0000-0000-000000000225', 4500, 'Cuota de socio 2025/2026', 'paid', 'manual', 'cash', '2025-09-10'),
  ('fb000000-0000-0000-0000-000000000226', 5000, 'Cuota de socio 2026/2027', 'paid', 'manual', 'bizum', '2026-09-10'),
  ('fb000000-0000-0000-0000-000000000599', 3000, 'Cuota de socio 2026/2027', 'paid', 'manual', 'cash', '2026-09-12');
-- Pablo's 2026/2027 fee is still pending (no payment row).

set local role authenticated;
set local request.jwt.claims = '{"sub":"bb000000-0000-0000-0000-000000000001","role":"authenticated"}';

select results_eq(
  $$select member_first_name, status, amount_cents, payment_id is null, total_count, paid_cents, pending_cents
    from public.get_club_payments('db000000-0000-0000-0000-000000000001',
      p_season_id => 'ab000000-0000-0000-0000-000000000026', p_status => 'pending')$$,
  $$values ('Pablo'::text, 'pending'::text, 5000, true, 1::bigint, 0::bigint, 5000::bigint)$$,
  'season + Pendiente: only the pending fees of that season and their total'
);
select results_eq(
  $$select count(*)::int, max(paid_cents), max(pending_cents)
    from public.get_club_payments('db000000-0000-0000-0000-000000000001',
      p_season_id => 'ab000000-0000-0000-0000-000000000026')$$,
  $$values (2, 5000::bigint, 5000::bigint)$$,
  'a season shows collected and pending totals'
);
select results_eq(
  $$select season_name, amount_cents, status, receipt_number is not null
    from public.get_club_payments('db000000-0000-0000-0000-000000000001', p_query => 'marta')$$,
  $$values ('2026/2027'::text, 5000, 'paid'::text, true), ('2025/2026'::text, 4500, 'paid'::text, true)$$,
  'filtering by member shows all of Marta''s payments in the club, newest first, with receipts'
);
select is(
  (select count(*)::int from public.get_club_payments('db000000-0000-0000-0000-000000000001', p_query => 'marta')
   where amount_cents = 3000),
  0, 'Marta''s payments in the other club are not shown'
);
select is(
  (select count(*)::int from public.get_club_payments('db000000-0000-0000-0000-000000000001', p_query => '3')),
  1, 'search by member number'
);
select results_eq(
  $$select count(*)::int, max(total_count)::int
    from public.get_club_payments('db000000-0000-0000-0000-000000000001', p_limit => 2)$$,
  $$values (2, 3)$$,
  'pagination keeps the total count'
);
select throws_ok(
  $$select * from public.get_club_payments('db000000-0000-0000-0000-000000000002')$$,
  '42501', null, 'the admin of one club does not see payments of another club'
);
select throws_ok(
  $$select * from public.get_club_payments('db000000-0000-0000-0000-000000000001',
      p_season_id => 'ab000000-0000-0000-0000-000000000099')$$,
  'P0002', null, 'a season of another club is rejected'
);
select throws_ok(
  $$select * from public.get_club_payments('db000000-0000-0000-0000-000000000001', p_status => 'bogus')$$,
  '22023', null, 'unknown status'
);

set local request.jwt.claims = '{"sub":"bb000000-0000-0000-0000-000000000002","role":"authenticated"}';
select throws_ok(
  $$select * from public.get_club_payments('db000000-0000-0000-0000-000000000001')$$,
  '42501', null, 'members cannot list the club payments'
);

select * from finish();
rollback;
