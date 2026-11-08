begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

insert into auth.users (id, email, aud, role) values
  ('a9000000-0000-0000-0000-000000000001', 'socia9@test.com', 'authenticated', 'authenticated'),
  ('a9000000-0000-0000-0000-000000000002', 'otro9@test.com', 'authenticated', 'authenticated'),
  ('a9000000-0000-0000-0000-000000000003', 'admin9@test.com', 'authenticated', 'authenticated'),
  ('a9000000-0000-0000-0000-000000000004', 'adminotro9@test.com', 'authenticated', 'authenticated');
insert into public.clubs (id, name, code) values
  ('c9000000-0000-0000-0000-000000000001', 'Nueve TEST', 'NUEVETEST'),
  ('c9000000-0000-0000-0000-000000000002', 'Otro TEST', 'OTRO9TEST');
insert into public.club_memberships (user_id, club_id, role, member_number) values
  ('a9000000-0000-0000-0000-000000000001', 'c9000000-0000-0000-0000-000000000001', 'member', 2),
  ('a9000000-0000-0000-0000-000000000003', 'c9000000-0000-0000-0000-000000000001', 'club_admin', 1),
  ('a9000000-0000-0000-0000-000000000004', 'c9000000-0000-0000-0000-000000000002', 'club_admin', 1);

set local role authenticated;
set local request.jwt.claims = '{"sub":"a9000000-0000-0000-0000-000000000001","role":"authenticated"}';

select lives_ok(
  $$select public.update_my_profile('Socia', 'Nueve', '600 999 999', '1985-03-02',
      'a9000000-0000-0000-0000-000000000001/photo-1.jpg')$$,
  'the member updates her data and photo'
);
select results_eq(
  $$select first_name, phone, birth_date, photo_path, email from public.profiles$$,
  $$values ('Socia'::text, '600999999'::text, '1985-03-02'::date,
            'a9000000-0000-0000-0000-000000000001/photo-1.jpg'::text, 'socia9@test.com'::text)$$,
  'data saved; email unchanged'
);
select throws_ok(
  $$select public.update_my_profile('Socia', 'Nueve', null, current_date + 1, null)$$,
  '22023', null, 'future birth date is rejected'
);
select throws_ok(
  $$select public.update_my_profile('Socia', 'Nueve', null, null,
      'a9000000-0000-0000-0000-000000000002/photo.jpg')$$,
  '22023', null, 'a photo of another folder is rejected'
);
select throws_ok(
  $$update public.profiles set first_name = 'Hack' where id = 'a9000000-0000-0000-0000-000000000002'$$,
  '42501', null, 'profiles cannot be updated directly'
);
select lives_ok(
  $$insert into storage.objects (bucket_id, name, owner) values
    ('profile-photos', 'a9000000-0000-0000-0000-000000000001/photo-1.jpg', 'a9000000-0000-0000-0000-000000000001')$$,
  'the member uploads into her folder'
);
select throws_ok(
  $$insert into storage.objects (bucket_id, name) values
    ('profile-photos', 'a9000000-0000-0000-0000-000000000002/photo.jpg')$$,
  '42501', null, 'nobody uploads into another person folder'
);

-- Another member
set local request.jwt.claims = '{"sub":"a9000000-0000-0000-0000-000000000002","role":"authenticated"}';
select lives_ok(
  $$select public.update_my_profile('Otro', 'Nueve', null, null, null)$$,
  'update_my_profile only changes the caller profile'
);
reset role;
select is(
  (select first_name from public.profiles where id = 'a9000000-0000-0000-0000-000000000001'),
  'Socia',
  'the other person did not change her profile'
);
set local role authenticated;
set local request.jwt.claims = '{"sub":"a9000000-0000-0000-0000-000000000002","role":"authenticated"}';
select is_empty(
  $$select 1 from storage.objects where bucket_id = 'profile-photos'$$,
  'other members cannot see her photo'
);

-- Admin of her club
set local request.jwt.claims = '{"sub":"a9000000-0000-0000-0000-000000000003","role":"authenticated"}';
select isnt_empty(
  $$select 1 from storage.objects where bucket_id = 'profile-photos'$$,
  'the admin of her club can see her photo'
);

-- Admin of another club
set local request.jwt.claims = '{"sub":"a9000000-0000-0000-0000-000000000004","role":"authenticated"}';
select is_empty(
  $$select 1 from storage.objects where bucket_id = 'profile-photos'$$,
  'admins of other clubs cannot see her photo'
);

-- Anonymous
reset role;
set local role anon;
select is_empty(
  $$select 1 from storage.objects where bucket_id = 'profile-photos'$$,
  'the bucket is private'
);

select * from finish();
rollback;
