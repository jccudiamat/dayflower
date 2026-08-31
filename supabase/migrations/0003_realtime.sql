-- Enable realtime change events for tables the app subscribes to.
-- Supabase only streams tables explicitly added to this publication.
alter publication supabase_realtime add table public.pairs;
