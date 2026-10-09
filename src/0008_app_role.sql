-- Phase 2: the RLS policies added since 0001_init.sql have never actually
-- been enforced. The app's only Postgres role, clarityadmin, both owns
-- every table (table owners bypass RLS by default unless FORCE ROW LEVEL
-- SECURITY is set — it isn't, anywhere) AND has BYPASSRLS (which bypasses
-- RLS unconditionally, FORCE or not). Every set_config('app.current_client_id',
-- ...) call in dashboard/lib/db.ts has been a no-op: confirmed empirically —
-- querying `clients` through the app's real connection string with no
-- session variables set at all (the documented "fail closed, zero rows"
-- case) returned every row anyway.
--
-- Fix: a second, least-privileged role for the app to connect as at
-- runtime. It owns nothing and has no bypass attribute, so RLS policies
-- apply to it automatically — no FORCE ROW LEVEL SECURITY needed, that
-- only ever mattered for the owner. clarityadmin keeps running migrations
-- (it legitimately needs schema-owner rights); this role is query-only.
--
-- Password is intentionally not set here — a git-tracked migration file is
-- not where a real credential belongs. Rotate it immediately after this
-- runs: `alter role clarity_app with password '<generated>';`, then update
-- the postgres-connection-string Key Vault secret to match. Until rotated
-- this role can't log in at all (no usable password), which is the safe
-- failure direction.
create role clarity_app with login nosuperuser nocreatedb nocreaterole nobypassrls;

grant usage on schema public to clarity_app;
grant select, insert, update, delete on all tables in schema public to clarity_app;

-- So future migrations (always run as clarityadmin) don't need a manual
-- grant step added for every new table.
alter default privileges for role clarityadmin in schema public
  grant select, insert, update, delete on tables to clarity_app;
