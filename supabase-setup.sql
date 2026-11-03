-- VDF Bracket: initial Supabase schema
-- Run this in Supabase Dashboard -> SQL Editor.

create table if not exists public.tournaments (
  id text primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  nickname text not null check (char_length(nickname) between 1 and 32),
  title text not null check (char_length(title) between 1 and 100),
  bracket_data jsonb not null,
  is_public boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists tournaments_created_at_idx
  on public.tournaments (created_at desc);
create index if not exists tournaments_owner_id_idx
  on public.tournaments (owner_id);

create or replace function public.vdf_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists vdf_tournaments_updated_at on public.tournaments;
create trigger vdf_tournaments_updated_at
before update on public.tournaments
for each row execute function public.vdf_set_updated_at();

alter table public.tournaments enable row level security;

-- Public visitors can read published brackets.
drop policy if exists "Anyone can read public tournaments" on public.tournaments;
create policy "Anyone can read public tournaments"
on public.tournaments for select
to anon, authenticated
using (is_public = true);

-- Anonymous Auth users are still authenticated users in Supabase.
-- Each user can create rows only with their own auth.uid().
drop policy if exists "Owners can create tournaments" on public.tournaments;
create policy "Owners can create tournaments"
on public.tournaments for insert
to authenticated
with check (owner_id = (select auth.uid()));

-- Only the owner can update their own tournament.
drop policy if exists "Owners can update tournaments" on public.tournaments;
create policy "Owners can update tournaments"
on public.tournaments for update
to authenticated
using (owner_id = (select auth.uid()))
with check (owner_id = (select auth.uid()));

-- Only the owner can delete their own tournament.
drop policy if exists "Owners can delete tournaments" on public.tournaments;
create policy "Owners can delete tournaments"
on public.tournaments for delete
to authenticated
using (owner_id = (select auth.uid()));

grant select on public.tournaments to anon, authenticated;
grant insert, update, delete on public.tournaments to authenticated;

-- Enable Realtime for the tournament table (safe to re-run).
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'tournaments'
  ) then
    alter publication supabase_realtime add table public.tournaments;
  end if;
end;
$$;
