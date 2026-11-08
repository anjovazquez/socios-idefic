begin;
create extension if not exists pgtap with schema extensions;
select plan(2);

select has_schema('public', 'public schema exists');
select ok(
  (select count(*) from auth.users) >= 0,
  'auth schema is reachable'
);

select * from finish();
rollback;
