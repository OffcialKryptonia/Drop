-- Admin-managed push notification templates, their change history, and a delivery log.
-- Built-in (system) templates are NOT inserted here: the Worker creates any that are missing from its own event
-- catalogue (worker/src/lib/push-templates.ts) the first time Admin opens the page, and never overwrites an edit.
-- Until then, and whenever this migration has not run, pushes use the built-in text in the Worker, exactly as before.

create table app.push_templates (
  id            bigserial primary key,
  key           text not null check (length(key) <= 80 and key ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$'),
  name          text not null check (length(btrim(name)) between 2 and 120),
  category      text not null check (length(category) between 2 and 40),
  audience      text not null check (audience in ('passenger', 'driver', 'all')),
  title         text not null check (length(btrim(title)) between 1 and 80),
  body          text not null check (length(btrim(body)) between 1 and 300),
  image_url     text check (image_url is null or (image_url ~ '^https://[^\s]+$' and length(image_url) <= 500)),
  deep_link     text check (deep_link is null or length(deep_link) <= 300),
  action_label  text check (action_label is null or length(action_label) between 1 and 30),
  variables     text[] not null default '{}',                    -- placeholders the text uses (worker-derived, never trusted from the client)
  status        text not null default 'inactive' check (status in ('active', 'inactive', 'archived')),
  is_system     boolean not null default false,                  -- built-in: can be edited, deactivated and archived, never deleted
  version       integer not null default 1,
  created_by    bigint references app.users (id) on delete set null,
  updated_by    bigint references app.users (id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz
);
create unique index push_templates_key_uq on app.push_templates (key) where deleted_at is null;
create index push_templates_filter_idx on app.push_templates (status, category, audience) where deleted_at is null;
alter table app.push_templates enable row level security;

create trigger push_templates_touch before update on app.push_templates
  for each row execute function app.touch_updated_at();

-- Every saved edit, so a change can be inspected (the Admin audit log also records who changed what).
create table app.push_template_versions (
  id           bigserial primary key,
  template_id  bigint not null references app.push_templates (id) on delete cascade,
  version      integer not null,
  snapshot     jsonb not null,
  note         text,
  changed_by   bigint references app.users (id) on delete set null,
  created_at   timestamptz not null default now(),
  unique (template_id, version)
);
alter table app.push_template_versions enable row level security;

-- One row per recipient per notification. title/body are what was sent; values of sensitive variables
-- (pickup code, wallet balance) are masked here, and such rows are never retried because the text cannot be rebuilt.
create table app.push_deliveries (
  id               bigserial primary key,
  template_id      bigint references app.push_templates (id) on delete set null,
  template_key     text not null,
  is_test          boolean not null default false,
  sent_by          bigint references app.users (id) on delete set null,   -- the admin, for a test send
  user_id          bigint references app.users (id) on delete set null,
  ride_id          bigint,
  title            text not null,
  body             text not null,
  deep_link        text,
  status           text not null check (status in ('queued', 'sent', 'failed', 'skipped')),
  reason           text,                                           -- why it failed or was skipped
  attempts         integer not null default 0,
  retryable        boolean not null default false,
  next_retry_at    timestamptz,
  provider_id      text,                                           -- OneSignal notification id: accepted by OneSignal, not proof of device delivery
  idempotency_key  uuid not null,                                  -- shared by the rows of one OneSignal request, so a retry cannot double-send
  dedupe_key       text,
  dedupe_bucket    bigint,
  created_at       timestamptz not null default now(),
  sent_at          timestamptz
);
-- The same notification to the same person inside one time bucket is sent once.
create unique index push_deliveries_dedupe_uq on app.push_deliveries (dedupe_key, dedupe_bucket)
  where dedupe_key is not null and not is_test;
create index push_deliveries_created_idx  on app.push_deliveries (created_at desc);
create index push_deliveries_status_idx   on app.push_deliveries (status, created_at desc);
create index push_deliveries_template_idx on app.push_deliveries (template_key, created_at desc);
create index push_deliveries_user_idx     on app.push_deliveries (user_id, created_at desc);
create index push_deliveries_retry_idx    on app.push_deliveries (next_retry_at) where status = 'failed' and retryable;
alter table app.push_deliveries enable row level security;
