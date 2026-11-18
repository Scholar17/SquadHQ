# Supabase migrations

SQL files here run **automatically on the live database** when they're pushed
to `main` (the "Deploy web" GitHub Action), before the web app is built and
deployed.

- **Name them in order**: `060_personal_expenses.sql`, `061_...`. They run
  oldest name first, and only letters, digits, `_`, `.` and `-` are allowed.
- **Each file runs once.** `ci.applied_migrations` records what has run. To
  change something already applied, add a new file. Editing the old one does
  nothing.
- **All or nothing.** Each file runs in one transaction. If it fails, nothing
  from it is kept, the deploy stops, and the next push retries it. So don't use
  statements that can't run in a transaction (e.g. `create index concurrently`).
- **Make them safe to run again** (`if not exists`, `create or replace`,
  `drop ... if exists`), like the older files in `supabase/sql/`.

`supabase/sql/` (001–059) is the older history, run by hand and kept out of
git.
