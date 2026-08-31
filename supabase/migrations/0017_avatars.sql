-- Dayflower — flower avatars.
--
-- `users` had no avatar at all: every surface drew the first initial on the
-- brand gradient. An avatar here is a **flower id**, not an uploaded image —
-- no Storage, no moderation, no upload failure path, and it fits an app whose
-- whole vocabulary is already flowers.
--
-- Run in the Supabase SQL editor as one script. Safe to re-run.

-- Which flower stands in for you. Null means "never chosen", which is what
-- lets the app fall back to the gender default instead of overwriting a
-- deliberate pick with one. See AvatarFlower.forUser in the Dart side.
alter table public.users
  add column if not exists avatar text;

-- Only used to choose the *default* avatar (daisy / tulip). Nullable and
-- free-text rather than an enum: nobody should be blocked from onboarding by
-- it, and the app treats anything it doesn't recognise as "unset".
alter table public.users
  add column if not exists gender text;

-- RLS is unchanged: 0001's "users_select_self_or_partner" already covers
-- reading a partner's avatar, and the self-update policy covers changing
-- your own. Nothing to add.
