-- Dayflower — access tokens for the media server.
-- Run in the Supabase SQL editor, or: dart run tool/run_sql.dart <this file>
--
-- Safe to re-run. Additive only.
--
-- ## Why the token is minted in Postgres and not in an Edge Function
--
-- A LiveKit access token is a plain HS256 JWT signed with the project's API
-- secret. The secret can never reach the app — anyone with it can mint a
-- token for any room, and a Flutter web build ships its `.env` to the
-- browser. So something server-side has to sign.
--
-- The obvious answer is an Edge Function, and the reason it is not used here
-- is workflow: this project has no Supabase CLI step. Every schema change so
-- far has gone through the SQL editor or `tool/run_sql.dart`, and adding a
-- `supabase functions deploy` to the loop would mean a second deployment
-- path to keep in step for the sake of forty lines of signing.
--
-- `pgjwt` does exactly this in the database, behind the same RLS and the
-- same `authenticated` grant as everything else. If calls ever need
-- server-side logic beyond signing — recording, egress, webhooks — that is
-- the moment to move to an Edge Function, and this function is the thing to
-- port.

create extension if not exists pgjwt with schema extensions;

-- ── The secret ────────────────────────────────────────────────────────────
--
-- Vault, not a table: `vault.decrypted_secrets` is readable only by
-- postgres, so a definer function can reach the secret and nothing the app
-- can call ever can. A plain table would be one missing RLS policy away from
-- handing out the key to the entire media account.
--
-- 🔴 **This migration does not create the secret — you do, once**, with the
-- values from your LiveKit project (Settings → Keys):
--
--   select vault.create_secret('<API_SECRET>', 'livekit_api_secret');
--   select vault.create_secret('<API_KEY>',    'livekit_api_key');
--
-- To rotate later, `select vault.update_secret(id, '<new>')` — the function
-- reads by name, so nothing here changes.

-- ── The token ─────────────────────────────────────────────────────────────
--
-- Issues a join token for one room, to the caller, for six hours.
--
-- The membership check is the whole security model: the room name embeds a
-- pair id (`dayflower-v1-<pairId>`, see CallRepository.roomFor), and this
-- refuses to sign for a pair you do not belong to. Without it, any signed-in
-- user could derive any couple's room name and walk into their call.
create or replace function public.livekit_token(p_room text)
returns text
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := auth.uid();
  v_pair uuid;
  v_key text;
  v_secret text;
  v_name text;
  v_now bigint := extract(epoch from now())::bigint;
begin
  if v_uid is null then
    raise exception 'not signed in';
  end if;

  -- The room must name a pair, and it must be one of ours. Parsed rather
  -- than trusted: the room arrives from the client.
  --
  -- ⚠️ `substring` returns NULL for a non-match and `null::uuid` is NULL,
  -- not an error — so an exception handler around the cast never fires and
  -- the null falls through to the membership check below. The null test is
  -- what actually rejects a malformed room; the handler only catches a
  -- well-shaped room whose tail is not a uuid.
  begin
    v_pair := substring(p_room from '^dayflower-v1-(.+)$')::uuid;
  exception when others then
    v_pair := null;
  end;

  if v_pair is null then
    raise exception 'unrecognised room';
  end if;

  if not exists (
    select 1 from public.pairs p
     where p.id = v_pair
       and v_uid in (p.user_a, p.user_b)
  ) then
    raise exception 'not your room';
  end if;

  select decrypted_secret into v_key
    from vault.decrypted_secrets where name = 'livekit_api_key';
  select decrypted_secret into v_secret
    from vault.decrypted_secrets where name = 'livekit_api_secret';

  if v_key is null or v_secret is null then
    -- Distinct from every other failure here: this one means the operator
    -- has not finished setting calling up, not that the caller did anything
    -- wrong. The app turns it into "calling isn't switched on yet".
    raise exception 'calling not configured';
  end if;

  select coalesce(pet_name, display_name, 'Someone') into v_name
    from public.users where id = v_uid;

  return extensions.sign(
    json_build_object(
      'iss', v_key,
      'sub', v_uid::text,
      'name', v_name,
      'nbf', v_now - 10,          -- clock skew between phone and server
      'exp', v_now + 60 * 60 * 6, -- long enough to outlast any real call
      'video', json_build_object(
        'room', p_room,
        'roomJoin', true,
        'canPublish', true,
        'canSubscribe', true,
        'canPublishData', true
      )
    ),
    v_secret
  );
end $$;

revoke all on function public.livekit_token(text) from public;
grant execute on function public.livekit_token(text) to authenticated;

-- ⚠️ Grants again — RLS decides which rows, the grant decides whether the
-- role may call the thing at all. See PROGRESS.md § Supabase.
