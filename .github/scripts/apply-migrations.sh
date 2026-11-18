#!/usr/bin/env bash
# Applies each supabase/migrations/*.sql not applied yet to the live
# Supabase project, oldest name first (so number them: 060_..., 061_...).
#
# - ci.applied_migrations records what ran (the ci schema isn't exposed by
#   the API). A file runs once; edit an applied one and it won't run again,
#   so add a new file instead.
# - Each file runs in one transaction together with its record: if it
#   fails, nothing from it is kept, the job fails (so the deploy stops),
#   and the next push tries it again. So no `create index concurrently`
#   or other statements that can't run in a transaction.
#
# Needs SUPABASE_ACCESS_TOKEN (Database read + write) and PROJECT_REF.
set -euo pipefail
shopt -s nullglob

files=(supabase/migrations/*.sql)
if [ ${#files[@]} -eq 0 ]; then
  echo "No migrations in supabase/migrations."
  exit 0
fi
if [ -z "${SUPABASE_ACCESS_TOKEN:-}" ]; then
  echo "::error::SUPABASE_ACCESS_TOKEN secret is missing"
  exit 1
fi

query() {
  supabase db query --remote="$PROJECT_REF" --agent=no --output-format json "$@"
}

# Rows from either output shape: [...] or {"rows": [...]}.
rows='if type == "array" then . else .rows end'

query --yes "
  create schema if not exists ci;
  revoke all on schema ci from public, anon, authenticated;
  create table if not exists ci.applied_migrations (
    name text primary key,
    applied_at timestamptz not null default now()
  );
" >/dev/null

applied=$(query --read-only "select name from ci.applied_migrations" | jq -r "$rows | .[].name")

ran=0
while IFS= read -r file; do
  name=$(basename "$file")
  if ! [[ "$name" =~ ^[A-Za-z0-9_.-]+\.sql$ ]]; then
    echo "::error file=$file::Migration names may only use letters, digits, _ . and -"
    exit 1
  fi
  if grep -qxF "$name" <<<"$applied"; then
    echo "Already applied: $name"
    continue
  fi
  wrapped=$(mktemp)
  {
    echo "begin;"
    cat "$file"
    echo
    echo "insert into ci.applied_migrations (name) values ('$name');"
    echo "commit;"
  } >"$wrapped"
  echo "::group::Applying $name"
  query --yes -f "$wrapped"
  echo "::endgroup::"
  rm -f "$wrapped"
  ran=$((ran + 1))
done < <(printf '%s\n' "${files[@]}" | sort)

echo "Applied $ran new migration(s)."
