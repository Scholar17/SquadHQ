// Keeps a rolling year of Squad HQ history.
//
// Run on the 1st of every month by pg_cron, or by hand with
// `select public.run_retention_now();` (supabase/sql/030_data_retention.sql).
// run_retention_cleanup() removes rows older than a year — carrying unpaid
// squad debts over so balances don't change — and returns the payment slip
// files nothing points to any more; this deletes those from Storage (SQL
// can't).
//
// Secrets: reuses PUSH_CRON_SECRET (same project, same x-cron-secret
// header as push-dispatcher). SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY
// are provided automatically.
//
// Deploy with JWT verification OFF: pg_cron calls it without a JWT, and
// the x-cron-secret check below is what guards it.

import { createClient } from "npm:@supabase/supabase-js@2";

type Result = { slip_paths: string[] } & Record<string, unknown>;

Deno.serve(async (request) => {
  // Refuse outright if the secret isn't set — otherwise a missing header
  // would "match" a missing secret.
  const cronSecret = Deno.env.get("PUSH_CRON_SECRET");
  if (!cronSecret || request.headers.get("x-cron-secret") !== cronSecret) {
    return new Response("Forbidden", { status: 403 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data, error } = await supabase.rpc("run_retention_cleanup");
  if (error) return Response.json({ error: error.message }, { status: 500 });
  const { slip_paths: paths, ...counts } = data as Result;

  // Storage takes up to 1,000 paths per call; stay well under.
  let removed = 0;
  for (let i = 0; i < paths.length; i += 100) {
    const batch = paths.slice(i, i + 100);
    const { error: storageError } = await supabase.storage.from("payment-slips").remove(batch);
    if (storageError) {
      return Response.json(
        { ...counts, slip_files_removed: removed, error: storageError.message },
        { status: 500 },
      );
    }
    removed += batch.length;
  }

  console.log("retention-cleanup", { ...counts, slip_files_removed: removed });
  return Response.json({ ...counts, slip_files_removed: removed });
});
