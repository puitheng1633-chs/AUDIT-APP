-- SSA Audit Tracker schema (as applied to project bjalgiqjxggmiczaxcgh).
-- Passwords live in Supabase Auth (auth.users); public.profiles holds app roles.

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique check (username ~ '^[a-z0-9._-]{2,32}$'),
  full_name text not null default '',
  role text not null default 'auditor' check (role in ('admin','auditor','reviewer')),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create schema if not exists private;
grant usage on schema private to authenticated;
create or replace function private.is_member() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.active);
$$;
create or replace function private.is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.active and p.role = 'admin');
$$;
revoke execute on function private.is_member() from public, anon;
revoke execute on function private.is_admin() from public, anon;
grant execute on function private.is_member() to authenticated;
grant execute on function private.is_admin() to authenticated;

create table public.engagements (
  id uuid primary key default gen_random_uuid(),
  entity text not null default '',
  fy_end date not null default '2026-06-30',
  currency text not null default 'SGD',
  om numeric not null default 250000 check (om >= 0),
  pm_pct numeric not null default 75 check (pm_pct between 1 and 100),
  ct_pct numeric not null default 5 check (ct_pct between 0 and 20),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles(id) on delete set null
);

create table public.audit_files (
  id text primary key,
  engagement_id uuid not null references public.engagements(id) on delete cascade,
  name text not null,
  sheets jsonb not null default '[]'::jsonb,
  sample boolean not null default false,
  uploaded_at timestamptz not null default now(),
  uploaded_by uuid references public.profiles(id) on delete set null
);

create table public.audit_issues (
  id uuid primary key default gen_random_uuid(),
  ref_no bigint generated always as identity unique,
  engagement_id uuid not null references public.engagements(id) on delete cascade,
  file_id text references public.audit_files(id) on delete cascade,
  key text unique,
  auto boolean not null default false,
  test_id text not null default 'manual',
  title text not null,
  cat text not null,
  amount numeric not null default 0,
  count integer not null default 0,
  detail text not null default '',
  loc jsonb not null default '{}'::jsonb,
  refs jsonb not null default '[]'::jsonb,
  extra_refs jsonb not null default '[]'::jsonb,
  status text not null default 'Open' check (status in ('Open','Investigating','Misstatement confirmed','Cleared')),
  prio text not null default '' check (prio in ('','P1','P2','P3')),
  risk_override text not null default '' check (risk_override in ('','High','Medium','Low')),
  w_override integer,
  notes text not null default '',
  sample boolean not null default false,
  created_at timestamptz not null default now(),
  created_by uuid references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles(id) on delete set null
);

create index audit_files_engagement_idx on public.audit_files(engagement_id);
create index audit_files_uploaded_by_idx on public.audit_files(uploaded_by);
create index audit_issues_engagement_idx on public.audit_issues(engagement_id);
create index audit_issues_file_idx on public.audit_issues(file_id);
create index audit_issues_created_by_idx on public.audit_issues(created_by);
create index audit_issues_updated_by_idx on public.audit_issues(updated_by);
create index engagements_updated_by_idx on public.engagements(updated_by);

create or replace function public.stamp_update() returns trigger
language plpgsql set search_path = '' as $$
begin new.updated_at := now(); new.updated_by := (select auth.uid()); return new; end $$;
create trigger engagements_stamp before update on public.engagements for each row execute function public.stamp_update();
create trigger audit_issues_stamp before insert or update on public.audit_issues for each row execute function public.stamp_update();

alter table public.profiles enable row level security;
alter table public.engagements enable row level security;
alter table public.audit_files enable row level security;
alter table public.audit_issues enable row level security;

create policy "members read profiles" on public.profiles for select to authenticated using ((select private.is_member()) or id = (select auth.uid()));
create policy "admins update profiles" on public.profiles for update to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy "members read engagements" on public.engagements for select to authenticated using ((select private.is_member()));
create policy "members update engagements" on public.engagements for update to authenticated using ((select private.is_member())) with check ((select private.is_member()));
create policy "admins insert engagements" on public.engagements for insert to authenticated with check ((select private.is_admin()));
create policy "members read files" on public.audit_files for select to authenticated using ((select private.is_member()));
create policy "members insert files" on public.audit_files for insert to authenticated with check ((select private.is_member()));
create policy "members update files" on public.audit_files for update to authenticated using ((select private.is_member())) with check ((select private.is_member()));
create policy "members delete files" on public.audit_files for delete to authenticated using ((select private.is_member()));
create policy "members read issues" on public.audit_issues for select to authenticated using ((select private.is_member()));
create policy "members insert issues" on public.audit_issues for insert to authenticated with check ((select private.is_member()));
create policy "members update issues" on public.audit_issues for update to authenticated using ((select private.is_member())) with check ((select private.is_member()));
create policy "members delete issues" on public.audit_issues for delete to authenticated using ((select private.is_member()));

alter publication supabase_realtime add table public.audit_issues;

insert into public.engagements (entity) values ('');

-- Seed users (priya = admin; dan, marcus = auditor) were created in auth.users with the
-- initial password "password" and email <username>@audit-app.local. Add further users
-- from the app's Users page (admin only), which calls the manage-users edge function.
