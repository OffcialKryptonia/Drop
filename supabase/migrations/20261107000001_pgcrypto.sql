-- Password hashing runs in the database (see worker/src/auth/password.ts). Supabase already ships
-- pgcrypto; this makes sure it exists in the "extensions" schema on any fresh database too.
create extension if not exists pgcrypto with schema extensions;
