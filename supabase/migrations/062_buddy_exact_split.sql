-- Applied automatically by the Deploy web workflow (supabase/migrations/README.md).
-- Buddy expenses get the squad's two typed-amount splits:
--   exact   type what each of you pays
--   custom  tick who's in, then type what each pays (one of you alone
--           in it pays it all)
-- 061 only allowed 'custom', used for "type both amounts". Those rows stay
-- 'custom' — with both of you in, it's the same split. save_buddy_expense
-- (061) already checks the shares add up to the amount for any split, so
-- only the allowed values change.
alter table public.buddy_expenses
  drop constraint if exists buddy_expenses_split_mode_check;
alter table public.buddy_expenses
  add constraint buddy_expenses_split_mode_check
  check (split_mode in ('equal', 'exact', 'custom', 'percent', 'shares'));
