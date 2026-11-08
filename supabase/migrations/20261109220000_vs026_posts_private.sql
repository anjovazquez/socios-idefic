-- VS-026: the blog is private (RF-023). Besides RLS, anonymous users get no
-- privileges at all on posts.
revoke all on table public.posts from anon;
