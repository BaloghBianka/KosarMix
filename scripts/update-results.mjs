// Behúzza az mkosz.hu műsorát, és frissíti a Supabase `matches` táblát:
// új meccsek, átírt időpontok és lejátszott meccsek végeredménye.
//
// Futtatás:  SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... node scripts/update-results.mjs
// Próba (nem ír semmit):  node scripts/update-results.mjs --dry-run [helyi.html]

const SOURCE = 'https://mkosz.hu/bajnoksag-musor/x2627/whun/';
const MONTHS = { január: 1, február: 2, március: 3, április: 4, május: 5, június: 6, július: 7, augusztus: 8, szeptember: 9, október: 10, november: 11, december: 12 };

const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');
const localFile = args.find(a => !a.startsWith('--'));

const decode = s => s.replace(/&amp;/g, '&').replace(/&quot;/g, '"').replace(/&#0?39;/g, "'").replace(/&lt;/g, '<').replace(/&gt;/g, '>');

export function parse(html) {
  const re = /<tr>\s*<td[^>]*><a href="[^"]*\/csapat\/[^"]*" title="([^"]+)".*?<a href="[^"]*\/csapat\/[^"]*" title="([^"]+)".*?<b>(\d{4})\. (\p{L}+) (\d+)\.<\/b>.*?<td[^>]*>([\d:]*)<\/td>.*?merkozes\/x2627\/whun\/(whun_\d+)">\s*(\d+)\s*-\s*(\d+)\s*<\/a>/gsu;
  const out = [];
  for (const [, home, away, y, mon, d, time, id, hs, as] of html.matchAll(re)) {
    const mo = MONTHS[mon.toLowerCase()];
    if (!mo) continue;
    const date = `${y}-${String(mo).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
    const H = +hs, A = +as;
    out.push({
      id, home: decode(home), away: decode(away),
      starts_at: `${date} ${time || '00:00'} Europe/Budapest`,
      // a még le nem játszott meccsek "0 - 0"-val szerepelnek
      score: H === 0 && A === 0 ? null : [H, A],
    });
  }
  return out;
}

async function main() {
  const html = localFile
    ? (await import('node:fs')).readFileSync(localFile, 'utf8')
    : await (await fetch(SOURCE, { headers: { 'User-Agent': 'Mozilla/5.0 (kosartipp)' } })).text();
  const rows = parse(html);
  if (rows.length < 50) throw new Error(`Gyanúsan kevés meccs (${rows.length}) – lehet, hogy változott az mkosz.hu oldal szerkezete.`);
  const played = rows.filter(r => r.score && r.score[0] !== r.score[1]);
  console.log(`${rows.length} meccs, ebből ${played.length} lejátszva.`);
  if (dryRun) { console.log(rows.slice(0, 3), played.slice(0, 3)); return; }

  const url = process.env.SUPABASE_URL, key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) throw new Error('Hiányzik a SUPABASE_URL vagy a SUPABASE_SERVICE_ROLE_KEY.');
  const headers = { apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' };

  // 1) műsor: új meccsek + időpont-változások
  const sched = rows.map(({ id, home, away, starts_at }) => ({ id, home, away, starts_at }));
  let res = await fetch(`${url}/rest/v1/matches?on_conflict=id`, {
    method: 'POST', headers: { ...headers, Prefer: 'resolution=merge-duplicates,return=minimal' }, body: JSON.stringify(sched),
  });
  if (!res.ok) throw new Error(`Műsor mentése sikertelen: ${res.status} ${await res.text()}`);

  // 2) végeredmények (csak ami még hiányzik vagy eltér)
  res = await fetch(`${url}/rest/v1/matches?select=id,home_score,away_score`, { headers });
  if (!res.ok) throw new Error(`Olvasás sikertelen: ${res.status} ${await res.text()}`);
  const current = Object.fromEntries((await res.json()).map(m => [m.id, m]));
  let updated = 0;
  for (const r of played) {
    const c = current[r.id];
    if (c && c.home_score === r.score[0] && c.away_score === r.score[1]) continue;
    res = await fetch(`${url}/rest/v1/matches?id=eq.${encodeURIComponent(r.id)}`, {
      method: 'PATCH', headers: { ...headers, Prefer: 'return=minimal' },
      body: JSON.stringify({ home_score: r.score[0], away_score: r.score[1] }),
    });
    if (!res.ok) throw new Error(`${r.id} eredménye nem menthető: ${res.status} ${await res.text()}`);
    updated++;
  }
  console.log(`Frissítve: ${updated} végeredmény.`);
}

import { pathToFileURL } from 'node:url';
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch(e => { console.error(e.message); process.exit(1); });
}
