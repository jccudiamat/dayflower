-- Picking a mood tells your partner.
--
-- Run as one script. Safe to re-run. Needs the `push` function that knows
-- the "mood" kind deployed FIRST: an older one describes it as "sent you a
-- message".
--
-- Since 0024 a mood has reached the other phone, but only as a value that
-- is there when they happen to look. Now choosing one, or changing it, is
-- news: a line in their notifications list (an activity), and a push, so a
-- phone with the app closed hears about it too.
--
-- ⚠️ **Collapsed, not throttled.** Somebody tapping through the chips to
-- find the right one changes their mood three times in as many seconds.
-- Dropping the later changes would announce a mood they moved away from,
-- so every change is announced, and a change within ten minutes of the
-- last one rewrites that activity instead of adding a second. On the phone
-- the notification shares one id, so the newest replaces the rest.
--
-- ⚠️ **Picking the same mood on a new day counts.** A mood is today's
-- (UserProfile.freshMood): yesterday's "happy" has already gone blank on
-- their screen, so choosing "happy" again this morning is news even though
-- the column did not change. Days are the setter's, in their own zone, as
-- freshMood judges them.

create or replace function public.tg_mood_shared()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_pair uuid;
  v_emoji text;
  v_title text;
  v_zone text := coalesce(nullif(new.timezone, ''), 'UTC');
  v_recent uuid;
  v_url text;
  v_secret text;
begin
  -- Cleared is not news; neither is saving the same mood again today.
  if new.mood is null or new.mood = '' or new.mood_at is null then
    return new;
  end if;
  if new.mood is not distinct from old.mood
     and old.mood_at is not null
     and (old.mood_at at time zone v_zone)::date
       = (new.mood_at at time zone v_zone)::date then
    return new;
  end if;

  select p.id into v_pair
    from public.pairs p
   where (p.user_a = new.id or p.user_b = new.id)
     and p.user_a is not null and p.user_b is not null
   limit 1;
  -- Nobody to tell yet.
  if v_pair is null then
    return new;
  end if;

  -- The app's Mood enum, in the only words the database needs. A mood a
  -- newer build adds still gets a line, with a sparkle for its face.
  v_emoji := case new.mood
    when 'happy' then '😊'
    when 'loved' then '🥰'
    when 'calm' then '😌'
    when 'low' then '😔'
    when 'stressed' then '😤'
    when 'tired' then '😴'
    else '✨'
  end;
  v_title := 'Feeling ' || lower(new.mood);

  select a.id into v_recent
    from public.activities a
   where a.pair_id = v_pair
     and a.actor_id = new.id
     and a.kind = 'mood_set'
     and a.created_at > now() - interval '10 minutes'
   order by a.created_at desc
   limit 1;

  if v_recent is not null then
    -- ⚠️ An update, not a delete and insert. Realtime cannot deliver a
    -- delete of this table to the other phone (its replica identity is the
    -- key alone, so the policy has no pair to check), and the old line
    -- would sit there beside the new one until the feed was rebuilt.
    update public.activities
       set title = v_title,
           emoji = v_emoji,
           meta = jsonb_build_object('mood', new.mood),
           created_at = now()
     where id = v_recent;
  else
    -- No subject, so log_activity's own thirty-minute dedupe (keyed on the
    -- subject) stays out of it: that would swallow a change of heart.
    perform public.log_activity(
      v_pair, new.id, 'mood_set', v_title, v_emoji, null,
      jsonb_build_object('mood', new.mood));
  end if;

  -- The push, exactly as 0046 sends a heartbeat's. Not configured is a
  -- normal state, not an error.
  select decrypted_secret into v_url
    from vault.decrypted_secrets where name = 'push_url';
  select decrypted_secret into v_secret
    from vault.decrypted_secrets where name = 'push_secret';
  if v_url is null or v_secret is null then
    return new;
  end if;

  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-push-secret', v_secret
    ),
    body := jsonb_build_object(
      'message_id', null,
      'pair_id', v_pair,
      'sender_id', new.id,
      'kind', 'mood',
      'call_mode', null,
      'mood', new.mood
    ),
    timeout_milliseconds := 4000
  );

  return new;
exception when others then
  -- 🔴 A mood must always save. The news of it is worth less than the
  -- mood itself, so nothing here is allowed to roll the update back.
  return new;
end $$;

drop trigger if exists users_mood_shared on public.users;
create trigger users_mood_shared
  after update of mood, mood_at on public.users
  for each row
  execute function public.tg_mood_shared();
