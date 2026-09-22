-- Kosártipp – adatbázis séma (Supabase SQL Editorban egyszer lefuttatni)
-- A szabályokat itt, az adatbázis kényszeríti ki, nem a böngésző:
--   * mindenki csak a saját nevében tippelhet
--   * tippelni/módosítani csak a zárásig lehet (péntek 23:59, vagy a kezdésig, ha az korábbi)
--   * mások tippje csak zárás után olvasható
--   * regisztrálni csak a meghívókóddal lehet; az első regisztráló lesz az admin

-- Játékosok: Supabase felhasználó -> név
create table if not exists public.players (
  user_id  uuid primary key references auth.users(id) on delete cascade,
  name     text not null check (char_length(name) between 2 and 20),
  is_admin boolean not null default false
);
create unique index if not exists players_name_ci on public.players (lower(name));

-- Beállítások (a meghívókód). Kliensről nem olvasható.
create table if not exists public.settings (
  key   text primary key,
  value text
);
insert into public.settings (key, value) values ('join_code', null) on conflict (key) do nothing;

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

create or replace function public.is_player()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from players where user_id = auth.uid())
$$;

-- ---------- regisztráció ----------
-- Regisztráció előtti ellenőrzés a felületnek (bejelentkezés nélkül hívható).
create or replace function public.signup_check(p_name text, p_invite text)
returns text language plpgsql stable security definer set search_path = public as $$
declare code text;
begin
  select value into code from settings where key = 'join_code';
  if code is null or coalesce(p_invite, '') <> code then return 'invite'; end if;
  if char_length(btrim(coalesce(p_name, ''))) not between 2 and 20 then return 'name_invalid'; end if;
  if exists (select 1 from players where lower(name) = lower(btrim(p_name))) then return 'name_taken'; end if;
  return 'ok';
end $$;

-- Új fiók: a meghívókódot az adatbázis ellenőrzi, rossz kóddal nem jön létre a fiók.
create or replace function public.check_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare code text;
begin
  select value into code from settings where key = 'join_code';
  if code is null or coalesce(new.raw_user_meta_data->>'invite', '') <> code then
    raise exception 'INVALID_INVITE';
  end if;
  new.raw_user_meta_data := new.raw_user_meta_data - 'invite';   -- a kódot nem tároljuk el
  return new;
end $$;

create or replace function public.create_player()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into players (user_id, name, is_admin)
  values (new.id, btrim(new.raw_user_meta_data->>'name'), not exists (select 1 from players));
  return new;
end $$;

drop trigger if exists kosartipp_check_new_user on auth.users;
create trigger kosartipp_check_new_user before insert on auth.users
  for each row execute function public.check_new_user();
drop trigger if exists kosartipp_create_player on auth.users;
create trigger kosartipp_create_player after insert on auth.users
  for each row execute function public.create_player();

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
alter table public.settings enable row level security;

revoke all on public.players, public.matches, public.tips, public.settings from anon, authenticated;
revoke all on function public.signup_check(text, text) from public;
grant execute on function public.signup_check(text, text) to anon, authenticated;
grant select on public.players, public.matches to authenticated;
grant select, insert, update, delete on public.tips to authenticated;
grant update (home_score, away_score) on public.matches to authenticated;  -- csak adminnak engedi a policy

drop policy if exists players_read on public.players;
create policy players_read on public.players for select to authenticated using (public.is_player());

drop policy if exists matches_read on public.matches;
create policy matches_read on public.matches for select to authenticated using (public.is_player());

drop policy if exists matches_admin_score on public.matches;
create policy matches_admin_score on public.matches for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

drop policy if exists tips_read on public.tips;
create policy tips_read on public.tips for select to authenticated
  using (user_id = auth.uid() or (public.is_player() and not public.match_open(match_id)));

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
