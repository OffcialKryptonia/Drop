-- Admin-managed email templates, their change history, and an email delivery log.
-- Separate from the push tables (app.push_*) on purpose: the channels have different content, limits and retry rules.
-- Both share the Worker's variable engine conventions and the Admin audit log (who changed what).
-- Built-in (system) templates are NOT inserted here: the Worker creates any that are missing from its own catalogue
-- (worker/src/lib/email-templates.ts) the first time Admin opens the page, and never overwrites an edit.
-- Until then, and whenever this migration has not run, the password-reset email uses its built-in text as before.

create table app.email_templates (
  id            bigserial primary key,
  key           text not null check (length(key) <= 80 and key ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$'),
  name          text not null check (length(btrim(name)) between 2 and 120),
  category      text not null check (length(category) between 2 and 40),
  audience      text not null check (audience in ('passenger', 'driver', 'system')),
  subject       text not null check (length(btrim(subject)) between 1 and 150),
  preheader     text check (preheader is null or length(preheader) <= 150),   -- the grey preview line inboxes show after the subject
  html_body     text not null check (length(btrim(html_body)) between 1 and 40000),
  text_body     text not null check (length(btrim(text_body)) between 1 and 20000),
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
create unique index email_templates_key_uq on app.email_templates (key) where deleted_at is null;
create index email_templates_filter_idx on app.email_templates (status, category, audience) where deleted_at is null;
alter table app.email_templates enable row level security;

create trigger email_templates_touch before update on app.email_templates
  for each row execute function app.touch_updated_at();

-- Every saved edit, so a change can be inspected and an old version restored by copying it back.
create table app.email_template_versions (
  id           bigserial primary key,
  template_id  bigint not null references app.email_templates (id) on delete cascade,
  version      integer not null,
  snapshot     jsonb not null,
  note         text,
  changed_by   bigint references app.users (id) on delete set null,
  created_at   timestamptz not null default now(),
  unique (template_id, version)
);
alter table app.email_template_versions enable row level security;

-- One row per recipient per email. Subject and bodies are what was sent. Emails that carry a code or a secure link
-- (password reset, verification, OTP) keep a masked subject and NO body, and are never retried, because the text cannot be rebuilt.
create table app.email_deliveries (
  id               bigserial primary key,
  template_id      bigint references app.email_templates (id) on delete set null,
  template_key     text not null,
  is_test          boolean not null default false,
  sent_by          bigint references app.users (id) on delete set null,   -- the admin, for a test send
  user_id          bigint references app.users (id) on delete set null,
  to_email         text not null,
  ride_id          bigint,
  subject          text not null,
  html_body        text,
  text_body        text,
  sensitive        boolean not null default false,
  status           text not null check (status in ('queued', 'sent', 'failed', 'skipped')),
  reason           text,                                           -- why it failed or was skipped, in plain words
  provider_status  integer,                                        -- HTTP status the email provider answered with
  attempts         integer not null default 0,
  retryable        boolean not null default false,
  next_retry_at    timestamptz,
  provider_id      text,                                           -- provider message id: accepted by the provider, not proof of inbox delivery
  idempotency_key  uuid not null,                                  -- sent to the provider so a retry cannot deliver twice
  dedupe_key       text,
  dedupe_bucket    bigint,
  created_at       timestamptz not null default now(),
  sent_at          timestamptz
);
-- The same email to the same person inside one time bucket is sent once.
create unique index email_deliveries_dedupe_uq on app.email_deliveries (dedupe_key, dedupe_bucket)
  where dedupe_key is not null and not is_test;
create index email_deliveries_created_idx  on app.email_deliveries (created_at desc);
create index email_deliveries_status_idx   on app.email_deliveries (status, created_at desc);
create index email_deliveries_template_idx on app.email_deliveries (template_key, created_at desc);
create index email_deliveries_user_idx     on app.email_deliveries (user_id, created_at desc);
create index email_deliveries_retry_idx    on app.email_deliveries (next_retry_at) where status = 'failed' and retryable;
alter table app.email_deliveries enable row level security;
