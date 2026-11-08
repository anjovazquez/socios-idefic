begin;
create extension if not exists pgtap with schema extensions;
select plan(19);

insert into auth.users (id, email, aud, role) values
  ('bf000000-0000-0000-0000-000000000001', 'admin24@test.com', 'authenticated', 'authenticated'),
  ('bf000000-0000-0000-0000-000000000002', 'marta24@test.com', 'authenticated', 'authenticated'),
  ('bf000000-0000-0000-0000-000000000003', 'pablo24@test.com', 'authenticated', 'authenticated');
insert into public.clubs (id, name, code, stripe_account_id, stripe_charges_enabled)
values ('df000000-0000-0000-0000-000000000001', 'Veinticuatro TEST', 'VEINTICUATROTEST', 'acct_test_24', true);
-- Charge in 10 days (cancellable now) and another season charged today.
insert into public.seasons (id, club_id, name, starts_on, ends_on, default_fee_cents, status, renewal_charge_on) values
  ('af000000-0000-0000-0000-000000000027', 'df000000-0000-0000-0000-000000000001', '2027/2028', '2027-09-01', '2028-08-31', 5000, 'draft', public.madrid_today() + 10),
  ('af000000-0000-0000-0000-000000000028', 'df000000-0000-0000-0000-000000000001', '2028/2029', '2028-09-01', '2029-08-31', 5000, 'draft', public.madrid_today());
alter table public.club_memberships disable trigger club_memberships_join_active_season;
insert into public.club_memberships (id, user_id, club_id, member_number, role, auto_renew) values
  ('ef000000-0000-0000-0000-000000000001', 'bf000000-0000-0000-0000-000000000001', 'df000000-0000-0000-0000-000000000001', 1, 'club_admin', false),
  ('ef000000-0000-0000-0000-000000000002', 'bf000000-0000-0000-0000-000000000002', 'df000000-0000-0000-0000-000000000001', 2, 'member', true),
  ('ef000000-0000-0000-0000-000000000003', 'bf000000-0000-0000-0000-000000000003', 'df000000-0000-0000-0000-000000000001', 3, 'member', true);
alter table public.club_memberships enable trigger club_memberships_join_active_season;
insert into public.payment_methods (club_membership_id, provider_customer_id, provider_method_id, kind, brand, last4) values
  ('ef000000-0000-0000-0000-000000000002', 'cus_marta', 'pm_marta', 'card', 'visa', '4242'),
  ('ef000000-0000-0000-0000-000000000003', 'cus_pablo', 'pm_pablo', 'card', 'visa', '0341');
insert into public.season_memberships (id, club_membership_id, season_id, fee_cents, status) values
  ('ff000000-0000-0000-0000-000000000227', 'ef000000-0000-0000-0000-000000000002', 'af000000-0000-0000-0000-000000000027', 5000, 'pending_payment'),
  ('ff000000-0000-0000-0000-000000000327', 'ef000000-0000-0000-0000-000000000003', 'af000000-0000-0000-0000-000000000027', 5000, 'pending_payment'),
  ('ff000000-0000-0000-0000-000000000228', 'ef000000-0000-0000-0000-000000000002', 'af000000-0000-0000-0000-000000000028', 5000, 'pending_payment');
-- Notices already sent.
insert into public.renewal_notices (season_membership_id, charge_on, amount_cents, sent_to) values
  ('ff000000-0000-0000-0000-000000000227', public.madrid_today() + 10, 5000, 'marta24@test.com'),
  ('ff000000-0000-0000-0000-000000000327', public.madrid_today() + 10, 5000, 'pablo24@test.com'),
  ('ff000000-0000-0000-0000-000000000228', public.madrid_today(), 5000, 'marta24@test.com');

-- Cancel before the charge.
set local role authenticated;
set local request.jwt.claims = '{"sub":"bf000000-0000-0000-0000-000000000002","role":"authenticated"}';
select results_eq(
  $$select next_charge_season, next_charge_cancellable from public.get_my_subscription('df000000-0000-0000-0000-000000000001')$$,
  $$values ('2028/2029'::text, false)$$,
  'the next charge is today: it can no longer be cancelled'
);
select lives_ok(
  $$select public.cancel_renewal('ff000000-0000-0000-0000-000000000227')$$,
  'Marta cancels the renewal before the charge date'
);
select throws_ok(
  $$select public.cancel_renewal('ff000000-0000-0000-0000-000000000327')$$,
  '42501', null, 'nobody cancels someone else''s renewal'
);
select throws_ok(
  $$select public.cancel_renewal('ff000000-0000-0000-0000-000000000228')$$,
  'P0001', null, 'on the charge date it is too late to cancel'
);
reset role;
select is(
  (select status from public.season_memberships where id = 'ff000000-0000-0000-0000-000000000227'),
  'cancelled', 'her renewal is cancelled'
);
select is(
  public.can_charge_renewal('ff000000-0000-0000-0000-000000000227', public.madrid_today() + 10),
  false, 'and it will not be charged'
);
set local role authenticated;
set local request.jwt.claims = '{"sub":"bf000000-0000-0000-0000-000000000001","role":"authenticated"}';
select results_eq(
  $$select status, concept from public.get_club_payments('df000000-0000-0000-0000-000000000001',
      p_season_id => 'af000000-0000-0000-0000-000000000027', p_status => 'cancelled')$$,
  $$values ('cancelled'::text, 'Renovación cancelada por el socio'::text)$$,
  'the admin sees the cancelled renewal in Pagos'
);
reset role;

-- Automatic charge on the charge date.
select set_eq(
  $$select season_membership_id from public.get_due_renewal_charges(public.madrid_today() + 10)$$,
  $$values ('ff000000-0000-0000-0000-000000000327'::uuid), ('ff000000-0000-0000-0000-000000000228'::uuid)$$,
  'due charges: not cancelled, notified, with a method, date reached'
);
select is(
  (select count(*)::int from public.get_due_renewal_charges(public.madrid_today() + 9)
   where season_membership_id = 'ff000000-0000-0000-0000-000000000327'),
  0, 'not before the charge date'
);
create temporary table t_charge as
  select * from public.claim_renewal_charge('ff000000-0000-0000-0000-000000000228');
select results_eq(
  $$select amount_cents, stripe_account_id, customer_id, method_id from t_charge$$,
  $$values (5000, 'acct_test_24'::text, 'cus_marta'::text, 'pm_marta'::text)$$,
  'the charge uses the saved card in the club account'
);
select is(
  (select count(*)::int from public.claim_renewal_charge('ff000000-0000-0000-0000-000000000228')),
  0, 'a second run the same day does not charge again'
);
select is(
  (select count(*)::int from public.payments where season_membership_id = 'ff000000-0000-0000-0000-000000000228'),
  1, 'Marta has a single charge'
);

set local role authenticated;
set local request.jwt.claims = '{"sub":"bf000000-0000-0000-0000-000000000002","role":"authenticated"}';
select throws_ok(
  $$select public.cancel_renewal('ff000000-0000-0000-0000-000000000228')$$,
  'P0001', null, 'once charged, cancelling is rejected (contact the club)'
);
reset role;

select is(
  public.apply_payment_event('evt_renewal_ok', 'payment_intent.succeeded', (select payment_id from t_charge), 'paid', 'card', 'pi_r'),
  'applied', 'the provider confirms the charge'
);
select results_eq(
  $$select p.status, sm.status from public.payments p join public.season_memberships sm on sm.id = p.season_membership_id
    where p.id = (select payment_id from t_charge)$$,
  $$values ('paid'::text, 'active'::text)$$,
  '50 € paid and her 2028/2029 card is active'
);

-- Failed charge: Pablo's card expired.
create temporary table t_fail as
  select * from public.claim_renewal_charge('ff000000-0000-0000-0000-000000000327', public.madrid_today() + 10);
select public.apply_payment_event('evt_renewal_ko', 'payment_intent.payment_failed', (select payment_id from t_fail), 'failed');
select results_eq(
  $$select email, season_name, amount_cents from public.get_failed_renewal_charges()$$,
  $$values ('pablo24@test.com'::text, '2027/2028'::text, 5000)$$,
  'the failed charge is pending to be notified'
);
select public.mark_renewal_failure_notified('ff000000-0000-0000-0000-000000000327');
select is((select count(*)::int from public.get_failed_renewal_charges()), 0, 'notified once');
select is(
  (select status from public.season_memberships where id = 'ff000000-0000-0000-0000-000000000327'),
  'pending_payment', 'the fee stays pending so he can pay manually'
);

set local role authenticated;
select throws_ok(
  $$select * from public.claim_renewal_charge('ff000000-0000-0000-0000-000000000327')$$,
  '42501', null, 'only the server charges renewals'
);

select * from finish();
rollback;
