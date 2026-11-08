begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

insert into auth.users (id, email, aud, role) values
  ('b1000000-0000-0000-0000-000000000001', 'admin10@test.com', 'authenticated', 'authenticated'),
  ('b1000000-0000-0000-0000-000000000002', 'luis10@test.com', 'authenticated', 'authenticated'),
  ('b1000000-0000-0000-0000-000000000003', 'nuevo10@test.com', 'authenticated', 'authenticated'),
  ('b1000000-0000-0000-0000-000000000004', 'admin10b@test.com', 'authenticated', 'authenticated');
insert into public.clubs (id, name, code) values
  ('d1000000-0000-0000-0000-000000000001', 'Diez TEST', 'DIEZTEST'),
  ('d1000000-0000-0000-0000-000000000002', 'Diez B TEST', 'DIEZBTEST');
insert into public.club_memberships (id, user_id, club_id, role, member_number) values
  ('e1000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000001', 'club_admin', 1),
  ('e1000000-0000-0000-0000-000000000002', 'b1000000-0000-0000-0000-000000000002', 'd1000000-0000-0000-0000-000000000001', 'member', 120),
  ('e1000000-0000-0000-0000-000000000004', 'b1000000-0000-0000-0000-000000000004', 'd1000000-0000-0000-0000-000000000002', 'club_admin', 1);
insert into public.club_invitations (id, club_id, email, first_name) values
  ('f1000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000001', 'nuevo10@test.com', 'Nuevo'),
  ('f1000000-0000-0000-0000-000000000002', 'd1000000-0000-0000-0000-000000000002', 'luis10@test.com', 'Luis');

-- Automatic numbers (server side)
select public.attach_invited_member('f1000000-0000-0000-0000-000000000001',
                                    'b1000000-0000-0000-0000-000000000003', 'invited');
select public.attach_invited_member('f1000000-0000-0000-0000-000000000002',
                                    'b1000000-0000-0000-0000-000000000002', 'active');
select is(
  (select member_number from public.club_memberships
   where user_id = 'b1000000-0000-0000-0000-000000000003'),
  121,
  'a new member gets the next number of the club'
);
select is(
  (select member_number from public.club_memberships
   where user_id = 'b1000000-0000-0000-0000-000000000002'
     and club_id = 'd1000000-0000-0000-0000-000000000002'),
  2,
  'numbers are independent per club (Luis is 120 in one club and 2 in the other)'
);

set local role authenticated;
set local request.jwt.claims = '{"sub":"b1000000-0000-0000-0000-000000000001","role":"authenticated"}';
select lives_ok(
  $$select public.set_member_number('e1000000-0000-0000-0000-000000000002', 7)$$,
  'the admin changes Luis''s number'
);
select results_eq(
  $$select member_number from public.get_club_members('d1000000-0000-0000-0000-000000000001')
    where email = 'luis10@test.com'$$,
  array[7],
  'Luis now has number 7 in this club'
);
select throws_ok(
  $$select public.set_member_number('e1000000-0000-0000-0000-000000000002', 1)$$,
  'P0001', null, 'a number already taken is rejected'
);
select throws_ok(
  $$select public.set_member_number('e1000000-0000-0000-0000-000000000002', 0)$$,
  '22023', null, 'numbers must be positive'
);
select throws_ok(
  $$select public.set_member_number('e1000000-0000-0000-0000-000000000004', 9)$$,
  '42501', null, 'an admin cannot change numbers of another club'
);
reset role;
select is(
  (select payload ->> 'to' from public.audit_log where action = 'member_number_changed'),
  '7',
  'the change is audited'
);

-- The member
set local role authenticated;
set local request.jwt.claims = '{"sub":"b1000000-0000-0000-0000-000000000002","role":"authenticated"}';
select throws_ok(
  $$select public.set_member_number('e1000000-0000-0000-0000-000000000002', 1000)$$,
  '42501', null, 'a member cannot change their own number'
);
select throws_ok(
  $$update public.club_memberships set member_number = 1000 where user_id = 'b1000000-0000-0000-0000-000000000002'$$,
  '42501', null, 'nor update it directly'
);

select * from finish();
rollback;
