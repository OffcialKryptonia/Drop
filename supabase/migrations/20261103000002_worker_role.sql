-- Drop database, migration 2: least-privilege login for the Cloudflare Worker.
--
-- The Worker connects (through Hyperdrive) as "hyperdrive_user", never as the
-- all-powerful "postgres" user. This role can only touch schema "app" (and use the
-- PostGIS types in "extensions"); it cannot reach Supabase's auth, storage or other
-- internal schemas.
--
-- BYPASSRLS lets it read and write the app tables, which have row level security on
-- and no policies (so anon/authenticated users get nothing). It has NO password here:
-- the owner sets it in the Supabase SQL editor, so the secret never lives in git.
--
--   alter role hyperdrive_user with password '<long random password>';

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'hyperdrive_user') then
    create role hyperdrive_user login bypassrls;
  end if;
end
$$;

alter role hyperdrive_user set search_path = app, extensions, public;
alter role hyperdrive_user set statement_timeout = '15s';
alter role hyperdrive_user set idle_in_transaction_session_timeout = '30s';

grant usage on schema app to hyperdrive_user;
grant usage on schema extensions to hyperdrive_user;
grant select, insert, update, delete on all tables in schema app to hyperdrive_user;
grant usage, select on all sequences in schema app to hyperdrive_user;

-- Tables and sequences created by future migrations are covered automatically.
alter default privileges in schema app
  grant select, insert, update, delete on tables to hyperdrive_user;
alter default privileges in schema app
  grant usage, select on sequences to hyperdrive_user;
