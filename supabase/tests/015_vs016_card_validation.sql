begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into auth.users (id, email, aud, role) values
  ('b7000000-0000-0000-0000-000000000001', 'admin16@test.com', 'authenticated', 'authenticated'),
  ('b7000000-0000-0000-0000-000000000002', 'ana16@test.com', 'authenticated', 'authenticated');
update public.profiles set first_name = 'Ana', last_name = 'Pérez', phone = '600000016', birth_date = '1990-01-01'
where id = 'b7000000-0000-0000-0000-000000000002';
insert into public.clubs (id, name, code) values ('d7000000-0000-0000-0000-000000000001', 'Dieciséis TEST', 'DIECISTEST');
insert into public.seasons (id, club_id, name, starts_on, ends_on, default_fee_cents, status) values
  ('a7000000-0000-0000-0000-000000000026', 'd7000000-0000-0000-0000-000000000001', '2026/2027', '2026-09-01', '2027-08-31', 5000, 'closed'),
  ('a7000000-0000-0000-0000-000000000027', 'd7000000-0000-0000-0000-000000000001', '2027/2028', '2027-09-01', '2028-08-31', 5000, 'active');
alter table public.club_memberships disable trigger club_memberships_join_active_season;
insert into public.club_memberships (id, user_id, club_id, role, member_number) values
  ('e7000000-0000-0000-0000-000000000001', 'b7000000-0000-0000-0000-000000000001', 'd7000000-0000-0000-0000-000000000001', 'club_admin', 1),
  ('e7000000-0000-0000-0000-000000000002', 'b7000000-0000-0000-0000-000000000002', 'd7000000-0000-0000-0000-000000000001', 'member', 2);
alter table public.club_memberships enable trigger club_memberships_join_active_season;
insert into public.season_memberships (id, club_membership_id, season_id, fee_cents, status, card_token) values
  ('f7000000-0000-0000-0000-000000000026', 'e7000000-0000-0000-0000-000000000002', 'a7000000-0000-0000-0000-000000000026', 5000, 'active', 'old-season-token-0000001'),
  ('f7000000-0000-0000-0000-000000000027', 'e7000000-0000-0000-0000-000000000002', 'a7000000-0000-0000-0000-000000000027', 5000, 'active', 'current-season-token-001');

set local role service_role;
select results_eq(
  $$select state, club_name, first_name, member_number, season_name from public.validate_card('current-season-token-001')$$,
  $$values ('active'::text, 'Dieciséis TEST'::text, 'Ana'::text, 2, '2027/2028'::text)$$,
  'an active card'
);
select results_eq(
  $$select state, season_name from public.validate_card('old-season-token-0000001')$$,
  $$values ('not_current'::text, '2026/2027'::text)$$,
  'a card of a previous season is not valid now'
);
select is_empty($$select 1 from public.validate_card('abc123')$$, 'an invented token finds nothing');
select is(
  (select count(*)::int from information_schema.routines r
   where r.routine_name = 'validate_card'),
  1,
  'validation returns no phone, email, birth date or payments (fixed columns)'
);

reset role;
set local role anon;
select throws_ok($$select * from public.validate_card('current-season-token-001')$$, '42501', null,
  'the public cannot call the RPC directly (only through the Edge Function)');

reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"b7000000-0000-0000-0000-000000000002","role":"authenticated"}';
select throws_ok($$select public.regenerate_card_token('f7000000-0000-0000-0000-000000000027')$$, '42501', null,
  'members cannot regenerate cards');

set local request.jwt.claims = '{"sub":"b7000000-0000-0000-0000-000000000001","role":"authenticated"}';
select lives_ok($$select public.regenerate_card_token('f7000000-0000-0000-0000-000000000027')$$,
  'the admin regenerates the card');

reset role;
set local role service_role;
select is_empty($$select 1 from public.validate_card('current-season-token-001')$$,
  'the old QR stops working');
reset role;
select ok(
  (select card_token <> 'current-season-token-001' and length(card_token) = 22
   from public.season_memberships where id = 'f7000000-0000-0000-0000-000000000027'),
  'a new random token was issued'
);

select * from finish();
rollback;
