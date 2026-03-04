CREATE TABLE IF NOT EXISTS public.hayvanlar (
  id text PRIMARY KEY,
  kupe_no text,
  devlet_kupe text,
  irk text,
  cinsiyet text,
  dogum_tarihi date,
  dogum_kg numeric,
  canli_agirlik numeric,
  boy numeric,
  renk text,
  ayirici_ozellik text,
  anne_id text,
  baba_bilgi text,
  grup text,
  padok text,
  durum text DEFAULT 'Aktif'
);

CREATE TABLE IF NOT EXISTS public.stok (
  id text PRIMARY KEY,
  urun_adi text NOT NULL,
  kategori text,
  birim text,
  baslangic_miktar numeric DEFAULT 0,
  esik numeric DEFAULT 0
);

CREATE TABLE IF NOT EXISTS public.stok_hareket (
  id text PRIMARY KEY,
  stok_id text,
  tur text,
  miktar numeric,
  notlar text,
  iptal boolean DEFAULT false
);

CREATE TABLE IF NOT EXISTS public.gorev_log (
  id text PRIMARY KEY,
  hayvan_id text,
  gorev_tipi text,
  aciklama text,
  hedef_tarih date,
  tamamlandi boolean DEFAULT false,
  tamamlanma_tarihi timestamptz,
  parent_id text,
  stok_id text,
  miktar numeric,
  hekim_id text,
  kaynak text,
  padok_hedef text,
  iptal boolean DEFAULT false
);

CREATE TABLE IF NOT EXISTS public.hastalik_log (
  id text PRIMARY KEY,
  hayvan_id text,
  tarih date,
  kategori text,
  tani text,
  siddet text,
  semptomlar text,
  hekim_id text,
  ilac_stok_id text,
  ilac_miktar numeric,
  durum text DEFAULT 'Aktif',
  kapanma_tarihi date
);

CREATE TABLE IF NOT EXISTS public.tohumlama (
  id text PRIMARY KEY,
  hayvan_id text,
  tarih date,
  sperma text,
  hekim_id text,
  sonuc text DEFAULT 'Bekliyor',
  deneme_no integer DEFAULT 1
);

CREATE TABLE IF NOT EXISTS public.dogum (
  id text PRIMARY KEY,
  anne_id text,
  tarih date,
  yavru_cins text,
  yavru_kupe text,
  dogum_tipi text,
  dogum_kg numeric,
  baba_bilgi text,
  hekim_id text
);

CREATE TABLE IF NOT EXISTS public.buzagi_takip (
  id text PRIMARY KEY,
  kupe_no text,
  cinsiyet text,
  dogum_tarihi date,
  anne_id text
);

NOTIFY pgrst, 'reload schema';
