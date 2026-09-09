-- pg_net installs http_post in the net schema, not extensions.net.
-- Preserve the existing trigger body and correct only the function reference.
do $$
begin
  execute replace(
    pg_get_functiondef('public.notify_push()'::regprocedure),
    'extensions.net.http_post',
    'net.http_post'
  );
end;
$$;
