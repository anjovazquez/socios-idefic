begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

-- A club with 90 active members (paid 50 €) and 10 pending (100 € each).
insert into public.clubs (id, name, code) values ('d0310000-0000-0000-0000-000000000001', 'Treintayuno TEST', 'TREINTAYUNOTEST');
insert into public.seasons (id, club_id, name, starts_on, ends_on, default_fee_cents, status) values
  ('a0310000-0000-0000-0000-000000000026', 'd0310000-0000-0000-0000-000000000001', '2026/2027', '2026-09-01', '2027-08-31', 5000, 'active');
insert into auth.users (id, email, aud, role)
select ('b0310000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid, 'm' || n || '@t31.com', 'authenticated', 'authenticated'
from generate_series(0, 102) n;
alter table public.club_memberships disable trigger club_memberships_join_active_season;
insert into public.club_memberships (id, user_id, club_id, member_number, role, status, auto_renew)
select ('e0310000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid,
       ('b0310000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid,
       'd0310000-0000-0000-0000-000000000001', n + 1,
       case when n = 0 then 'club_admin' else 'member' end,
       case when n between 101 and 102 then 'invited' else 'active' end,
       n between 1 and 30
from generate_series(0, 102) n;
alter table public.club_memberships enable trigger club_memberships_join_active_season;
-- n 1..90 active season members, 91..100 pending; n 0 (admin) not renewed.
insert into public.season_memberships (id, club_membership_id, season_id, fee_cents, status)
select ('f0310000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid,
       ('e0310000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid,
       'a0310000-0000-0000-0000-000000000026',
       case when n <= 90 then 5000 else 10000 end, 'pending_payment'
from generate_series(1, 100) n;
insert into public.payments (season_membership_id, amount_cents, concept, status, provider, method, paid_at)
select ('f0310000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid, 5000, 'Cuota', 'paid', 'manual', 'cash', now()
from generate_series(1, 90) n;
insert into public.posts (club_id, title, body, status, published_at) values
  ('d0310000-0000-0000-0000-000000000001', 'Vieja', 'x', 'published', now() - interval '9 days'),
  ('d0310000-0000-0000-0000-000000000001', 'Media', 'x', 'published', now() - interval '5 days'),
  ('d0310000-0000-0000-0000-000000000001', 'Nueva', 'x', 'published', now() - interval '1 day'),
  ('d0310000-0000-0000-0000-000000000001', 'Reciente', 'x', 'published', now() - interval '1 hour'),
  ('d0310000-0000-0000-0000-000000000001', 'Borrador', 'x', 'draft', null);

set local role authenticated;
set local request.jwt.claims = '{"sub":"b0310000-0000-0000-0000-000000000000","role":"authenticated"}';
select results_eq(
  $$select season_name, active_members, pending_members, not_renewed_members, invited_members,
           auto_renew_members, paid_cents, pending_cents
    from public.get_club_dashboard('d0310000-0000-0000-0000-000000000001')$$,
  $$values ('2026/2027'::text, 90, 10, 1, 2, 30, 450000::bigint, 100000::bigint)$$,
  '90 active, 10 pending, 1.000 € pending, 4.500 € collected'
);
select is(
  (select jsonb_path_query_array(latest_posts, '$[*].title') from public.get_club_dashboard('d0310000-0000-0000-0000-000000000001')),
  '["Reciente", "Nueva", "Media"]'::jsonb,
  'the 3 latest published posts, newest first'
);

set local request.jwt.claims = '{"sub":"b0310000-0000-0000-0000-000000000001","role":"authenticated"}';
select throws_ok(
  $$select * from public.get_club_dashboard('d0310000-0000-0000-0000-000000000001')$$,
  '42501', null, 'members do not see the dashboard'
);
reset role;
set local role anon;
select throws_ok(
  $$select * from public.get_club_dashboard('d0310000-0000-0000-0000-000000000001')$$,
  '42501', null, 'anonymous users neither'
);

select * from finish();
rollback;
