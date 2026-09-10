-- Gifts, moved off the shelf and onto the server.
--
-- 🔴 The catalogue was a `const` list compiled into the APK. Every price
-- correction, every dead listing and — the reason this exists — every
-- affiliate link was a new build and an update prompt on both phones, and
-- anyone who did not update kept tapping links that earn nothing. Affiliate
-- links expire, get revoked and rotate with campaigns; a catalogue that can
-- only change at build time cannot carry them.
--
-- The bundled list stays in the app as the offline fallback, so the screen
-- still fills with something on a dead network or a fresh install.

create table if not exists public.gift_products (
  -- ⚠️ Text, not uuid, and it matches the bundled asset name: the app looks
  -- for assets/images/gifts/<id>.jpg when image_url is null. Renaming an id
  -- silently drops that product back to the placeholder icon.
  id            text primary key,
  name          text not null,
  merchant      text not null,
  category      text not null,

  -- Whole pesos. Observations, not live quotes — the app says so.
  price         integer not null,
  price_max     integer,
  voucher       boolean not null default false,

  -- Which half of the couple it suits. Free text so the filter chips can
  -- grow without a migration.
  recipients    text[] not null default '{}',

  -- 🔴 **This is the affiliate link.** Whatever is here is what opens.
  url           text not null,

  -- Null means "use the bundled asset for this id". Anything else is
  -- loaded over the network, so a product added from the dashboard can
  -- have a picture without shipping a build.
  image_url     text,
  image_source  text,

  -- Display order, low first. Ties break on name.
  sort          integer not null default 0,

  -- ⚠️ Retire a listing by clearing this, not by deleting the row. A delete
  -- loses the click history that says whether it was ever worth carrying.
  active        boolean not null default true,

  updated_at    timestamptz not null default now()
);

comment on table public.gift_products is
  'Gift catalogue. Edited from the Supabase dashboard or tool/sync_gifts.dart; '
  'the app has no write path. `url` is the affiliate link.';

alter table public.gift_products enable row level security;

-- Everyone signed in reads the catalogue. Nobody writes it: there is
-- deliberately no insert/update/delete policy, so the only ways in are the
-- dashboard and the service-role key, and a compromised phone cannot
-- rewrite a link to point somewhere else.
drop policy if exists gift_products_read on public.gift_products;
create policy gift_products_read on public.gift_products
  for select to authenticated using (true);

create index if not exists gift_products_active_sort
  on public.gift_products (active, sort, name);

-- ── Which gifts actually get tapped ────────────────────────────────
--
-- The only way to know whether a listing earns its place. Rows rather than a
-- counter: a counter cannot tell you a product died in March.

create table if not exists public.gift_clicks (
  id          uuid primary key default gen_random_uuid(),
  product_id  text not null,
  user_id     uuid not null references public.users (id) on delete cascade,
  clicked_at  timestamptz not null default now()
);

comment on table public.gift_clicks is
  'One row per gift opened. Personal data — see the privacy note in the '
  'website policy before this leaves the two of you.';

alter table public.gift_clicks enable row level security;

-- ⚠️ Own rows only, both ways. A gift someone looked at is personal, and
-- there is no feature that needs one half of a couple to see the other
-- half's browsing.
drop policy if exists gift_clicks_insert on public.gift_clicks;
create policy gift_clicks_insert on public.gift_clicks
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists gift_clicks_read on public.gift_clicks;
create policy gift_clicks_read on public.gift_clicks
  for select to authenticated using (user_id = auth.uid());

create index if not exists gift_clicks_product
  on public.gift_clicks (product_id, clicked_at desc);

-- ── Grants ─────────────────────────────────────────────────────────
--
-- 🔴 **RLS decides which rows; grants decide whether the table can be
-- touched at all.** A policy without a grant is "permission denied for
-- table", which reads like a policy problem and is not one — the same trap
-- migration 0036 hit with device_tokens. Tables created outside the normal
-- migration path do not always pick up the project's default privileges, so
-- both roles are named here explicitly.

grant select on public.gift_products to authenticated;
grant select, insert, update, delete on public.gift_products to service_role;

grant select, insert on public.gift_clicks to authenticated;
grant select on public.gift_clicks to service_role;
