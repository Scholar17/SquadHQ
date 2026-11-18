-- Applied automatically by the Deploy web workflow (supabase/migrations/README.md).
-- Personal expenses: a private spending tracker. One list per person
-- across all their squads — only its owner can see or change any of it,
-- and it never touches anyone's balance.
--   personal_expenses            what you spent (amount, title, category,
--                                when, note, receipt photo)
--   personal_expense_categories  your own categories, next to the
--                                built-in Food / Transport / Sports /
--                                Shopping / Bills / Other
--   personal_settings            the one currency your spending is in
-- Receipt photos go in the private payment-slips bucket under
-- personal/<your id>/. Kept until you delete them: the yearly retention
-- cleanup (030) doesn't touch these tables. Safe to run again.

create table if not exists public.personal_expense_categories (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  name text not null check (length(trim(name)) between 1 and 30),
  created_at timestamptz not null default now()
);

create unique index if not exists personal_expense_categories_owner_name
  on public.personal_expense_categories (owner_id, lower(trim(name)));

create table if not exists public.personal_expenses (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  title text not null check (length(trim(title)) between 1 and 80),
  amount numeric(12, 2) not null check (amount > 0),
  -- A built-in category; 'custom' when [custom_category_id] is set.
  category text not null
    check (category in ('food', 'transport', 'sports', 'shopping', 'bills', 'other', 'custom')),
  -- A deleted category leaves its expenses under Other.
  custom_category_id uuid references public.personal_expense_categories(id) on delete set null,
  spent_at timestamptz not null default now(),
  note text check (note is null or length(note) <= 500),
  receipt_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists personal_expenses_owner_spent
  on public.personal_expenses (owner_id, spent_at desc);

create table if not exists public.personal_settings (
  owner_id uuid primary key default auth.uid() references public.profiles(id) on delete cascade,
  currency text not null default 'thb' check (currency in ('thb', 'mmk')),
  updated_at timestamptz not null default now()
);

alter table public.personal_expense_categories enable row level security;
alter table public.personal_expenses enable row level security;
alter table public.personal_settings enable row level security;

-- Owner only, for everything.
drop policy if exists "personal_expense_categories_own" on public.personal_expense_categories;
create policy "personal_expense_categories_own" on public.personal_expense_categories
  for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists "personal_expenses_own" on public.personal_expenses;
create policy "personal_expenses_own" on public.personal_expenses
  for all to authenticated
  using (owner_id = auth.uid())
  with check (
    owner_id = auth.uid()
    -- Only your own categories.
    and (
      custom_category_id is null
      or exists (
        select 1 from public.personal_expense_categories c
        where c.id = custom_category_id and c.owner_id = auth.uid()
      )
    )
  );

drop policy if exists "personal_settings_own" on public.personal_settings;
create policy "personal_settings_own" on public.personal_settings
  for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

-- Receipt photos: payment-slips/personal/<owner id>/..., owner only.
drop policy if exists "personal_receipts_insert_own" on storage.objects;
create policy "personal_receipts_insert_own" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'payment-slips'
    and (storage.foldername(name))[1] = 'personal'
    and (storage.foldername(name))[2] = auth.uid()::text
  );

drop policy if exists "personal_receipts_select_own" on storage.objects;
create policy "personal_receipts_select_own" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'payment-slips'
    and (storage.foldername(name))[1] = 'personal'
    and (storage.foldername(name))[2] = auth.uid()::text
  );

drop policy if exists "personal_receipts_delete_own" on storage.objects;
create policy "personal_receipts_delete_own" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'payment-slips'
    and (storage.foldername(name))[1] = 'personal'
    and (storage.foldername(name))[2] = auth.uid()::text
  );
