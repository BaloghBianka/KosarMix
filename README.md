# Kosártipp 26/27

Heti tippverseny Bia, Bogi és Tamás részére a Női NB I. A csoport meccseire.
Minden meccsre azt kell tippelni, melyik csapat nyer. Határidő: péntek 23:59, vagy a kezdés, ha az korábbi.
Minden eltalált győztes 1 pontot ér. Van heti győztes és szezongyőztes is.

- **Weboldal:** `web/`. Statikus oldal, GitHub Pages szolgálja ki.
- **Bejelentkezés és adatbázis:** Supabase (ingyenes csomag).
  - A határidőt és azt, hogy mindenki csak a saját nevében tippelhessen, maga az adatbázis ellenőrzi (`supabase/schema.sql`).
- **Eredmények:** egy GitHub Action naponta kétszer behúzza az mkosz.hu-ról (`scripts/update-results.mjs`).
  - Ha elakad, Bia (admin) kézzel is beírhatja az eredményt a meccs kártyáján.

## Telepítés (egyszer, kb. 20 perc)

### 1. Supabase
1. Regisztrálj a https://supabase.com oldalon, és hozz létre egy új projektet. Régiónak válaszd a Central EU-t (Frankfurt).
2. **SQL Editor → New query:** másold be és futtasd le sorban ezeket:
   - `supabase/schema.sql`
   - `supabase/seed.sql`
3. **Authentication → Sign In / Providers:** kapcsold ki az **Allow new users to sign up** beállítást, hogy idegenek ne tudjanak regisztrálni.
4. **Authentication → Users → Add user → Create new user:** hozd létre a három fiókot.
   - Mindegyiknél add meg az e-mail-címet és egy ideiglenes jelszót.
   - Pipáld be az **Auto Confirm User** opciót.
5. **SQL Editor:** a `supabase/players.sql` fájlba írd be a három e-mail-címet, majd futtasd le.
6. **Project Settings → API:** két adatra lesz szükséged:
   - a **Project URL**
   - az **anon / publishable** kulcs

### 2. Weboldal beállítása
Írd be a `web/config.js` fájlba a Project URL-t és az anon kulcsot. Az anon kulcs nyilvános, ezért nyugodtan lehet a kódban.
A **service_role / secret** kulcs viszont soha nem kerülhet ide.

### 3. GitHub
1. Hozz létre egy új repót (pl. `kosartipp`), és töltsd fel ezt a mappát.
2. **Settings → Pages → Source:** válaszd a **GitHub Actions** lehetőséget.
3. **Settings → Secrets and variables → Actions → New repository secret:** vegyél fel két titkot:
   - `SUPABASE_URL`: a Project URL
   - `SUPABASE_SERVICE_ROLE_KEY`: a Supabase **service_role / secret** kulcsa. Ez titok, csak ide kerülhet.
4. **Actions** fül:
   - Futtasd le a **Weboldal kitelepítése** workflow-t (utána minden `web/` módosításnál magától fut).
   - Futtasd le egyszer kézzel az **Eredmények frissítése** workflow-t, hogy lásd, működik-e.
5. Az oldal címe ez lesz: `https://<github-felhasznalonev>.github.io/kosartipp/`

### 4. Első belépés
Küldd el Boginak és Tamásnak a címet és az ideiglenes jelszavukat.
Első belépés után mindenki változtassa meg a jelszavát: a jobb felső sarokban a névre kattintva, a **Jelszó módosítása** menüpontban.
Innentől senki más, Bia sem tud az ő nevükben tippelni.

## Tudnivalók
- **Rájátszás:** a meccsek az mkosz.hu-n valószínűleg másik oldalon lesznek. Ha kisorsolták őket, kell hozzá egy új forrás-URL a szkriptbe.
- **Időpont-változások:** az mkosz.hu-n átírt kezdési időpontokat a szkript automatikusan átveszi.
- **Ingyenes Supabase-projekt:** egy hét teljes inaktivitás után szünetel. Az Action napi futása ezt megakadályozza.
