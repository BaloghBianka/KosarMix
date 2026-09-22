-- Kosártipp – adatbázis séma (Supabase SQL Editorban egyszer lefuttatni)
-- A szabályokat itt, az adatbázis kényszeríti ki, nem a böngésző:
--   * mindenki csak a saját nevében tippelhet
--   * tippelni/módosítani csak a zárásig lehet (péntek 23:59, vagy a kezdésig, ha az korábbi)
--   * mások tippje csak zárás után olvasható

-- Játékosok: Supabase felhasználó -> név
create table if not exists public.players (
  user_id  uuid primary key references auth.users(id) on delete cascade,
  name     text not null unique,
  is_admin boolean not null default false
);

-- Meccsek (a GitHub Action frissíti az mkosz.hu alapján)
create table if not exists public.matches (
  id         text primary key,          -- mkosz azonosító, pl. whun_135479
  home       text not null,
  away       text not null,
  starts_at  timestamptz not null,
  home_score int check (home_score >= 0),
  away_score int check (away_score >= 0),
  constraint no_draw check (home_score is null or away_score is null or home_score <> away_score)
);

-- Tippek: H = hazai nyer, A = vendég nyer
create table if not exists public.tips (
  user_id    uuid not null default auth.uid() references public.players(user_id) on delete cascade,
  match_id   text not null references public.matches(id) on delete cascade,
  pick       char(1) not null check (pick in ('H','A')),
  updated_at timestamptz not null default now(),
  primary key (user_id, match_id)
);

-- Zárás időpontja: a meccs hetének (hétfő–vasárnap, budapesti idő) szombat 00:00-ja,
-- vagy a kezdés, ha az korábbi.
create or replace function public.lock_at(ts timestamptz)
returns timestamptz language sql stable as $$
  select least(
    ts,
    (date_trunc('week', ts at time zone 'Europe/Budapest') + interval '5 days') at time zone 'Europe/Budapest'
  )
$$;

create or replace function public.match_open(mid text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from matches m where m.id = mid and now() < lock_at(m.starts_at))
$$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from players where user_id = auth.uid() and is_admin)
$$;

create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at := now(); return new; end $$;

drop trigger if exists tips_touch on public.tips;
create trigger tips_touch before update on public.tips
  for each row execute function public.touch_updated_at();

-- ---------- jogosultságok ----------
alter table public.players enable row level security;
alter table public.matches enable row level security;
alter table public.tips    enable row level security;

revoke all on public.players, public.matches, public.tips from anon, authenticated;
grant select on public.players, public.matches to authenticated;
grant select, insert, update, delete on public.tips to authenticated;
grant update (home_score, away_score) on public.matches to authenticated;  -- csak adminnak engedi a policy

drop policy if exists players_read on public.players;
create policy players_read on public.players for select to authenticated using (true);

drop policy if exists matches_read on public.matches;
create policy matches_read on public.matches for select to authenticated using (true);

drop policy if exists matches_admin_score on public.matches;
create policy matches_admin_score on public.matches for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

drop policy if exists tips_read on public.tips;
create policy tips_read on public.tips for select to authenticated
  using (user_id = auth.uid() or not public.match_open(match_id));

drop policy if exists tips_insert on public.tips;
create policy tips_insert on public.tips for insert to authenticated
  with check (user_id = auth.uid() and public.match_open(match_id));

drop policy if exists tips_update on public.tips;
create policy tips_update on public.tips for update to authenticated
  using (user_id = auth.uid() and public.match_open(match_id))
  with check (user_id = auth.uid() and public.match_open(match_id));

drop policy if exists tips_delete on public.tips;
create policy tips_delete on public.tips for delete to authenticated
  using (user_id = auth.uid() and public.match_open(match_id));
