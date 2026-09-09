-- Bypassing RLS does not grant table access. The push sender needs both.
grant select on public.pairs, public.users, public.device_tokens to service_role;
grant delete on public.device_tokens to service_role;
