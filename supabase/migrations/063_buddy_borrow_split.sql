-- Applied automatically by the Deploy web workflow (supabase/migrations/README.md).
-- Buddy expenses get a Borrow split: whoever paid lent it, so the other one
-- owes all of it back (their share is the whole amount, the payer's 0).
-- save_buddy_expense (061) already checks the shares add up to the amount,
-- so only the allowed values change.
alter table public.buddy_expenses
  drop constraint if exists buddy_expenses_split_mode_check;
alter table public.buddy_expenses
  add constraint buddy_expenses_split_mode_check
  check (split_mode in ('equal', 'exact', 'custom', 'percent', 'shares', 'borrow'));
