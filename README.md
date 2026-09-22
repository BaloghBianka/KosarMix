# Kosártipp 26/27

Heti tippverseny Bia, Bogi és Tamás részére a Női NB I. A csoport meccseire.
Minden meccsre azt kell tippelni, melyik csapat nyer. Egy hét meccseire hétfő 0:00-tól lehet tippelni, a határidő péntek 23:59 (vagy a kezdés, ha az korábbi). A mentett tipp végleges.
Minden eltalált győztes 1 pontot ér. Van heti győztes és szezongyőztes is.

- **Weboldal:** `web/`. Statikus oldal, ingyen kiszolgálja a GitHub Pages (`.github/workflows/pages.yml`) vagy a Render (`render.yaml`). Elég az egyik.
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
3. **SQL Editor:** állítsd be a meghívókódot. Ezt ne írd bele a repóba, mert a repó publikus:
   ```sql
   update public.settings set value = 'IDE_A_TITKOS_KOD' where key = 'join_code';
   ```
   Amíg nincs kód beállítva, senki nem tud regisztrálni. Használj legalább 8 karakteres, nem kitalálható kódot.
4. **Authentication → URL Configuration → Site URL:** írd be ezt: `https://baloghbianka.github.io/KosarMix/`. Ide visznek a megerősítő és a jelszó-visszaállító e-mailek linkjei.
5. **Authentication → Sign In / Providers → Email:** alapból be van kapcsolva a **Confirm email**.
   - Így regisztráció után mindenki kap egy megerősítő e-mailt.
   - Ha ezt nem szeretnéd, kapcsold ki. Akkor regisztráció után azonnal be lehet lépni.
   - Az ingyenes csomag óránként csak néhány e-mailt küld, de három embernek ez bőven elég.
6. **Project Settings → API Keys:** két adatra lesz szükséged:
   - a **Project URL**
   - az **anon / publishable** kulcs

### 2. Weboldal beállítása
Írd be a `web/config.js` fájlba a Project URL-t és az anon kulcsot. Az anon kulcs nyilvános, ezért nyugodtan lehet a kódban.
A **service_role / secret** kulcs viszont soha nem kerülhet ide.

### 3. GitHub (napi eredményfrissítés)
1. **Settings → Secrets and variables → Actions → New repository secret:** vegyél fel két titkot:
   - `SUPABASE_URL`: a Project URL
   - `SUPABASE_SERVICE_ROLE_KEY`: a Supabase **service_role / secret** kulcsa. Ez titok, csak ide kerülhet.
2. **Actions** fül → **Eredmények frissítése** → **Run workflow:** futtasd le egyszer kézzel, hogy lásd, működik-e.

### 4/a. GitHub Pages (weboldal)
1. **Settings → Pages → Source:** válaszd a **GitHub Actions** lehetőséget.
2. **Actions** fül → **Weboldal kitelepítése** → **Run workflow**.
3. Az oldal címe: `https://baloghbianka.github.io/KosarMix/`. Minden `web/` módosítás után magától frissül.

### 4/b. Render (weboldal, a GitHub Pages helyett vagy mellett)
1. Regisztrálj a https://render.com oldalon GitHub-fiókkal.
2. **New → Blueprint**, válaszd ki a `KosarMix` repót, majd kattints az **Apply** gombra.
   - A `render.yaml` alapján létrejön egy ingyenes Static Site.
   - Alternatíva: **New → Static Site**, a repó kiválasztása után **Publish directory:** `web`, a **Build command** mező maradjon üres.
3. Az oldal címe: `https://kosarmix.onrender.com` (vagy amit a Render kioszt). Minden `git push` után magától frissül.

### 5. Regisztráció
1. **Bia regisztrál elsőként** az oldalon (Regisztráció fül: név, e-mail, jelszó, meghívókód). Az első regisztráló automatikusan admin lesz.
2. Utána küldd el Boginak és Tamásnak a linket és a meghívókódot. Mindenki a saját fiókjával regisztrál, így más nem tud a nevében tippelni.
3. Ha már mindenki bent van, a kódot le is lehet tiltani:
   ```sql
   update public.settings set value = null where key = 'join_code';
   ```

## Frissítés
A `supabase/schema.sql` bármikor újra lefuttatható. Megtartja az adatokat és a meghívókódot, csak a szabályokat frissíti.

## Tudnivalók
- **Rájátszás:** a meccsek az mkosz.hu-n valószínűleg másik oldalon lesznek. Ha kisorsolták őket, kell hozzá egy új forrás-URL a szkriptbe.
- **Időpont-változások:** az mkosz.hu-n átírt kezdési időpontokat a szkript automatikusan átveszi.
- **Ingyenes Supabase-projekt:** egy hét teljes inaktivitás után szünetel. Az Action napi futása ezt megakadályozza.
