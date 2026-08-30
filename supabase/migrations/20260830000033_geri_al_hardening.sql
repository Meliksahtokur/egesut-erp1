-- Fix: geri_al güvenlik sertleştirmesi (review 2026-08-30)
-- 1) Snapshot tablo whitelist'i (öndoğrulama — fail-closed, kısmi uygulama yok)
-- 2) EXCEPTION WHEN others -> SQLSTATE 42883/22P02 (yalnız tip hataları fallback)
-- 3) tohumlama_abort 3-param: anon yetkisi çekildi (auth-gate lockdown uyumu)
-- Taban: canlı prod gövdesi (assets/geri_al_canli_v2.sql)

CREATE OR REPLACE FUNCTION public.geri_al(p_islem_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_snapshot  jsonb;
  v_item      jsonb;
  v_tablo     text;
  v_pk        text;
  v_onceki    jsonb;
  v_col       text;
  v_val       text;
  v_set_parts text[] := '{}';
  v_sql       text;
BEGIN
  SELECT snapshot INTO v_snapshot
  FROM islem_log
  WHERE id = p_islem_id;

  IF v_snapshot IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'hata', 'islem bulunamadi');
  END IF;

  -- GÜVENLİK (review 2026-08-30): whitelist öndoğrulama — snapshot'taki tüm tablo
  -- adları bilinen undo yüzeyleriyle sınırlı (üretim geçmişi envanterinden türetildi).
  -- İzinsiz tablo görülürse HİÇBİR mutasyona başlamadan döner (tek transaction; kısmi uygulama yok).
  FOR v_item IN
    SELECT * FROM jsonb_array_elements(COALESCE(v_snapshot->'olusturulan','[]'::jsonb))
    UNION ALL
    SELECT * FROM jsonb_array_elements(COALESCE(v_snapshot->'guncellenen','[]'::jsonb))
  LOOP
    IF v_item->>'tablo' IS NULL OR v_item->>'tablo' NOT IN (
      'treatment_day_uygulamalar','gorev_log','treatment_days','hayvanlar',
      'uygulama_log','cases','tohumlama','stok_hareket','stok','vaccination_log',
      'drug_products','protokol_ayar','hekimler','padoklar','vaccines'
    ) THEN
      RETURN jsonb_build_object('ok', false, 'hata', 'Snapshot izin verilmeyen tablo iceriyor: ' || COALESCE(v_item->>'tablo','?'));
    END IF;
  END LOOP;

  FOR v_item IN SELECT * FROM jsonb_array_elements(v_snapshot->'olusturulan')
  LOOP
    v_tablo := v_item->>'tablo';
    v_pk    := v_item->>'id';

    IF v_tablo = 'treatment_days' THEN
      -- Stok iade: iptal=true (audit trail korunur — DELETE değil)
      UPDATE public.stok_hareket
      SET iptal = true
      WHERE notlar IN (
        SELECT 'drug_admin:' || da.id::text
        FROM public.drug_administrations da
        WHERE da.treatment_day_id = v_pk::uuid
      );
      -- Tedavi günü sil (CASCADE: drug_administrations otomatik)
      DELETE FROM public.treatment_days WHERE id = v_pk::uuid;

    ELSIF v_tablo = 'cases' THEN
      -- TEDAVI_GUN gorev orphan temizliği (snapshot'ta değil, manuel sil)
      DELETE FROM public.gorev_log g
      WHERE g.gorev_tipi = 'TEDAVI_GUN'
        AND EXISTS (
          SELECT 1 FROM public.treatment_days td
          WHERE td.case_id = v_pk::uuid
            AND g.aciklama IS NOT NULL
            AND (g.aciklama::jsonb->>'day_id')::uuid = td.id
        );

      -- Stok iade: tüm treatment_days için iptal=true
      UPDATE public.stok_hareket
      SET iptal = true
      WHERE notlar IN (
        SELECT 'drug_admin:' || da.id::text
        FROM public.drug_administrations da
        JOIN public.treatment_days td ON da.treatment_day_id = td.id
        WHERE td.case_id = v_pk::uuid
      );

      -- Case sil (CASCADE zinciri)
      DELETE FROM public.cases WHERE id = v_pk::uuid;

    ELSE
      BEGIN
        EXECUTE format('DELETE FROM %I WHERE id = $1', v_tablo) USING v_pk;
      EXCEPTION WHEN SQLSTATE '42883' OR SQLSTATE '22P02' THEN
        EXECUTE format('DELETE FROM %I WHERE id = $1::uuid', v_tablo) USING v_pk;
      END;
    END IF;
  END LOOP;

  FOR v_item IN SELECT * FROM jsonb_array_elements(v_snapshot->'guncellenen')
  LOOP
    v_tablo  := v_item->>'tablo';
    v_pk     := v_item->>'id';
    v_onceki := v_item->'onceki';
    v_set_parts := '{}';

    FOR v_col, v_val IN SELECT key, value #>> '{}' FROM jsonb_each(v_onceki)
    LOOP
      v_set_parts := array_append(
        v_set_parts,
        format('%I = %L', v_col, v_val)
      );
    END LOOP;

    IF array_length(v_set_parts, 1) > 0 THEN
      v_sql := format(
        'UPDATE %I SET %s WHERE id = $1',
        v_tablo,
        array_to_string(v_set_parts, ', ')
      );
      BEGIN
        EXECUTE v_sql USING v_pk;
      EXCEPTION WHEN SQLSTATE '42883' OR SQLSTATE '22P02' THEN
        -- uuid PK'lı tablolar (tohumlama vb.) için tip fallback'i —
        -- yalnız tip hatalarında; diğer hatalar aynen yükselir
        EXECUTE format(
          'UPDATE %I SET %s WHERE id = $1::uuid',
          v_tablo,
          array_to_string(v_set_parts, ', ')
        ) USING v_pk;
      END;
    END IF;
  END LOOP;

  UPDATE islem_log SET durum = 'geri_alindi' WHERE id = p_islem_id;
  RETURN jsonb_build_object('ok', true);
END;
$function$
;

REVOKE EXECUTE ON FUNCTION public.tohumlama_abort(text, text, date) FROM anon;
NOTIFY pgrst, 'reload schema';
