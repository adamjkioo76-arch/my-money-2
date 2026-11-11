-- ============================================================
-- MY MONEY 4.0 — Schema
-- ============================================================
create extension if not exists "pgcrypto";

-- PROFILES
create table profiles (
  id uuid primary key references auth.users on delete cascade,
  full_name text not null,
  email text not null,
  avatar_url text,
  created_at timestamptz default now()
);

-- USER SETTINGS
create table user_settings (
  user_id uuid primary key references auth.users on delete cascade,
  base_currency text default 'EGP',
  language text default 'ar' check (language in ('ar','en')),
  theme text default 'light' check (theme in ('light','dark')),
  hide_balances boolean default false,
  onboarding_completed boolean default false,
  created_at timestamptz default now()
);

-- CATEGORIES
create table categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users on delete cascade,
  name_ar text not null,
  name_en text not null,
  icon text default 'Tag',
  color text default '#3B82F6',
  is_default boolean default false,
  created_at timestamptz default now()
);

-- SALARIES
create table salaries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  amount numeric(14,2) not null check (amount >= 0),
  currency text default 'EGP',
  payment_date date not null,
  salary_month date not null,
  notes text,
  created_at timestamptz default now(),
  unique(user_id, salary_month)
);

-- INCOME
create table income (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  amount numeric(14,2) not null check (amount > 0),
  currency text default 'EGP',
  source text default 'other',
  description text,
  income_date date not null,
  created_at timestamptz default now()
);

-- TRANSACTIONS (Expenses)
create table transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  category_id uuid references categories on delete set null,
  amount numeric(14,2) not null check (amount > 0),
  currency text default 'EGP',
  description text,
  payment_method text default 'cash',
  transaction_date date not null,
  created_at timestamptz default now()
);

-- BUDGETS
create table budgets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  month date not null,
  category_id uuid references categories on delete cascade,
  amount numeric(14,2) not null check (amount > 0),
  currency text default 'EGP',
  created_at timestamptz default now(),
  unique(user_id, month, category_id)
);

-- SAVINGS
create table savings_goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  name text not null,
  target_amount numeric(14,2) not null check (target_amount > 0),
  current_amount numeric(14,2) default 0,
  currency text default 'EGP',
  target_date date,
  icon text default 'Target',
  color text default '#10B981',
  created_at timestamptz default now()
);

create table savings_contributions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  goal_id uuid not null references savings_goals on delete cascade,
  amount numeric(14,2) not null,
  note text,
  contribution_date date not null,
  created_at timestamptz default now()
);

-- DEBTS
create table debts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  direction text not null check (direction in ('owed_to_me','i_owe')),
  person_name text not null,
  amount numeric(14,2) not null check (amount > 0),
  currency text default 'EGP',
  paid_amount numeric(14,2) default 0,
  due_date date,
  status text default 'active',
  notes text,
  created_at timestamptz default now()
);

create table debt_payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  debt_id uuid not null references debts on delete cascade,
  amount numeric(14,2) not null check (amount > 0),
  payment_date date not null,
  note text,
  created_at timestamptz default now()
);

-- RECURRING
create table recurring_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  type text not null check (type in ('income','expense')),
  category_id uuid references categories on delete set null,
  amount numeric(14,2) not null check (amount > 0),
  currency text default 'EGP',
  description text not null,
  recurrence text not null check (recurrence in ('daily','weekly','monthly','yearly')),
  start_date date not null,
  next_due_date date not null,
  is_active boolean default true,
  created_at timestamptz default now()
);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
alter table profiles enable row level security;
alter table user_settings enable row level security;
alter table categories enable row level security;
alter table salaries enable row level security;
alter table income enable row level security;
alter table transactions enable row level security;
alter table budgets enable row level security;
alter table savings_goals enable row level security;
alter table savings_contributions enable row level security;
alter table debts enable row level security;
alter table debt_payments enable row level security;
alter table recurring_transactions enable row level security;

create policy "own_profile" on profiles for all using (auth.uid() = id) with check (auth.uid() = id);
create policy "own_settings" on user_settings for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own_categories_read" on categories for select using (user_id is null or auth.uid() = user_id);
create policy "own_categories_write" on categories for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own_salaries" on salaries for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own_income" on income for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own_transactions" on transactions for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own_budgets" on budgets for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own_goals" on savings_goals for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own_contribs" on savings_contributions for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own_debts" on debts for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own_debt_payments" on debt_payments for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own_recurring" on recurring_transactions for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ============================================================
-- AUTO-CREATE PROFILE ON SIGNUP
-- ============================================================
create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into profiles(id, full_name, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email,'@',1)),
    new.email
  );
  insert into user_settings(user_id) values (new.id) on conflict do nothing;
  return new;
end; $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function handle_new_user();

-- ============================================================
-- DEFAULT CATEGORIES (global, shared by all users)
-- ============================================================
insert into categories (user_id, name_ar, name_en, icon, color, is_default) values
  (null, 'طعام ومشروبات', 'Food & Drinks', 'UtensilsCrossed', '#EF4444', true),
  (null, 'مواصلات', 'Transportation', 'Car', '#F59E0B', true),
  (null, 'تسوق', 'Shopping', 'ShoppingBag', '#8B5CF6', true),
  (null, 'فواتير', 'Bills', 'Receipt', '#3B82F6', true),
  (null, 'إنترنت واتصالات', 'Internet & Phone', 'Wifi', '#06B6D4', true),
  (null, 'صحة وأدوية', 'Health', 'Heart', '#EC4899', true),
  (null, 'ترفيه', 'Entertainment', 'Gamepad2', '#10B981', true),
  (null, 'ملابس', 'Clothing', 'Shirt', '#F97316', true),
  (null, 'منزل', 'Home', 'Home', '#14B8A6', true),
  (null, 'مصروف شخصي', 'Personal', 'User', '#6366F1', true),
  (null, 'تعليم', 'Education', 'GraduationCap', '#0891B2', true),
  (null, 'اشتراكات', 'Subscriptions', 'CreditCard', '#EAB308', true),
  (null, 'سفر', 'Travel', 'Plane', '#0EA5E9', true),
  (null, 'أخرى', 'Other', 'Tag', '#64748B', true);

-- ============================================================
-- SAVINGS GOAL AUTO-UPDATE
-- ============================================================
create or replace function update_goal_amount() returns trigger
language plpgsql as $$
begin
  update savings_goals set current_amount = (
    select coalesce(sum(amount),0) from savings_contributions where goal_id = coalesce(new.goal_id, old.goal_id)
  ) where id = coalesce(new.goal_id, old.goal_id);
  return null;
end; $$;

create trigger trg_goal_ins after insert on savings_contributions for each row execute function update_goal_amount();
create trigger trg_goal_upd after update on savings_contributions for each row execute function update_goal_amount();
create trigger trg_goal_del after delete on savings_contributions for each row execute function update_goal_amount();