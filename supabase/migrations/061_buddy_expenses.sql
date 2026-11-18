-- Applied automatically by the Deploy web workflow (supabase/migrations/README.md).
-- Buddy expenses: a cost shared by just two members of a squad, with its
-- own 1-on-1 balance and settling — kept apart from the squad's balance
-- (like trips), in tables no squad-balance function reads. Only the two
-- of them can see it; either can add, edit, delete or settle.
--   buddy_expenses     one cost: who paid, each person's share (equal,
--                      custom, percent or shares), category, note, receipt
--   buddy_settlements  paying back: the one who owes says "I paid" (pending
--                      until the other confirms), or the one owed marks it
--                      received (confirmed straight away)
-- Pushes go to the other person; leaving or being removed from the squad
-- waits until your buddy balances there are settled.

-- A pair is stored low id first (person_a < person_b), so each pair's
-- rows line up whoever added them.
create table if not exists public.buddy_expenses (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  person_a uuid not null references public.profiles(id) on delete cascade,
  person_b uuid not null references public.profiles(id) on delete cascade,
  payer_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (length(trim(title)) between 1 and 80),
  category text not null default 'other',
  category_label text check (category_label is null or length(trim(category_label)) between 1 and 30),
  amount numeric(12, 2) not null check (amount > 0),
  split_mode text not null check (split_mode in ('equal', 'custom', 'percent', 'shares')),
  share_a numeric(12, 2) not null check (share_a >= 0),
  share_b numeric(12, 2) not null check (share_b >= 0),
  -- The % or shares typed, for a percent or shares split.
  weight_a numeric(10, 2) check (weight_a is null or weight_a >= 0),
  weight_b numeric(10, 2) check (weight_b is null or weight_b >= 0),
  spent_at timestamptz not null default now(),
  note text check (note is null or length(note) <= 500),
  receipt_path text,
  created_by uuid not null references public.profiles(id) on delete cascade,
  updated_by uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (person_a < person_b),
  check (payer_id in (person_a, person_b)),
  check (share_a + share_b = amount)
);

create index if not exists buddy_expenses_pair
  on public.buddy_expenses (team_id, person_a, person_b, spent_at desc);

create table if not exists public.buddy_settlements (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  from_id uuid not null references public.profiles(id) on delete cascade,
  to_id uuid not null references public.profiles(id) on delete cascade,
  amount numeric(12, 2) not null check (amount > 0),
  method text not null check (method in ('qr', 'bank', 'cash')),
  status text not null default 'pending' check (status in ('pending', 'confirmed', 'rejected')),
  slip_path text,
  reject_reason text check (reject_reason is null or length(reject_reason) <= 200),
  recorded_by uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  check (from_id <> to_id)
);

create index if not exists buddy_settlements_pair
  on public.buddy_settlements (team_id, from_id, to_id, created_at desc);

alter table public.buddy_expenses enable row level security;
alter table public.buddy_settlements enable row level security;

-- Reads: only the two of them. Writes go through the functions below.
drop policy if exists "buddy_expenses_select_pair" on public.buddy_expenses;
create policy "buddy_expenses_select_pair" on public.buddy_expenses
  for select to authenticated
  using (auth.uid() in (person_a, person_b));

drop policy if exists "buddy_settlements_select_pair" on public.buddy_settlements;
create policy "buddy_settlements_select_pair" on public.buddy_settlements
  for select to authenticated
  using (auth.uid() in (from_id, to_id));

-- What [p_debtor] owes [p_creditor] in [p_team_id] on buddy expenses,
-- after confirmed payments (negative: the other way round).
create or replace function public.buddy_owed(p_team_id uuid, p_debtor uuid, p_creditor uuid)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select
    coalesce((
      select sum(
        case
          when e.payer_id = p_creditor then
            case when e.person_a = p_debtor then e.share_a else e.share_b end
          else
            -(case when e.person_a = p_creditor then e.share_a else e.share_b end)
        end
      )
      from public.buddy_expenses e
      where e.team_id = p_team_id
        and e.person_a = least(p_debtor, p_creditor)
        and e.person_b = greatest(p_debtor, p_creditor)
    ), 0)
    - coalesce((
      select sum(s.amount) from public.buddy_settlements s
      where s.team_id = p_team_id and s.status = 'confirmed'
        and s.from_id = p_debtor and s.to_id = p_creditor
    ), 0)
    + coalesce((
      select sum(s.amount) from public.buddy_settlements s
      where s.team_id = p_team_id and s.status = 'confirmed'
        and s.from_id = p_creditor and s.to_id = p_debtor
    ), 0);
$$;

revoke execute on function public.buddy_owed(uuid, uuid, uuid) from public, anon, authenticated;

-- Adds ([p_id] null) or edits a buddy expense between the caller and
-- [p_buddy]. [p_share_me] / [p_share_buddy] are worked out in the app and
-- must add up to [p_amount].
create or replace function public.save_buddy_expense(
  p_id uuid,
  p_team_id uuid,
  p_buddy uuid,
  p_payer uuid,
  p_title text,
  p_category text,
  p_category_label text,
  p_amount numeric,
  p_split_mode text,
  p_share_me numeric,
  p_share_buddy numeric,
  p_weight_me numeric,
  p_weight_buddy numeric,
  p_spent_at timestamptz,
  p_note text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_a uuid := least(v_me, p_buddy);
  v_b uuid := greatest(v_me, p_buddy);
  v_me_is_a boolean := v_me < p_buddy;
  v_existing public.buddy_expenses;
  v_id uuid;
begin
  if v_me is null then
    raise exception 'You are signed out';
  end if;
  if p_buddy is null or p_buddy = v_me then
    raise exception 'Pick who you shared it with';
  end if;
  if public.squad_role(p_team_id) is null then
    raise exception 'Only squad members can add buddy expenses';
  end if;
  if not exists (
    select 1 from public.team_members where team_id = p_team_id and profile_id = p_buddy
  ) then
    raise exception 'They''re not in this squad';
  end if;
  if p_payer not in (v_me, p_buddy) then
    raise exception 'One of you must have paid';
  end if;
  if coalesce(p_share_me, -1) < 0 or coalesce(p_share_buddy, -1) < 0
     or round(p_share_me + p_share_buddy, 2) <> round(p_amount, 2) then
    raise exception 'Shares add up to %, not %', p_share_me + p_share_buddy, p_amount;
  end if;

  if p_id is not null then
    select * into v_existing from public.buddy_expenses
    where id = p_id and team_id = p_team_id;
    if not found or v_me not in (v_existing.person_a, v_existing.person_b) then
      raise exception 'This expense no longer exists';
    end if;
    if p_buddy not in (v_existing.person_a, v_existing.person_b) then
      raise exception 'A buddy expense stays between the same two people';
    end if;
  end if;

  if p_id is null then
    insert into public.buddy_expenses (
      team_id, person_a, person_b, payer_id, title, category, category_label, amount,
      split_mode, share_a, share_b, weight_a, weight_b, spent_at, note, created_by, updated_by
    )
    values (
      p_team_id, v_a, v_b, p_payer, trim(p_title), coalesce(p_category, 'other'),
      nullif(trim(p_category_label), ''), round(p_amount, 2), p_split_mode,
      round(case when v_me_is_a then p_share_me else p_share_buddy end, 2),
      round(case when v_me_is_a then p_share_buddy else p_share_me end, 2),
      case when v_me_is_a then p_weight_me else p_weight_buddy end,
      case when v_me_is_a then p_weight_buddy else p_weight_me end,
      coalesce(p_spent_at, now()), nullif(trim(p_note), ''), v_me, v_me
    )
    returning id into v_id;
  else
    update public.buddy_expenses
    set payer_id = p_payer,
        title = trim(p_title),
        category = coalesce(p_category, 'other'),
        category_label = nullif(trim(p_category_label), ''),
        amount = round(p_amount, 2),
        split_mode = p_split_mode,
        share_a = round(case when v_me_is_a then p_share_me else p_share_buddy end, 2),
        share_b = round(case when v_me_is_a then p_share_buddy else p_share_me end, 2),
        weight_a = case when v_me_is_a then p_weight_me else p_weight_buddy end,
        weight_b = case when v_me_is_a then p_weight_buddy else p_weight_me end,
        spent_at = coalesce(p_spent_at, spent_at),
        note = nullif(trim(p_note), ''),
        updated_by = v_me,
        updated_at = now()
    where id = p_id;
    v_id := p_id;
  end if;
  return v_id;
end;
$$;

grant execute on function public.save_buddy_expense(
  uuid, uuid, uuid, uuid, text, text, text, numeric, text, numeric, numeric, numeric, numeric,
  timestamptz, text
) to authenticated;

-- [p_path]: a photo already uploaded to payment-slips/buddy/..., or null
-- to take it off. Either of the two.
create or replace function public.set_buddy_expense_receipt(p_id uuid, p_path text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_path is not null and split_part(p_path, '/', 1) <> 'buddy' then
    raise exception 'Invalid receipt';
  end if;
  update public.buddy_expenses
  set receipt_path = p_path
  where id = p_id and auth.uid() in (person_a, person_b);
  if not found then
    raise exception 'This expense no longer exists';
  end if;
end;
$$;

grant execute on function public.set_buddy_expense_receipt(uuid, text) to authenticated;

create or replace function public.delete_buddy_expense(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.buddy_expenses
  where id = p_id and auth.uid() in (person_a, person_b);
  if not found then
    raise exception 'This expense no longer exists';
  end if;
end;
$$;

grant execute on function public.delete_buddy_expense(uuid) to authenticated;

-- Paying back. The one who owes ([p_to] is owed): "I paid", pending until
-- they confirm. The one owed ([p_from] owes them): "Mark as received",
-- confirmed straight away.
create or replace function public.record_buddy_payment(
  p_team_id uuid,
  p_from uuid,
  p_to uuid,
  p_amount numeric,
  p_method text,
  p_slip_path text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_id uuid;
begin
  if v_me is null or v_me not in (p_from, p_to) or p_from = p_to then
    raise exception 'Only the two of you can settle this';
  end if;
  if public.squad_role(p_team_id) is null then
    raise exception 'Only squad members can settle up';
  end if;
  if coalesce(p_amount, 0) <= 0 then
    raise exception 'Enter an amount';
  end if;
  if p_slip_path is not null and split_part(p_slip_path, '/', 1) <> 'buddy' then
    raise exception 'Invalid slip';
  end if;
  insert into public.buddy_settlements (
    team_id, from_id, to_id, amount, method, status, slip_path, recorded_by, responded_at
  )
  values (
    p_team_id, p_from, p_to, round(p_amount, 2), coalesce(p_method, 'cash'),
    case when v_me = p_to then 'confirmed' else 'pending' end,
    p_slip_path, v_me,
    case when v_me = p_to then now() end
  )
  returning id into v_id;
  return v_id;
end;
$$;

grant execute on function public.record_buddy_payment(uuid, uuid, uuid, numeric, text, text)
  to authenticated;

-- The one paid confirms or rejects a pending "I paid".
create or replace function public.respond_buddy_payment(
  p_id uuid,
  p_confirm boolean,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.buddy_settlements
  set status = case when p_confirm then 'confirmed' else 'rejected' end,
      reject_reason = case when p_confirm then null else nullif(trim(p_reason), '') end,
      responded_at = now()
  where id = p_id and to_id = auth.uid() and status = 'pending';
  if not found then
    raise exception 'This payment was already answered';
  end if;
end;
$$;

grant execute on function public.respond_buddy_payment(uuid, boolean, text) to authenticated;

-- The one who said "I paid" can take it back while it's pending.
create or replace function public.cancel_buddy_payment(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.buddy_settlements
  where id = p_id and from_id = auth.uid() and status = 'pending';
  if not found then
    raise exception 'This payment was already answered';
  end if;
end;
$$;

grant execute on function public.cancel_buddy_payment(uuid) to authenticated;

-- Photos: payment-slips/buddy/<team id>/<uploader id>/<file>. Uploaded by
-- a squad member into their own folder; seen only by the two people on
-- the expense or payment it's attached to.
drop policy if exists "buddy_photos_insert_own" on storage.objects;
create policy "buddy_photos_insert_own" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'payment-slips'
    and (storage.foldername(name))[1] = 'buddy'
    and (storage.foldername(name))[2] in (select id::text from public.my_team_ids() as id)
    and (storage.foldername(name))[3] = auth.uid()::text
  );

drop policy if exists "buddy_photos_select_pair" on storage.objects;
create policy "buddy_photos_select_pair" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'payment-slips'
    and (storage.foldername(name))[1] = 'buddy'
    and (
      (storage.foldername(name))[3] = auth.uid()::text
      or exists (
        select 1 from public.buddy_expenses e
        where e.receipt_path = name and auth.uid() in (e.person_a, e.person_b)
      )
      or exists (
        select 1 from public.buddy_settlements s
        where s.slip_path = name and auth.uid() in (s.from_id, s.to_id)
      )
    )
  );

-- Why [p_profile_id] can't leave [p_team_id] yet on buddy expenses, or
-- null. [p_self]: they're leaving (else being removed).
create or replace function public.buddy_leave_blocker(
  p_team_id uuid,
  p_profile_id uuid,
  p_self boolean
)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_other uuid;
  v_owed numeric;
  v_name text;
begin
  for v_other in
    select distinct case when e.person_a = p_profile_id then e.person_b else e.person_a end
    from public.buddy_expenses e
    where e.team_id = p_team_id and p_profile_id in (e.person_a, e.person_b)
  loop
    v_owed := public.buddy_owed(p_team_id, p_profile_id, v_other);
    if round(v_owed, 2) <> 0 then
      select coalesce(name, 'a squad-mate') into v_name from public.profiles where id = v_other;
      return case
        when p_self and v_owed > 0 then 'Settle up with ' || v_name || ' on your buddy expenses first.'
        when p_self then v_name || ' still owes you on your buddy expenses. Settle up first.'
        else 'They still have a buddy balance with ' || v_name || '. They need to settle up first.'
      end;
    end if;
  end loop;
  if exists (
    select 1 from public.buddy_settlements s
    where s.team_id = p_team_id and s.status = 'pending'
      and p_profile_id in (s.from_id, s.to_id)
  ) then
    return case
      when p_self then 'A buddy payment is still waiting to be confirmed.'
      else 'They have a buddy payment still waiting to be confirmed.'
    end;
  end if;
  return null;
end;
$$;

revoke execute on function public.buddy_leave_blocker(uuid, uuid, boolean)
  from public, anon, authenticated;

-- leave_team and remove_team_member (051), now also waiting for buddy
-- balances to be settled.
create or replace function public.leave_team(p_team_id uuid, p_new_owner uuid default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_role public.team_role;
  v_blocker text;
begin
  select role into v_role from public.team_members
  where team_id = p_team_id and profile_id = v_uid;
  if not found then
    raise exception 'You''re not in this group';
  end if;

  if not exists (
    select 1 from public.team_members
    where team_id = p_team_id and profile_id <> v_uid
  ) then
    raise exception 'You''re the only member. Delete the group instead.';
  end if;

  v_blocker := coalesce(
    public.member_leave_blocker(p_team_id, v_uid, true),
    public.buddy_leave_blocker(p_team_id, v_uid, true)
  );
  if v_blocker is not null then
    raise exception '%', v_blocker;
  end if;

  if v_role = 'super_admin' and not exists (
    select 1 from public.team_members
    where team_id = p_team_id and profile_id <> v_uid and role = 'super_admin'
  ) then
    if p_new_owner is null or p_new_owner = v_uid or not exists (
      select 1 from public.team_members
      where team_id = p_team_id and profile_id = p_new_owner
    ) then
      raise exception 'Choose who becomes the new super admin first';
    end if;
    update public.team_members set role = 'super_admin'
    where team_id = p_team_id and profile_id = p_new_owner;
  end if;

  perform public.drop_team_member(p_team_id, v_uid, null);
end;
$$;

revoke execute on function public.leave_team(uuid, uuid) from public, anon;
grant execute on function public.leave_team(uuid, uuid) to authenticated;

create or replace function public.remove_team_member(p_team_id uuid, p_profile_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_my_role public.team_role;
  v_their_role public.team_role;
  v_blocker text;
begin
  if p_profile_id = v_uid then
    raise exception 'To remove yourself, leave the group instead';
  end if;

  select role into v_my_role from public.team_members
  where team_id = p_team_id and profile_id = v_uid;
  select role into v_their_role from public.team_members
  where team_id = p_team_id and profile_id = p_profile_id;
  if v_their_role is null then
    raise exception 'They''re not in this group any more';
  end if;

  if not (
    (v_my_role = 'super_admin' and v_their_role in ('admin', 'player'))
    or (v_my_role = 'admin' and v_their_role = 'player')
  ) then
    raise exception '%', case
      when v_my_role = 'admin' then 'Admins can only remove players'
      else 'Only an admin can remove members'
    end;
  end if;

  v_blocker := coalesce(
    public.member_leave_blocker(p_team_id, p_profile_id, false),
    public.buddy_leave_blocker(p_team_id, p_profile_id, false)
  );
  if v_blocker is not null then
    raise exception '%', v_blocker;
  end if;

  perform public.drop_team_member(p_team_id, p_profile_id, v_uid);
end;
$$;

revoke execute on function public.remove_team_member(uuid, uuid) from public, anon;
grant execute on function public.remove_team_member(uuid, uuid) to authenticated;

-- "฿1,250" / "K3,000.50" in a squad's currency.
create or replace function public.buddy_money(p_amount numeric, p_currency text)
returns text
language sql
immutable
set search_path = public
as $$
  select case p_currency when 'mmk' then 'K' else '฿' end
    || regexp_replace(trim(to_char(p_amount, 'FM999,999,999,990.00')), '\.00$', '');
$$;

-- Pushes to the other person. Keys are '<kind>:<team id>:<row id>[:<version>]',
-- so the claim files them under the squad and its Settle tab opens.
create or replace function public.due_buddy_push_notifications()
returns table (key text, profile_id uuid, title text, body text, route text, web_only boolean)
language sql
stable
security definer
set search_path = public
as $$
  -- Added or changed: to whoever didn't do it, once per change.
  select
    'buddy_expense:' || e.team_id || ':' || e.id || ':' || extract(epoch from e.updated_at)::bigint,
    case when e.updated_by = e.person_a then e.person_b else e.person_a end,
    coalesce(who.name, 'Your buddy')
      || case when e.created_at = e.updated_at then ' added ' else ' changed ' end
      || e.title,
    case
      when e.payer_id = e.updated_by then
        'You owe ' || public.buddy_money(
          case when e.person_a = e.updated_by then e.share_b else e.share_a end, t.currency
        ) || ' · just between you two in ' || t.name
      else
        coalesce(who.name, 'They') || ' owes you ' || public.buddy_money(
          case when e.person_a = e.updated_by then e.share_a else e.share_b end, t.currency
        ) || ' · just between you two in ' || t.name
    end,
    '/wallet',
    false
  from public.buddy_expenses e
  join public.teams t on t.id = e.team_id
  left join public.profiles who on who.id = e.updated_by
  where e.updated_at > now() - interval '1 day'

  union all

  -- "I paid": to the one paid, to confirm.
  select
    'buddy_payment:' || s.team_id || ':' || s.id,
    s.to_id,
    coalesce(who.name, 'Your buddy') || ' says they paid you ' || public.buddy_money(s.amount, t.currency),
    'Confirm it in ' || t.name || ' → Settle → Buddies.',
    '/wallet',
    false
  from public.buddy_settlements s
  join public.teams t on t.id = s.team_id
  left join public.profiles who on who.id = s.from_id
  where s.recorded_by = s.from_id and s.created_at > now() - interval '1 day'

  union all

  -- Marked received, confirmed or rejected: to the one who paid.
  select
    case
      when s.recorded_by = s.to_id then 'buddy_received:'
      when s.status = 'confirmed' then 'buddy_confirmed:'
      else 'buddy_rejected:'
    end || s.team_id || ':' || s.id,
    s.from_id,
    case
      when s.status = 'rejected' then
        coalesce(who.name, 'Your buddy') || ' didn''t get your ' || public.buddy_money(s.amount, t.currency)
      else
        coalesce(who.name, 'Your buddy') || ' got your ' || public.buddy_money(s.amount, t.currency)
    end,
    case
      when s.status = 'rejected' then coalesce(s.reject_reason, 'Check with them, then try again.')
      else 'Buddy balance updated in ' || t.name || '.'
    end,
    '/wallet',
    false
  from public.buddy_settlements s
  join public.teams t on t.id = s.team_id
  left join public.profiles who on who.id = s.to_id
  where s.status in ('confirmed', 'rejected')
    and s.responded_at > now() - interval '1 day';
$$;

revoke execute on function public.due_buddy_push_notifications()
  from public, anon, authenticated;

-- 056's claim, now also sending buddy pushes.
create or replace function public.claim_push_notifications()
returns table (profile_id uuid, title text, body text, route text, web_only boolean)
language sql
volatile
security definer
set search_path = public
as $$
  with every_due as (
    select * from public.due_push_notifications()
    union all
    select * from public.due_squad_push_notifications()
    union all
    select * from public.due_match_comment_push_notifications()
    union all
    select * from public.due_rating_push_notifications()
    union all
    select * from public.due_mention_push_notifications()
    union all
    select * from public.due_member_removed_push_notifications()
    union all
    select * from public.due_match_question_push_notifications()
    union all
    select * from public.due_share_push_notifications()
    union all
    select * from public.due_group_invite_push_notifications()
    union all
    select * from public.due_buddy_push_notifications()
  ),
  due as (
    select
      d.key,
      d.profile_id,
      d.title,
      public.render_mentions(d.body) as body,
      d.route,
      d.web_only
    from every_due d
    -- Mentioned in a comment: the mention push, not the comment one too.
    where split_part(d.key, ':', 1) like '%\_mention'
      or not exists (
        select 1 from every_due mention
        where split_part(mention.key, ':', 1) like '%\_mention'
          and split_part(mention.key, ':', 3) = split_part(d.key, ':', 3)
          and mention.profile_id = d.profile_id
      )
  ),
  claimed as (
    insert into public.push_log (key)
    select key from due
    on conflict (key) do nothing
    returning key
  ),
  filed as (
    insert into public.notifications (
      key, profile_id, kind, match_id, expense_id, team_id, trip_id, title, body
    )
    select
      due.key,
      due.profile_id,
      split_part(due.key, ':', 1),
      m.id,
      e.id,
      coalesce(m.team_id, s.team_id, e.team_id, tr.team_id, pp.team_id, g.id),
      coalesce(tr.id, e.trip_id, s.trip_id, pp.trip_id),
      due.title,
      due.body
    from due
    join claimed on claimed.key = due.key
    left join public.matches m
      on m.id::text = split_part(due.key, ':', 2)
    left join public.settlements s
      on s.id::text = split_part(due.key, ':', 2)
    left join public.expenses e
      on e.id::text = split_part(due.key, ':', 2)
    left join public.trips tr
      on tr.id::text = split_part(due.key, ':', 2)
    left join public.payment_promises pp
      on pp.id::text = split_part(due.key, ':', 2)
    left join public.teams g
      on g.id::text = split_part(due.key, ':', 2)
    on conflict (key) do nothing
    returning id, key
  )
  select
    due.profile_id,
    due.title,
    due.body,
    coalesce('/notifications/' || filed.id, due.route),
    due.web_only
  from due
  join claimed on claimed.key = due.key
  left join filed on filed.key = due.key;
$$;

revoke execute on function public.claim_push_notifications() from public, anon, authenticated;
grant execute on function public.claim_push_notifications() to service_role;

drop trigger if exists push_kick_buddy_expenses on public.buddy_expenses;
create trigger push_kick_buddy_expenses
  after insert or update on public.buddy_expenses
  for each statement execute function public.kick_push_dispatcher();

drop trigger if exists push_kick_buddy_settlements on public.buddy_settlements;
create trigger push_kick_buddy_settlements
  after insert or update on public.buddy_settlements
  for each statement execute function public.kick_push_dispatcher();
