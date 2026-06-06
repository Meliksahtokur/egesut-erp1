BEGIN;

-- ── 1. _protokol_kapat: tek kaynak_ref'e göre protokol kapat + görevleri iptal et ──
CREATE OR REPLACE FUNCTION public._protokol_kapat(
  p_kaynak_ref  text,
  p_sebep       text  -- DOGUM | OLUM | SATIS | MANUEL | TAMAMLANDI
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.gorev_log
  SET iptal = true
  WHERE kaynak = p_kaynak_ref
    AND tamamlandi = false
    AND iptal = false;

  UPDATE public.protokol_instance
  SET durum = 'iptal',
      kapandi_at = now(),
      kapandi_sebep = p_sebep
  WHERE kaynak_ref = p_kaynak_ref
    AND durum = 'aktif';
END;
$$;

GRANT EXECUTE ON FUNCTION public._protokol_kapat(text, text) TO anon, authenticated;

-- ── 2. cikis_yap: hayvan çıkışı — tüm pending görevler + tüm aktif protokoller iptal ──
CREATE OR REPLACE FUNCTION public.cikis_yap(
  p_hayvan_id    text,
  p_cikis_tipi   text,           -- 'olum' | 'satis'
  p_cikis_tarihi date    DEFAULT (NOW() AT TIME ZONE 'Europe/Istanbul')::date,
  p_cikis_sebebi text    DEFAULT NULL,
  p_satis_fiyati numeric DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_durum_yeni      text;
  v_iptal_gorev_say integer;
  v_iptal_inst_say  integer;
BEGIN
  IF p_cikis_tipi = 'olum' THEN
    v_durum_yeni := 'Ölü';
  ELSIF p_cikis_tipi = 'satis' THEN
    v_durum_yeni := 'Satıldı';
  ELSE
    RAISE EXCEPTION 'Geçersiz çıkış tipi: % (beklenen: olum veya satis)', p_cikis_tipi;
  END IF;

  UPDATE public.hayvanlar
  SET durum        = v_durum_yeni,
      cikis_tipi   = p_cikis_tipi,
      cikis_tarihi = p_cikis_tarihi,
      cikis_sebebi = p_cikis_sebebi,
      satis_fiyati = CASE WHEN p_cikis_tipi = 'satis' THEN p_satis_fiyati ELSE satis_fiyati END
  WHERE id = p_hayvan_id AND durum = 'Aktif';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Aktif hayvan bulunamadı: ' || p_hayvan_id);
  END IF;

  -- TÜM pending görevleri iptal et (kaynak bağımsız)
  UPDATE public.gorev_log
  SET iptal = true
  WHERE hayvan_id = p_hayvan_id
    AND tamamlandi = false
    AND iptal = false;

  GET DIAGNOSTICS v_iptal_gorev_say = ROW_COUNT;

  -- TÜM aktif protokol instance'larını kapat
  UPDATE public.protokol_instance
  SET durum = 'iptal',
      kapandi_at = now(),
      kapandi_sebep = upper(p_cikis_tipi)
  WHERE hayvan_id = p_hayvan_id
    AND durum = 'aktif';

  GET DIAGNOSTICS v_iptal_inst_say = ROW_COUNT;

  RETURN jsonb_build_object(
    'ok',              true,
    'hayvan_id',       p_hayvan_id,
    'durum',           v_durum_yeni,
    'iptal_gorev',     v_iptal_gorev_say,
    'iptal_protokol',  v_iptal_inst_say
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.cikis_yap(text, text, date, text, numeric) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
