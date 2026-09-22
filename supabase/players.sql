-- A három fiók hozzárendelése a játékosokhoz.
-- Előbb hozd létre a felhasználókat: Authentication → Users → Add user → Create new user
-- (pipáld be az "Auto Confirm User"-t). Utána írd be az e-mail-címeket, és futtasd le.
insert into public.players (user_id, name, is_admin)
select id, v.name, v.is_admin
from auth.users u
join (values
  ('BIA_EMAILCIME',   'Bia',   true),
  ('BOGI_EMAILCIME',  'Bogi',  false),
  ('TAMAS_EMAILCIME', 'Tamás', false)
) as v(email, name, is_admin) on lower(u.email) = lower(v.email)
on conflict (user_id) do update set name = excluded.name, is_admin = excluded.is_admin;

select p.name, u.email, p.is_admin from public.players p join auth.users u on u.id = p.user_id;
