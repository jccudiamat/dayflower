-- Fix: 42501 permission denied for table pairs.
-- RLS policies only filter rows — the authenticated role still needs
-- table-level grants. This project lacks the usual defaults, so grant
-- explicitly (and set defaults so future tables get them automatically).

grant usage on schema public to authenticated;

grant select, insert, update on public.users to authenticated;
grant select, insert, update, delete on public.pairs to authenticated;

-- Future tables created by postgres (SQL editor) get grants automatically.
alter default privileges in schema public
  grant select, insert, update, delete on tables to authenticated;
