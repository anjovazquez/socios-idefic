begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

insert into auth.users (id, email, aud, role) values
  ('b8000000-0000-0000-0000-000000000001', 'admin17@test.com', 'authenticated', 'authenticated'),
  ('b8000000-0000-0000-0000-000000000002', 'marta17@test.com', 'authenticated', 'authenticated'),
  ('b8000000-0000-0000-0000-000000000003', 'otro17@test.com', 'authenticated', 'authenticated');
insert into public.clubs (id, name, code) values ('d8000000-0000-0000-0000-000000000001', 'Diecisiete TEST', 'DIECISIETETEST');
insert into public.seasons (id, club_id, name, starts_on, ends_on, default_fee_cents, status) values
  ('a8000000-0000-0000-0000-000000000026', 'd8000000-0000-0000-0000-000000000001', '2026/2027', '2026-09-01', '2027-08-31', 5000, 'active');
insert into public.club_memberships (id, user_id, club_id, role, member_number) values
  ('e8000000-0000-0000-0000-000000000001', 'b8000000-0000-0000-0000-000000000001', 'd8000000-0000-0000-0000-000000000001', 'club_admin', 1),
  ('e8000000-0000-0000-0000-000000000002', 'b8000000-0000-0000-0000-000000000002', 'd8000000-0000-0000-0000-000000000001', 'member', 2);

-- Marta joined the active season (trigger) and owes 50 €.
set local role authenticated;
set local request.jwt.claims = '{"sub":"b8000000-0000-0000-0000-000000000002","role":"authenticated"}';
select results_eq(
  $$select fee_cents, status from public.season_memberships$$,
  $$values (5000, 'pending_payment'::text)$$,
  'Marta owes 50 €'
);
select throws_ok(
  $$select public.record_manual_payment((select id from public.season_memberships), 'cash')$$,
  '42501', null, 'a member cannot record her own payment'
);
select throws_ok(
  $$insert into public.payments (season_membership_id, amount_cents, concept, status, provider, paid_at)
    values ((select id from public.season_memberships), 5000, 'x', 'paid', 'manual', now())$$,
  '42501', null, 'nor insert payments directly'
);

set local request.jwt.claims = '{"sub":"b8000000-0000-0000-0000-000000000001","role":"authenticated"}';
select throws_ok(
  $$select public.record_manual_payment(
     (select id from public.season_memberships where club_membership_id = 'e8000000-0000-0000-0000-000000000002'),
     'cash', 0)$$,
  '22023', null, 'amounts must be positive'
);
select throws_ok(
  $$select public.record_manual_payment(
     (select id from public.season_memberships where club_membership_id = 'e8000000-0000-0000-0000-000000000002'),
     'card')$$,
  '22023', null, 'manual payments are cash, transfer, Bizum or other'
);
select lives_ok(
  $$select public.record_manual_payment(
     (select id from public.season_memberships where club_membership_id = 'e8000000-0000-0000-0000-000000000002'),
     'transfer', null, current_date, 'TRF-123')$$,
  'the admin records a transfer of 50 €'
);
select results_eq(
  $$select amount_cents, currency, concept, status, provider, method, provider_reference from public.payments$$,
  $$values (5000, 'EUR'::text, 'Cuota de socio 2026/2027'::text, 'paid'::text, 'manual'::text, 'transfer'::text, 'TRF-123'::text)$$,
  'the payment is stored in cents with its concept'
);
reset role;
select is(
  (select status from public.season_memberships where club_membership_id = 'e8000000-0000-0000-0000-000000000002'),
  'active',
  'Marta becomes an active member'
);

-- Transitions
set local role authenticated;
set local request.jwt.claims = '{"sub":"b8000000-0000-0000-0000-000000000001","role":"authenticated"}';
select throws_ok(
  $$select public.set_payment_status((select id from public.payments), 'failed')$$,
  'P0001', null, 'a paid payment cannot become failed'
);
select lives_ok(
  $$select public.set_payment_status((select id from public.payments), 'cancelled')$$,
  'a manual payment recorded by mistake is cancelled'
);
reset role;
select is(
  (select status from public.season_memberships where club_membership_id = 'e8000000-0000-0000-0000-000000000002'),
  'pending_payment',
  'cancelling the only payment makes the fee pending again'
);
select throws_ok(
  $$update public.payments set status = 'paid'$$,
  'P0001', null, 'a cancelled payment can never become paid'
);
insert into public.payments (season_membership_id, amount_cents, concept, status, provider)
values ((select id from public.season_memberships where club_membership_id = 'e8000000-0000-0000-0000-000000000002'),
        5000, 'Cuota', 'pending', 'stripe');
select lives_ok($$update public.payments set status = 'failed' where provider = 'stripe' and season_membership_id = (select id from public.season_memberships where club_membership_id = 'e8000000-0000-0000-0000-000000000002')$$, 'pending → failed');
select throws_ok($$update public.payments set status = 'paid' where provider = 'stripe' and season_membership_id = (select id from public.season_memberships where club_membership_id = 'e8000000-0000-0000-0000-000000000002')$$, 'P0001', null,
  'failed → paid is not allowed');

-- Visibility
set local role authenticated;
set local request.jwt.claims = '{"sub":"b8000000-0000-0000-0000-000000000002","role":"authenticated"}';
select is((select count(*)::int from public.payments), 2, 'Marta sees her payments');
set local request.jwt.claims = '{"sub":"b8000000-0000-0000-0000-000000000003","role":"authenticated"}';
select is_empty('select 1 from public.payments', 'others see nothing');

select * from finish();
rollback;
