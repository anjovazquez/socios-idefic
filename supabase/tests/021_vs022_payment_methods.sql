begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

insert into auth.users (id, email, aud, role) values
  ('bd000000-0000-0000-0000-000000000002', 'marta22@test.com', 'authenticated', 'authenticated'),
  ('bd000000-0000-0000-0000-000000000003', 'otro22@test.com', 'authenticated', 'authenticated');
insert into public.clubs (id, name, code, stripe_account_id, stripe_charges_enabled)
values ('dd000000-0000-0000-0000-000000000001', 'Veintidos TEST', 'VEINTIDOSTEST', 'acct_test_22', true);
alter table public.club_memberships disable trigger club_memberships_join_active_season;
insert into public.club_memberships (id, user_id, club_id, member_number) values
  ('ed000000-0000-0000-0000-000000000002', 'bd000000-0000-0000-0000-000000000002', 'dd000000-0000-0000-0000-000000000001', 2);
alter table public.club_memberships enable trigger club_memberships_join_active_season;

set local role authenticated;
set local request.jwt.claims = '{"sub":"bd000000-0000-0000-0000-000000000002","role":"authenticated"}';
select results_eq(
  $$select kind, auto_renew from public.get_my_payment_method('dd000000-0000-0000-0000-000000000001')$$,
  $$values (null::text, false)$$,
  'no saved method and no automatic renewal at first'
);
select results_eq(
  $$select club_membership_id, stripe_account_id, member_email
    from public.prepare_payment_method_setup('dd000000-0000-0000-0000-000000000001')$$,
  $$values ('ed000000-0000-0000-0000-000000000002'::uuid, 'acct_test_22'::text, 'marta22@test.com'::text)$$,
  'Marta can open a setup Checkout to save a method without paying'
);
select throws_ok(
  $$select public.save_payment_method('evt_x', 'ed000000-0000-0000-0000-000000000002', 'cus', 'pm', 'card')$$,
  '42501', null, 'only the webhook saves methods'
);

reset role;
select is(
  public.save_payment_method('evt_card', 'ed000000-0000-0000-0000-000000000002', 'cus_marta', 'pm_card', 'card', 'visa', '4242'),
  'applied', 'the webhook saves the card of the Checkout'
);
select is(
  public.save_payment_method('evt_card', 'ed000000-0000-0000-0000-000000000002', 'cus_marta', 'pm_card', 'card', 'visa', '4242'),
  'duplicate', 'a repeated event does not save it twice'
);
select throws_ok(
  $$select public.save_payment_method('evt_bad', 'ed000000-0000-0000-0000-000000000002', 'cus', 'pm', 'card', 'visa', '4242424242424242')$$,
  '23514', null, 'full card numbers can never be stored'
);

set local role authenticated;
set local request.jwt.claims = '{"sub":"bd000000-0000-0000-0000-000000000002","role":"authenticated"}';
select results_eq(
  $$select kind, brand, last4, auto_renew from public.get_my_payment_method('dd000000-0000-0000-0000-000000000001')$$,
  $$values ('card'::text, 'visa'::text, '4242'::text, true)$$,
  'her subscription shows the card ending in 4242 and automatic renewal on'
);

reset role;
select public.save_payment_method('evt_sepa', 'ed000000-0000-0000-0000-000000000002', 'cus_marta', 'pm_sepa', 'sepa_debit', null, '3000', 'ES', 'mandate_1');
set local role authenticated;
set local request.jwt.claims = '{"sub":"bd000000-0000-0000-0000-000000000002","role":"authenticated"}';
select results_eq(
  $$select kind, last4, country from public.get_my_payment_method('dd000000-0000-0000-0000-000000000001')$$,
  $$values ('sepa_debit'::text, '3000'::text, 'ES'::text)$$,
  'a bank account with its mandate replaces the card (masked IBAN)'
);
select is(
  (select count(*)::int from public.payment_methods),
  2, 'she sees her own methods (the replaced one is kept as history)'
);

set local request.jwt.claims = '{"sub":"bd000000-0000-0000-0000-000000000003","role":"authenticated"}';
select is((select count(*)::int from public.payment_methods), 0, 'others do not see them');

set local request.jwt.claims = '{"sub":"bd000000-0000-0000-0000-000000000002","role":"authenticated"}';
select results_eq(
  $$select stripe_account_id, provider_method_id from public.remove_my_payment_method('dd000000-0000-0000-0000-000000000001')$$,
  $$values ('acct_test_22'::text, 'pm_sepa'::text)$$,
  'removing returns what to detach in Stripe'
);
select results_eq(
  $$select kind, auto_renew from public.get_my_payment_method('dd000000-0000-0000-0000-000000000001')$$,
  $$values (null::text, false)$$,
  'after removing it the automatic renewal is off'
);

select * from finish();
rollback;
