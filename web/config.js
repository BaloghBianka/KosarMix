// Supabase → Project Settings → API (vagy Data API): ide másold a Project URL-t és az anon / publishable kulcsot.
// Az anon kulcs nyilvános, nyugodtan lehet a kódban – a jogosultságokat az adatbázis szabályai védik.
// A service_role / secret kulcsot SOHA ne írd ide!
window.KOSARTIPP_CONFIG = {
  supabaseUrl: 'https://XXXXXXXX.supabase.co',
  supabaseAnonKey: 'IDE_JON_AZ_ANON_KULCS',
};
