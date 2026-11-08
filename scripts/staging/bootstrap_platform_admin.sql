-- Run ONCE in the SQL editor of the staging project, after creating the user
-- in Authentication → Users → "Add user" (email + password, auto confirm).
-- Replace the email. Never run the local seed against staging.

insert into public.platform_admins (user_id)
select id from public.profiles where email = lower('TU-EMAIL@ejemplo.com')
on conflict do nothing;

-- Check:
select p.email, pa.created_at
from public.platform_admins pa
join public.profiles p on p.id = pa.user_id;
