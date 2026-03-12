-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.bildirim_log (
  id text NOT NULL DEFAULT (gen_random_uuid())::text,
  hayvan_id text,
  tip text NOT NULL,
  mesaj text,
  durum text NOT NULL DEFAULT 'bekliyor'::text,
  erteleme_tarihi date,
  olusturma timestamp with time zone DEFAULT now(),
  guncelleme timestamp with time zone DEFAULT now(),
  CONSTRAINT bildirim_log_pkey PRIMARY KEY (id)
);
CREATE TABLE public.buzagi_takip (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  kupe_no text UNIQUE,
  cinsiyet text,
  irk text,
  dogum_tarihi date,
  anne_id text,
  sut_kesme_tarihi date,
  besi_satis_notu text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT buzagi_takip_pkey PRIMARY KEY (id),
  CONSTRAINT buzagi_takip_anne_id_fkey FOREIGN KEY (anne_id) REFERENCES public.hayvanlar(id)
);
CREATE TABLE public.cop_kutusu (
  id text NOT NULL DEFAULT (gen_random_uuid())::text,
  kaynak_tablo text NOT NULL,
  kaynak_id text NOT NULL,
  veri jsonb NOT NULL,
  silme_tarihi timestamp with time zone DEFAULT now(),
  otomatik_silme_tarihi timestamp with time zone DEFAULT (now() + '30 days'::interval),
  geri_yuklendi boolean DEFAULT false,
  silme_sebebi text,
  CONSTRAINT cop_kutusu_pkey PRIMARY KEY (id)
);
CREATE TABLE public.dogum (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  anne_id text,
  tarih date,
  yavru_cins text,
  yavru_kupe text,
  yavru_irk text,
  dogum_tipi text DEFAULT 'Normal'::text,
  created_at timestamp with time zone DEFAULT now(),
  hekim_id text,
  dogum_kg numeric,
  baba_bilgi text,
  CONSTRAINT dogum_pkey PRIMARY KEY (id),
  CONSTRAINT dogum_anne_id_fkey FOREIGN KEY (anne_id) REFERENCES public.hayvanlar(id)
);
CREATE TABLE public.gorev_log (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  hayvan_id text,
  gorev_tipi text,
  aciklama text,
  hedef_tarih date,
  tamamlandi boolean DEFAULT false,
  tamamlanma_tarihi timestamp with time zone,
  padok_hedef text,
  stok_id text,
  miktar numeric,
  stok_dusuldu boolean DEFAULT false,
  kaynak text,
  created_at timestamp with time zone DEFAULT now(),
  parent_id uuid,
  iptal boolean DEFAULT false,
  hekim_id text,
  CONSTRAINT gorev_log_pkey PRIMARY KEY (id),
  CONSTRAINT gorev_log_hayvan_id_fkey FOREIGN KEY (hayvan_id) REFERENCES public.hayvanlar(id)
);
CREATE TABLE public.hastalik_log (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  hayvan_id text,
  tarih date,
  kategori text,
  tani text,
  siddet text,
  semptomlar text,
  ilac_stok_id text,
  ilac_miktar numeric,
  durum text DEFAULT 'Aktif'::text,
  kapanis_tarihi date,
  veteriner_notu text,
  created_at timestamp with time zone DEFAULT now(),
  hekim_id text,
  kapanma_tarihi date,
  lokasyon text,
  CONSTRAINT hastalik_log_pkey PRIMARY KEY (id)
);
CREATE TABLE public.hayvanlar (
  id text NOT NULL,
  kupe_no text,
  cins text,
  irk text,
  dogum_tarihi date,
  dogum_kg numeric,
  kesim_kg numeric,
  grup text,
  padok text DEFAULT 'P1'::text,
  durum text DEFAULT 'Aktif'::text,
  cikis_tarihi date,
  cikis_sebebi text,
  satis_fiyati numeric,
  created_at timestamp with time zone DEFAULT now(),
  cinsiyet text,
  anne_id text,
  baba_bilgi text,
  canli_agirlik numeric,
  boy numeric,
  renk text,
  ayirici_ozellik text,
  devlet_kupe text,
  kategori text,
  suttten_kesme_tarihi date,
  tohumlama_onay_tarihi date,
  tohumlama_durumu text,
  cikis_tipi text,
  notlar text,
  abort_sayisi integer DEFAULT 0,
  CONSTRAINT hayvanlar_pkey PRIMARY KEY (id)
);
CREATE TABLE public.irk_esik (
  id text NOT NULL DEFAULT (gen_random_uuid())::text,
  irk text NOT NULL UNIQUE,
  tohumlama_gun integer NOT NULL DEFAULT 365,
  suttten_kesme_gun integer NOT NULL DEFAULT 60,
  guncelleme timestamp with time zone DEFAULT now(),
  kullanim_sayisi integer NOT NULL DEFAULT 0,
  CONSTRAINT irk_esik_pkey PRIMARY KEY (id)
);
CREATE TABLE public.islem_log (
  id text NOT NULL DEFAULT (gen_random_uuid())::text,
  tip text NOT NULL,
  ana_hayvan_id text,
  tarih timestamp with time zone DEFAULT now(),
  kullanici_notu text,
  durum text NOT NULL DEFAULT 'aktif'::text,
  geri_alma_tarihi timestamp with time zone,
  snapshot jsonb NOT NULL,
  ref_id text,
  ref_tablo text,
  CONSTRAINT islem_log_pkey PRIMARY KEY (id)
);
CREATE TABLE public.kizginlik_log (
  id text NOT NULL,
  hayvan_id text,
  tarih date,
  belirti text,
  notlar text,
  olusturma timestamp with time zone DEFAULT now(),
  CONSTRAINT kizginlik_log_pkey PRIMARY KEY (id)
);
CREATE TABLE public.stok (
  id text NOT NULL,
  urun_adi text,
  tur text,
  birim_turu text,
  birim text,
  baslangic_miktar numeric DEFAULT 0,
  esik numeric DEFAULT 0,
  maliyet numeric DEFAULT 0,
  notlar text,
  created_at timestamp with time zone DEFAULT now(),
  kategori text,
  CONSTRAINT stok_pkey PRIMARY KEY (id)
);
CREATE TABLE public.stok_hareket (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  stok_id text,
  tarih timestamp with time zone DEFAULT now(),
  tur text,
  miktar numeric,
  notlar text,
  iptal boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  referans_tipi text,
  referans_id text,
  CONSTRAINT stok_hareket_pkey PRIMARY KEY (id),
  CONSTRAINT stok_hareket_stok_id_fkey FOREIGN KEY (stok_id) REFERENCES public.stok(id)
);
CREATE TABLE public.tedavi (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  hayvan_id text,
  tarih date,
  tani text,
  ilac_stok_id text,
  miktar numeric,
  sut_yasagi_bitis date,
  aktif boolean DEFAULT true,
  vaka_id text,
  created_at timestamp with time zone DEFAULT now(),
  uygulama_yolu text,
  hekim_id text,
  bekleme_suresi_gun integer,
  notlar text,
  CONSTRAINT tedavi_pkey PRIMARY KEY (id),
  CONSTRAINT tedavi_hayvan_id_fkey FOREIGN KEY (hayvan_id) REFERENCES public.hayvanlar(id)
);
CREATE TABLE public.tohumlama (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  hayvan_id text,
  tarih date,
  sperma text,
  irk_bilgisi text,
  tohumlayan text,
  kontrol_tarihi date,
  sonuc text DEFAULT 'Bekliyor'::text,
  deneme_no integer DEFAULT 1,
  created_at timestamp with time zone DEFAULT now(),
  hekim_id text,
  dogum_tarihi date,
  buzagi_kupe text,
  abort_notlar text,
  CONSTRAINT tohumlama_pkey PRIMARY KEY (id),
  CONSTRAINT tohumlama_hayvan_id_fkey FOREIGN KEY (hayvan_id) REFERENCES public.hayvanlar(id)
);