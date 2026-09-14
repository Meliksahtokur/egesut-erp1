-- G-20260914-GERI-ALMA-AKISI — W1 §2-6: geri alma motoru genişletmesi
--
-- Frozen contract: .harness/goals/2026/G-20260914-GERI-ALMA-AKISI.md,
--   "Frozen contract — FAZ B motor genişletmesi" §2-6 (K1 zincir kapsamı dahil).
--   §2  p_hedef.zaman (ISO; tablo+pk ile): nearest kayit_zamani within 120 s,
--       else HEDEF_BULUNAMADI + detay.neden='ZAMAN_ESLESME_YOK'. txid wins.
--   §3  p_seviye='zincir' (ADDITIVE; alan|satir|islem unchanged):
--       (a) same-row later changes of every planned (tablo,pk);
--       (b) dependency-graph rows (FK children + hayvan bridge) whose later
--           changes would block/conflict; irrelevant parent-side edits (the
--           hayvanlar row itself) stay OUT. Order: same-row newest-first,
--           dependents before their anchor (log id DESC + EKLE topo).
--       TEK transaction, tek geri_alma_txid; cap 100 (ZINCIR_COK_UZUN);
--       geri_alinabilir=false → sirali_rehber (newest first, individually
--       revertible {tablo,pk,txid} targets).
--   §4  cakismalar: FULL list of later changes (not just the first) with
--       zaman, degisen_alanlar, islem, log_id (all levels).
--   §5  HEDEF_BULUNAMADI detay.neden: SATIR_YOK | LOG_YOK | ZAMAN_ESLESME_YOK.
--   §6  Telafi kaydı: degisim_geri_al (every level incl. zincir) inserts
--       islem_log(tip='GERI_ALINDI', ref_id/ref_tablo, ana_hayvan_id,
--       payload={orijinal_tip,seviye,adim}) in the SAME transaction;
--       original islem_log rows untouched (immutable guard only blocks U/D).
--
-- All changes ADDITIVE: the 4 existing RPC signatures and the alan/satir/islem
-- behavior are unchanged (k3 46-case regression, V9). Replay-safe.
--
-- DEMO ONLY until the owner's prod deploy gate.

BEGIN;

-- ── L4 §2 helper: nearest-log txid for a (tablo,pk) within 120 s ────────────
CREATE OR REPLACE FUNCTION surum_gizli._l4_zaman_txid(
  p_tablo text,
  p_pk    jsonb,
  p_zaman text,
  OUT o_txid    bigint,
  OUT o_neden   text,
  OUT o_enyakin timestamptz)
RETURNS record
LANGUAGE plpgsql
STABLE
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_zt timestamptz;
BEGIN
  o_txid    := NULL;
  o_neden   := NULL;
  o_enyakin := NULL;
  BEGIN
    v_zt := p_zaman::timestamptz;
  EXCEPTION WHEN others THEN
    o_neden := 'ZAMAN_GECERSIZ';
    RETURN;
  END;
  SELECT l.txid INTO o_txid
    FROM public.degisim_log l
   WHERE l.tablo_adi = p_tablo AND l.satir_pk = p_pk
     AND l.kayit_zamani BETWEEN v_zt - interval '120 seconds'
                            AND v_zt + interval '120 seconds'
   ORDER BY abs(extract(epoch FROM l.kayit_zamani - v_zt)), l.id
   LIMIT 1;
  IF o_txid IS NOT NULL THEN
    RETURN;
  END IF;
  SELECT l.kayit_zamani INTO o_enyakin
    FROM public.degisim_log l
   WHERE l.tablo_adi = p_tablo AND l.satir_pk = p_pk
   ORDER BY abs(extract(epoch FROM l.kayit_zamani - v_zt)), l.id
   LIMIT 1;
  IF o_enyakin IS NULL THEN
    o_neden := CASE WHEN surum_gizli._guncel_satir(p_tablo, p_pk) IS NULL
                    THEN 'SATIR_YOK' ELSE 'LOG_YOK' END;
  ELSE
    o_neden := 'ZAMAN_ESLESME_YOK';
  END IF;
END;
$$;

-- ── plan: extended in place (zaman target, neden detail, full conflicts) ────
CREATE OR REPLACE FUNCTION surum_gizli._degisim_plan(p_hedef jsonb, p_seviye text)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path = pg_catalog, public
AS $$
DECLARE
  c_teknik  CONSTANT text[] := ARRAY['created_at','updated_at','olusturma',
                                     'guncelleme','guncelleme_tarihi','guncellendi'];
  v_txid    bigint;
  v_tablo   text;
  v_pk      jsonb;
  v_alan    text;
  v_zaman   text;
  v_neden   text;
  v_enyakin timestamptz;
  v_ids     bigint[];
  v_work    bigint[];
  v_eid     bigint;
  v_cids    bigint[];
  v_ctx     bigint[];
  v_cpk     jsonb;
  v_cur     jsonb;
  v_fields  text[];
  v_exists  boolean;
  e         public.degisim_log;
  fk        record;
  ch        record;
  r         record;
  v_ekle    public.degisim_log[];
  v_sirali  public.degisim_log[];
  v_topo    public.degisim_log[] := ARRAY[]::public.degisim_log[];
  v_n       int;
  v_derece  int[];
  v_cikti   boolean[];
  v_kalan   int;
  v_bulundu boolean;
  i         int;
  j         int;
  v_plan    jsonb  := '[]'::jsonb;
  v_cak     jsonb  := '[]'::jsonb;
  v_cak_e   jsonb;
  v_bag     jsonb  := '[]'::jsonb;
  v_stok    jsonb  := '[]'::jsonb;
  v_eng     text[] := '{}';
  v_sira    int    := 0;
BEGIN
  IF p_seviye IS NULL OR p_seviye NOT IN ('alan', 'satir', 'islem') THEN
    RETURN jsonb_build_object('ok', false, 'hata', 'GECERSIZ_SEVIYE');
  END IF;
  IF p_hedef IS NULL OR jsonb_typeof(p_hedef) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'hata', 'GECERSIZ_HEDEF');
  END IF;
  IF nullif(p_hedef ->> 'txid', '') IS NOT NULL THEN
    BEGIN
      v_txid := (p_hedef ->> 'txid')::bigint;
    EXCEPTION WHEN others THEN
      RETURN jsonb_build_object('ok', false, 'hata', 'GECERSIZ_HEDEF');
    END;
  END IF;
  -- L4 §2: optional 'zaman' (ISO text) with tablo+pk; an explicit txid wins
  v_zaman := nullif(p_hedef ->> 'zaman', '');

  -- ── 1. target entries ──
  IF p_seviye = 'islem' THEN
    IF v_txid IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'hata', 'GECERSIZ_HEDEF');
    END IF;
    SELECT array_agg(id ORDER BY id) INTO v_ids FROM public.degisim_log WHERE txid = v_txid;
    IF v_ids IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'hata', 'HEDEF_BULUNAMADI',
        'detay', jsonb_build_object('neden', 'LOG_YOK'));
    END IF;
  ELSE
    v_tablo := p_hedef ->> 'tablo';
    IF v_tablo IS NULL OR NOT surum_gizli._kapsamda(v_tablo) THEN
      RETURN jsonb_build_object('ok', false, 'hata', 'GECERSIZ_HEDEF');
    END IF;
    v_pk := surum_gizli._pk_json(v_tablo, p_hedef -> 'pk');
    IF v_pk IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'hata', 'GECERSIZ_HEDEF');
    END IF;

    IF p_seviye = 'alan' THEN
      v_alan := p_hedef ->> 'alan';
      IF v_alan IS NULL OR NOT EXISTS (
           SELECT 1 FROM pg_attribute
            WHERE attrelid = format('public.%I', v_tablo)::regclass
              AND attname = v_alan AND attnum > 0 AND NOT attisdropped) THEN
        RETURN jsonb_build_object('ok', false, 'hata', 'GECERSIZ_HEDEF');
      END IF;
      IF v_txid IS NULL AND v_zaman IS NOT NULL THEN
        SELECT o_txid, o_neden, o_enyakin INTO v_txid, v_neden, v_enyakin
          FROM surum_gizli._l4_zaman_txid(v_tablo, v_pk, v_zaman);
        IF v_txid IS NULL THEN
          IF v_neden = 'ZAMAN_GECERSIZ' THEN
            RETURN jsonb_build_object('ok', false, 'hata', 'GECERSIZ_HEDEF');
          END IF;
          RETURN jsonb_build_object('ok', false, 'hata', 'HEDEF_BULUNAMADI',
            'detay', jsonb_build_object('neden', v_neden, 'zaman', v_zaman,
                                        'en_yakin', v_enyakin));
        END IF;
      END IF;
      IF v_txid IS NULL THEN
        SELECT txid INTO v_txid FROM public.degisim_log
         WHERE tablo_adi = v_tablo AND satir_pk = v_pk
           AND (islem <> 'U' OR v_alan = ANY (degisen_alanlar))
         ORDER BY id DESC LIMIT 1;
      END IF;
      IF v_txid IS NULL OR NOT EXISTS (
           SELECT 1 FROM public.degisim_log
            WHERE txid = v_txid AND tablo_adi = v_tablo AND satir_pk = v_pk) THEN
        RETURN jsonb_build_object('ok', false, 'hata', 'HEDEF_BULUNAMADI',
          'detay', jsonb_build_object('neden',
            CASE WHEN v_txid IS NULL
                  AND surum_gizli._guncel_satir(v_tablo, v_pk) IS NULL
                 THEN 'SATIR_YOK' ELSE 'LOG_YOK' END));
      END IF;
      SELECT array_agg(id ORDER BY id) INTO v_ids FROM public.degisim_log
       WHERE txid = v_txid AND tablo_adi = v_tablo AND satir_pk = v_pk
         AND islem = 'U' AND v_alan = ANY (degisen_alanlar);
      IF v_ids IS NULL THEN
        -- the row changed in that tx, but not as an UPDATE of this field
        RETURN jsonb_build_object('ok', false, 'hata', 'GECERSIZ_HEDEF');
      END IF;
    ELSE
      IF v_txid IS NULL AND v_zaman IS NOT NULL THEN
        SELECT o_txid, o_neden, o_enyakin INTO v_txid, v_neden, v_enyakin
          FROM surum_gizli._l4_zaman_txid(v_tablo, v_pk, v_zaman);
        IF v_txid IS NULL THEN
          IF v_neden = 'ZAMAN_GECERSIZ' THEN
            RETURN jsonb_build_object('ok', false, 'hata', 'GECERSIZ_HEDEF');
          END IF;
          RETURN jsonb_build_object('ok', false, 'hata', 'HEDEF_BULUNAMADI',
            'detay', jsonb_build_object('neden', v_neden, 'zaman', v_zaman,
                                        'en_yakin', v_enyakin));
        END IF;
      END IF;
      IF v_txid IS NULL THEN
        SELECT txid INTO v_txid FROM public.degisim_log
         WHERE tablo_adi = v_tablo AND satir_pk = v_pk
         ORDER BY id DESC LIMIT 1;
        IF v_txid IS NULL THEN
          RETURN jsonb_build_object('ok', false, 'hata', 'HEDEF_BULUNAMADI',
            'detay', jsonb_build_object('neden',
              CASE WHEN surum_gizli._guncel_satir(v_tablo, v_pk) IS NULL
                   THEN 'SATIR_YOK' ELSE 'LOG_YOK' END));
        END IF;
      END IF;
      SELECT array_agg(id ORDER BY id) INTO v_ids FROM public.degisim_log
       WHERE txid = v_txid AND tablo_adi = v_tablo AND satir_pk = v_pk;
      IF v_ids IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'hata', 'HEDEF_BULUNAMADI',
          'detay', jsonb_build_object('neden', 'LOG_YOK'));
      END IF;

      -- stock movements of the same tx that reference this row join the plan
      IF v_tablo <> 'stok_hareket'
         AND (SELECT count(*) FROM jsonb_object_keys(v_pk)) = 1 THEN
        v_ids := v_ids || ARRAY(
          SELECT id FROM public.degisim_log
           WHERE txid = v_txid AND tablo_adi = 'stok_hareket'
             AND coalesce(yeni, eski) ->> 'referans_id' = (SELECT v #>> '{}' FROM jsonb_each(v_pk) AS x(k, v))
             AND id <> ALL (v_ids));
      END IF;
    END IF;
  END IF;

  IF v_ids IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'hata', 'HEDEF_BULUNAMADI',
      'detay', jsonb_build_object('neden', 'LOG_YOK'));
  END IF;

  -- ── 2. dependencies of rows the plan will DELETE (reverting an INSERT) ──
  IF p_seviye <> 'alan' THEN
    v_work := ARRAY(SELECT id FROM public.degisim_log WHERE id = ANY (v_ids) AND islem = 'I' ORDER BY id);
    WHILE cardinality(v_work) > 0 LOOP
      v_eid := v_work[1];
      v_work := v_work[2:];
      SELECT * INTO e FROM public.degisim_log WHERE id = v_eid;
      FOR fk IN
        SELECT cc.relname::text AS child, con.conrelid AS child_rel, con.confdeltype,
               array_agg(ca.attname::text ORDER BY k.ord) AS ccols,
               array_agg(pa.attname::text ORDER BY k.ord) AS pcols
          FROM pg_constraint con
          JOIN pg_class cc ON cc.oid = con.conrelid
          CROSS JOIN LATERAL unnest(con.conkey, con.confkey) WITH ORDINALITY AS k(ck, pk, ord)
          JOIN pg_attribute ca ON ca.attrelid = con.conrelid AND ca.attnum = k.ck
          JOIN pg_attribute pa ON pa.attrelid = con.confrelid AND pa.attnum = k.pk
         WHERE con.contype = 'f'
           AND con.confrelid = format('public.%I', e.tablo_adi)::regclass
           AND cc.relnamespace = 'public'::regnamespace
         GROUP BY 1, 2, 3
      LOOP
        FOR ch IN EXECUTE format(
            'SELECT to_jsonb(c) AS j FROM public.%I c WHERE (%s) = (SELECT %s FROM jsonb_populate_record(NULL::public.%I, $1))',
            fk.child,
            (SELECT string_agg(format('c.%I', x), ', ') FROM unnest(fk.ccols) x),
            (SELECT string_agg(format('%I', x), ', ') FROM unnest(fk.pcols) x),
            e.tablo_adi)
          USING e.yeni
        LOOP
          SELECT jsonb_object_agg(a.attname, ch.j -> a.attname) INTO v_cpk
            FROM pg_constraint pc
            CROSS JOIN LATERAL unnest(pc.conkey) AS u(n)
            JOIN pg_attribute a ON a.attrelid = pc.conrelid AND a.attnum = u.n
           WHERE pc.conrelid = fk.child_rel AND pc.contype = 'p';
          SELECT array_agg(id), array_agg(DISTINCT txid) INTO v_cids, v_ctx
            FROM public.degisim_log WHERE tablo_adi = fk.child AND satir_pk = v_cpk;

          IF v_cids && v_ids THEN
            CONTINUE;                                   -- already in the plan
          ELSIF v_cids IS NULL THEN
            -- untracked child (pre-system or written with triggers off)
            v_bag := v_bag || jsonb_build_object(
              'tablo', fk.child, 'pk', surum_gizli._pk_gorunum(v_cpk), 'satir_pk', v_cpk,
              'iliski', format('%s(%s) -> %s', fk.child, array_to_string(fk.ccols, ','), e.tablo_adi),
              'etki', CASE WHEN fk.confdeltype = 'n' THEN 'UYARI' ELSE 'ENGEL' END);
            IF fk.confdeltype <> 'n' THEN
              v_eng := v_eng || format('%s kaydı %s geçmişi olmayan bağımlı kayıt', fk.child, surum_gizli._pk_gorunum(v_cpk));
            END IF;
          ELSIF v_ctx = ARRAY[e.txid] THEN
            -- child born and only changed in the same tx: cascade it
            v_bag := v_bag || jsonb_build_object(
              'tablo', fk.child, 'pk', surum_gizli._pk_gorunum(v_cpk), 'satir_pk', v_cpk,
              'iliski', format('%s(%s) -> %s', fk.child, array_to_string(fk.ccols, ','), e.tablo_adi),
              'etki', 'KADEMELI');
            v_ids := v_ids || v_cids;
            v_work := v_work || ARRAY(SELECT id FROM public.degisim_log WHERE id = ANY (v_cids) AND islem = 'I');
          ELSE
            v_bag := v_bag || jsonb_build_object(
              'tablo', fk.child, 'pk', surum_gizli._pk_gorunum(v_cpk), 'satir_pk', v_cpk,
              'iliski', format('%s(%s) -> %s', fk.child, array_to_string(fk.ccols, ','), e.tablo_adi),
              'etki', 'ENGEL');
            v_eng := v_eng || format('%s kaydı %s hedef işlemden sonra değişmiş bağımlı kayıt', fk.child, surum_gizli._pk_gorunum(v_cpk));
          END IF;
        END LOOP;
      END LOOP;
    END LOOP;

    -- rows the plan re-INSERTs (reverting a DELETE) need their FK parents
    FOR e IN SELECT * FROM public.degisim_log WHERE id = ANY (v_ids) AND islem = 'D' LOOP
      FOR fk IN
        SELECT pcl.relname::text AS parent, con.confdeltype,
               array_agg(ca.attname::text ORDER BY k.ord) AS ccols,
               array_agg(pa.attname::text ORDER BY k.ord) AS pcols
          FROM pg_constraint con
          JOIN pg_class pcl ON pcl.oid = con.confrelid
          CROSS JOIN LATERAL unnest(con.conkey, con.confkey) WITH ORDINALITY AS k(ck, pk, ord)
          JOIN pg_attribute ca ON ca.attrelid = con.conrelid AND ca.attnum = k.ck
          JOIN pg_attribute pa ON pa.attrelid = con.confrelid AND pa.attnum = k.pk
         WHERE con.contype = 'f'
           AND con.conrelid = format('public.%I', e.tablo_adi)::regclass
           AND pcl.relnamespace = 'public'::regnamespace
         GROUP BY 1, 2
      LOOP
        CONTINUE WHEN EXISTS (SELECT 1 FROM unnest(fk.ccols) c WHERE e.eski ->> c IS NULL);
        EXECUTE format(
          'SELECT EXISTS (SELECT 1 FROM public.%I p WHERE (%s) = (SELECT %s FROM jsonb_populate_record(NULL::public.%I, $1)))',
          fk.parent,
          (SELECT string_agg(format('p.%I', x), ', ') FROM unnest(fk.pcols) x),
          (SELECT string_agg(format('%I', x), ', ') FROM unnest(fk.ccols) x),
          e.tablo_adi)
          INTO v_exists USING e.eski;
        IF NOT v_exists AND NOT EXISTS (
             SELECT 1 FROM public.degisim_log d
              WHERE d.id = ANY (v_ids) AND d.tablo_adi = fk.parent AND d.islem = 'D'
                AND NOT EXISTS (SELECT 1 FROM unnest(fk.pcols, fk.ccols) AS u(p, c)
                                 WHERE d.eski ->> u.p IS DISTINCT FROM e.eski ->> u.c)) THEN
          v_bag := v_bag || jsonb_build_object(
            'tablo', fk.parent, 'pk', NULL,
            'iliski', format('%s(%s) -> %s(%s)', e.tablo_adi, array_to_string(fk.ccols, ','),
                             fk.parent, array_to_string(fk.pcols, ',')),
            'etki', 'ENGEL');
          v_eng := v_eng || format('%s kaydı geri eklenemez: üst kayıt (%s) yok', e.tablo_adi, fk.parent);
        END IF;
      END LOOP;
    END LOOP;
  END IF;

  -- ── 3. conflicts: L4 §4 — the FULL list of later changes on each planned
  --    row (UI builds the chain offer from this), or state drift ──
  FOR r IN
    SELECT tablo_adi, satir_pk, max(id) AS son_id
      FROM public.degisim_log WHERE id = ANY (v_ids) GROUP BY 1, 2
  LOOP
    SELECT coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
             'tablo', l.tablo_adi, 'pk', surum_gizli._pk_gorunum(r.satir_pk),
             'satir_pk', r.satir_pk, 'alan', v_alan, 'neden', 'SONRAKI_DEGISIKLIK',
             'txid', l.txid::text, 'zaman', l.kayit_zamani,
             'degisen_alanlar', to_jsonb(l.degisen_alanlar),
             'islem', l.islem, 'log_id', l.id)) ORDER BY l.id), '[]'::jsonb)
      INTO v_cak_e
      FROM public.degisim_log l
     WHERE l.tablo_adi = r.tablo_adi AND l.satir_pk = r.satir_pk
       AND l.id > r.son_id AND l.id <> ALL (v_ids)
       AND (p_seviye <> 'alan' OR l.islem <> 'U' OR v_alan = ANY (l.degisen_alanlar))
       -- L4 sıralı rehber (yalnız hedefte l4_rehber işareti varken): geri-alma
       -- motorunun kendi izleri ve etkisi daha sonra dönülmüş sonraki
       -- değişiklikler engel sayılmaz ("önce 5'i, sonra 4'ü geri al" akışı).
       -- İşaretsiz hedeflerde L2'nin katı kuralı AYNEN korunur (k3 S6c).
       AND (
             COALESCE((p_hedef ->> 'l4_rehber')::boolean, false) = false
             OR (l.kaynak ? 'geri_alma' = false
                 AND NOT EXISTS (
                       SELECT 1 FROM public.degisim_log r2
                        WHERE r2.tablo_adi = l.tablo_adi AND r2.satir_pk = l.satir_pk
                          AND r2.id > l.id AND r2.kaynak ? 'geri_alma')));
    IF jsonb_array_length(v_cak_e) > 0 THEN
      v_cak := v_cak || v_cak_e;
      CONTINUE;
    END IF;

    SELECT * INTO e FROM public.degisim_log WHERE id = r.son_id;
    v_cur := surum_gizli._guncel_satir(r.tablo_adi, r.satir_pk);
    IF e.islem = 'D' THEN
      IF v_cur IS NOT NULL THEN
        v_cak := v_cak || jsonb_strip_nulls(jsonb_build_object(
          'tablo', r.tablo_adi, 'pk', surum_gizli._pk_gorunum(r.satir_pk), 'satir_pk', r.satir_pk,
          'neden', 'GUNCEL_DURUM_FARKLI'));
      END IF;
    ELSE
      v_fields := CASE WHEN p_seviye = 'alan' THEN ARRAY[v_alan]
                       ELSE ARRAY(SELECT jsonb_object_keys(e.yeni)) END;
      IF v_cur IS NULL OR EXISTS (
           SELECT 1 FROM unnest(v_fields) f
            WHERE f <> ALL (c_teknik) AND v_cur ? f
              AND (v_cur -> f) IS DISTINCT FROM (e.yeni -> f)) THEN
        v_cak := v_cak || jsonb_strip_nulls(jsonb_build_object(
          'tablo', r.tablo_adi, 'pk', surum_gizli._pk_gorunum(r.satir_pk), 'satir_pk', r.satir_pk,
          'alan', v_alan, 'neden', 'GUNCEL_DURUM_FARKLI'));
      END IF;
    END IF;
  END LOOP;

  SELECT v_eng || coalesce(array_agg(format('%s kaydı %s: %s', c ->> 'tablo', c -> 'pk', c ->> 'neden')), '{}')
    INTO v_eng FROM jsonb_array_elements(v_cak) c;

  -- ── 4. stock advisories (informational, never blocking) ──
  IF p_seviye <> 'islem' THEN
    FOR e IN
      SELECT * FROM public.degisim_log
       WHERE txid = v_txid AND tablo_adi = 'stok_hareket' AND id <> ALL (v_ids)
    LOOP
      v_stok := v_stok || jsonb_build_object(
        'stok_id', coalesce(e.yeni, e.eski) ->> 'stok_id',
        'metin', format('Aynı işlemdeki stok hareketi (%s) bu geri almaya dahil değil; stok elle kontrol edilmeli',
                        e.satir_pk ->> 'id'));
    END LOOP;
  END IF;
  FOR r IN
    SELECT DISTINCT tablo_adi, satir_pk FROM public.degisim_log
     WHERE id = ANY (v_ids) AND tablo_adi <> 'stok_hareket'
       AND (SELECT count(*) FROM jsonb_object_keys(satir_pk)) = 1
  LOOP
    FOR e IN
      SELECT * FROM public.degisim_log l
       WHERE l.tablo_adi = 'stok_hareket' AND l.id <> ALL (v_ids)
         AND coalesce(l.yeni, l.eski) ->> 'referans_id' = (SELECT v #>> '{}' FROM jsonb_each(r.satir_pk) AS x(k, v))
    LOOP
      v_stok := v_stok || jsonb_build_object(
        'stok_id', coalesce(e.yeni, e.eski) ->> 'stok_id',
        'metin', format('%s kaydına bağlı stok hareketi (txid %s) bu geri almaya dahil değil; stok elle kontrol edilmeli',
                        r.tablo_adi, e.txid));
    END LOOP;
  END LOOP;

  -- ── 5. plan steps ──
  -- EKLE steps (reverting DELETEs) are topologically ordered parents-first:
  -- cascade children carry HIGHER log ids than the parent, so plain id-DESC
  -- would re-insert the child before its parent (FK 23503, deterministic
  -- failure). U/SIL steps keep reverse log order (undo-last-first). Kahn's
  -- algorithm over the plan-local FK graph; on an impossible cycle fall
  -- back to id order for the remainder.
  SELECT coalesce(array_agg(x ORDER BY x.id), ARRAY[]::public.degisim_log[])
    INTO v_ekle
    FROM public.degisim_log x
   WHERE x.id = ANY (v_ids) AND x.islem = 'D';
  SELECT coalesce(array_agg(x ORDER BY x.id DESC), ARRAY[]::public.degisim_log[])
    INTO v_sirali
    FROM public.degisim_log x
   WHERE x.id = ANY (v_ids) AND x.islem <> 'D';

  v_n := coalesce(cardinality(v_ekle), 0);
  IF v_n > 0 THEN
    v_derece := array_fill(0, ARRAY[v_n]);
    v_cikti  := array_fill(false, ARRAY[v_n]);
    FOR i IN 1 .. v_n LOOP
      FOR j IN 1 .. v_n LOOP
        CONTINUE WHEN i = j;
        IF surum_gizli._ekle_bagli(v_ekle[j], v_ekle[i]) THEN   -- i depends on j
          v_derece[i] := v_derece[i] + 1;
        END IF;
      END LOOP;
    END LOOP;
    v_kalan := v_n;
    WHILE v_kalan > 0 LOOP
      v_bulundu := false;
      FOR i IN 1 .. v_n LOOP
        CONTINUE WHEN v_cikti[i] OR v_derece[i] > 0;
        v_cikti[i] := true;
        v_kalan := v_kalan - 1;
        v_bulundu := true;
        v_topo := v_topo || v_ekle[i];
        FOR j IN 1 .. v_n LOOP
          CONTINUE WHEN v_cikti[j];
          IF surum_gizli._ekle_bagli(v_ekle[i], v_ekle[j]) THEN
            v_derece[j] := v_derece[j] - 1;
          END IF;
        END LOOP;
        EXIT;
      END LOOP;
      IF NOT v_bulundu THEN   -- cycle: emit remaining in id order
        FOR i IN 1 .. v_n LOOP
          CONTINUE WHEN v_cikti[i];
          v_cikti[i] := true;
          v_kalan := v_kalan - 1;
          v_topo := v_topo || v_ekle[i];
        END LOOP;
      END IF;
    END LOOP;
    v_sirali := v_topo || v_sirali;
  END IF;

  -- cascade children erased together with a parent whose DELETE is being
  -- reverted only partially (satir-level on the parent): they stay gone —
  -- informational, never blocking
  IF p_seviye <> 'islem' THEN
    FOR e IN SELECT * FROM public.degisim_log WHERE id = ANY (v_ids) AND islem = 'D' LOOP
      FOR ch IN
        SELECT c.* FROM public.degisim_log c
         WHERE c.txid = e.txid AND c.islem = 'D' AND c.id <> ALL (v_ids)
           AND surum_gizli._ekle_bagli(e, c)
      LOOP
        v_bag := v_bag || jsonb_build_object(
          'tablo', ch.tablo_adi, 'pk', surum_gizli._pk_gorunum(ch.satir_pk), 'satir_pk', ch.satir_pk,
          'iliski', format('%s kaydı %s ile aynı işlemde silinmiş ve bu geri almaya dahil değil',
                           ch.tablo_adi, e.tablo_adi),
          'etki', 'UYARI');
      END LOOP;
    END LOOP;
  END IF;

  FOREACH e IN ARRAY v_sirali LOOP
    v_sira := v_sira + 1;
    v_fields := CASE WHEN e.islem <> 'U' THEN NULL
                     WHEN p_seviye = 'alan' THEN ARRAY[v_alan]
                     ELSE e.degisen_alanlar END;
    v_plan := v_plan || jsonb_build_object(
      'sira', v_sira,
      'log_id', e.id,
      'txid', e.txid::text,
      'tablo', e.tablo_adi,
      'pk', surum_gizli._pk_gorunum(e.satir_pk),
      'satir_pk', e.satir_pk,
      'islem', e.islem,
      'alanlar', to_jsonb(v_fields),
      'eski', CASE e.islem WHEN 'U' THEN (SELECT jsonb_object_agg(f, e.eski -> f) FROM unnest(v_fields) f)
                           WHEN 'D' THEN e.eski END,
      'yeni', CASE e.islem WHEN 'U' THEN (SELECT jsonb_object_agg(f, e.yeni -> f) FROM unnest(v_fields) f)
                           WHEN 'I' THEN e.yeni END,
      'yapilacak', CASE e.islem WHEN 'U' THEN 'GUNCELLE' WHEN 'I' THEN 'SIL' ELSE 'EKLE' END);
  END LOOP;

  RETURN jsonb_build_object(
    'ok', true,
    'seviye', p_seviye,
    'hedef', jsonb_strip_nulls(jsonb_build_object(
               'txid', v_txid::text, 'tablo', v_tablo,
               'pk', CASE WHEN v_pk IS NOT NULL THEN surum_gizli._pk_gorunum(v_pk) END,
               'satir_pk', v_pk, 'alan', v_alan)),
    'plan', v_plan,
    'cakismalar', v_cak,
    'bagimliliklar', v_bag,
    'stok_uyari', v_stok,
    'geri_alinabilir', jsonb_array_length(v_cak) = 0 AND cardinality(v_eng) = 0
                       AND jsonb_array_length(v_plan) > 0,
    'engeller', to_jsonb(v_eng));
END;
$$;

-- ── L4 §3: zincir planner (K1 cross-row scope) ──────────────────────────────
CREATE OR REPLACE FUNCTION surum_gizli._l4_zincir(p_hedef jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path = pg_catalog, public
AS $$
DECLARE
  c_teknik  CONSTANT text[] := ARRAY['created_at','updated_at','olusturma',
                                     'guncelleme','guncelleme_tarihi','guncellendi'];
  -- hayvan bridge columns (live FK inventory 2026-09-14, probe_sema.out §6;
  -- the same list degisim_listele's hayvan filter uses)
  c_hayvan_kolonlar CONSTANT text[] := ARRAY['hayvan_id','ana_hayvan_id','animal_id',
                                             'anne_id','buzagi_id','farm_animal_id'];
  c_adim_siniri CONSTANT int := 100;

  v_txid       bigint;
  v_tablo      text;
  v_pk         jsonb;
  v_zaman      text;
  v_neden      text;
  v_enyakin    timestamptz;
  v_hedef_txid bigint;
  v_ids        bigint[];
  v_add        bigint[];
  v_min        bigint;
  v_taranan    bigint[] := '{}'::bigint[];
  e            public.degisim_log;
  r            record;
  fk           record;
  ch           record;
  s            record;
  v_cpk        jsonb;
  v_cids       bigint[];
  v_ctx        bigint[];
  v_cur        jsonb;
  v_fields     text[];
  v_exists     boolean;
  v_eng_sayi   int := 0;
  v_bloke_birim jsonb := '[]'::jsonb;
  v_ekle       public.degisim_log[];
  v_sirali     public.degisim_log[];
  v_topo       public.degisim_log[] := ARRAY[]::public.degisim_log[];
  v_n          int;
  v_derece     int[];
  v_cikti      boolean[];
  v_kalan      int;
  v_bulundu    boolean;
  i            int;
  j            int;
  v_sira       int := 0;
  v_plan       jsonb := '[]'::jsonb;
  v_cak        jsonb := '[]'::jsonb;
  v_bag        jsonb := '[]'::jsonb;
  v_stok       jsonb := '[]'::jsonb;
  v_eng        text[] := '{}';
  v_ga         boolean;
  v_rehber     jsonb := NULL;
BEGIN
  IF p_hedef IS NULL OR jsonb_typeof(p_hedef) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'hata', 'GECERSIZ_HEDEF');
  END IF;

  IF nullif(p_hedef ->> 'txid', '') IS NOT NULL THEN
    BEGIN
      v_txid := (p_hedef ->> 'txid')::bigint;
    EXCEPTION WHEN others THEN
      RETURN jsonb_build_object('ok', false, 'hata', 'GECERSIZ_HEDEF');
    END;
  END IF;
  v_zaman := nullif(p_hedef ->> 'zaman', '');

  -- ── 1. hedef adımı: {txid} | {tablo,pk[,txid|zaman]} ──
  IF v_txid IS NOT NULL THEN
    v_hedef_txid := v_txid;
    -- {tablo,pk,txid} formu: SATIR-KÖKLÜ hedef (yalnız bu satırın o tx'teki
    -- girişleri + aynı-tx stok hareketleri başlangıç adımıdır; {txid} tek
    -- başına verildiğinde tx BÜTÜNÜ başlangıçtır). Böylece W2, satır önizle
    -- mesinde kullandığı hedefi zincire de geçebilir (sessiz genişleme yok).
    v_tablo := nullif(p_hedef ->> 'tablo', '');
    IF v_tablo IS NOT NULL THEN
      IF NOT surum_gizli._kapsamda(v_tablo) THEN
        RETURN jsonb_build_object('ok', false, 'hata', 'GECERSIZ_HEDEF');
      END IF;
      v_pk := surum_gizli._pk_json(v_tablo, p_hedef -> 'pk');
      IF v_pk IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'hata', 'GECERSIZ_HEDEF');
      END IF;
      SELECT array_agg(id ORDER BY id) INTO v_ids
        FROM public.degisim_log
       WHERE txid = v_txid AND tablo_adi = v_tablo AND satir_pk = v_pk;
      IF v_ids IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'hata', 'HEDEF_BULUNAMADI',
          'detay', jsonb_build_object('neden', 'LOG_YOK'));
      END IF;
      IF (SELECT count(*) FROM jsonb_object_keys(v_pk)) = 1 THEN
        v_ids := v_ids || ARRAY(
          SELECT id FROM public.degisim_log
           WHERE txid = v_txid AND tablo_adi = 'stok_hareket'
             AND coalesce(yeni, eski) ->> 'referans_id' = (SELECT v #>> '{}' FROM jsonb_each(v_pk) AS x(k, v))
             AND id <> ALL (v_ids));
      END IF;
    ELSE
      SELECT array_agg(id ORDER BY id) INTO v_ids FROM public.degisim_log WHERE txid = v_txid;
      IF v_ids IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'hata', 'HEDEF_BULUNAMADI',
          'detay', jsonb_build_object('neden', 'LOG_YOK'));
      END IF;
    END IF;
  ELSE
    v_tablo := p_hedef ->> 'tablo';
    IF v_tablo IS NULL OR NOT surum_gizli._kapsamda(v_tablo) THEN
      RETURN jsonb_build_object('ok', false, 'hata', 'GECERSIZ_HEDEF');
    END IF;
    v_pk := surum_gizli._pk_json(v_tablo, p_hedef -> 'pk');
    IF v_pk IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'hata', 'GECERSIZ_HEDEF');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.degisim_log
                    WHERE tablo_adi = v_tablo AND satir_pk = v_pk) THEN
      RETURN jsonb_build_object('ok', false, 'hata', 'HEDEF_BULUNAMADI',
        'detay', jsonb_build_object('neden',
          CASE WHEN surum_gizli._guncel_satir(v_tablo, v_pk) IS NULL
               THEN 'SATIR_YOK' ELSE 'LOG_YOK' END));
    END IF;

    IF v_zaman IS NOT NULL THEN
      SELECT o_txid, o_neden, o_enyakin INTO v_txid, v_neden, v_enyakin
        FROM surum_gizli._l4_zaman_txid(v_tablo, v_pk, v_zaman);
      IF v_txid IS NULL THEN
        IF v_neden = 'ZAMAN_GECERSIZ' THEN
          RETURN jsonb_build_object('ok', false, 'hata', 'GECERSIZ_HEDEF');
        END IF;
        RETURN jsonb_build_object('ok', false, 'hata', 'HEDEF_BULUNAMADI',
          'detay', jsonb_build_object('neden', v_neden, 'zaman', v_zaman,
                                      'en_yakin', v_enyakin));
      END IF;
    ELSE
      SELECT txid INTO v_txid FROM public.degisim_log
       WHERE tablo_adi = v_tablo AND satir_pk = v_pk
       ORDER BY id DESC LIMIT 1;
    END IF;
    v_hedef_txid := v_txid;

    SELECT array_agg(id ORDER BY id) INTO v_ids
      FROM public.degisim_log
     WHERE txid = v_txid AND tablo_adi = v_tablo AND satir_pk = v_pk;
    -- stock movements of the same tx that reference this row join the chain
    -- (satir precedenti)
    IF (SELECT count(*) FROM jsonb_object_keys(v_pk)) = 1 THEN
      v_ids := v_ids || ARRAY(
        SELECT id FROM public.degisim_log
         WHERE txid = v_txid AND tablo_adi = 'stok_hareket'
           AND coalesce(yeni, eski) ->> 'referans_id' = (SELECT v #>> '{}' FROM jsonb_each(v_pk) AS x(k, v))
           AND id <> ALL (v_ids));
    END IF;
  END IF;

  -- sınır: hedef adımı KENDİ BAŞINDA 100 adımı aşiyorsa da ZINCIR_COK_UZUN
  -- (kapanış döngüsü büyüme yolunda denetler; başlangıç burada denetlenir)
  IF cardinality(v_ids) > c_adim_siniri THEN
    RETURN jsonb_build_object('ok', false, 'hata', 'GECERSIZ_HEDEF',
      'detay', jsonb_build_object('neden', 'ZINCIR_COK_UZUN',
                                  'zincir_adim', cardinality(v_ids),
                                  'sinir', c_adim_siniri));
  END IF;

  SELECT min(id) INTO v_min FROM public.degisim_log WHERE id = ANY (v_ids);

  -- ── 2. yineli kapsam kapanışı (K1): (a) aynı satır, (b) FK çocuklar +
  --    hayvan köprüsü; yalnız engel/çakışma üreten çapraz-satır olaylar ──
  LOOP
    v_add := '{}'::bigint[];

    -- (a) zincir satırlarında, hedef adımından SONRAKİ tüm değişiklikler
    v_add := v_add || coalesce(ARRAY(
      SELECT l.id
        FROM public.degisim_log l
        JOIN (SELECT d.tablo_adi, d.satir_pk, min(d.id) AS ilk_id
                FROM public.degisim_log d
               WHERE d.id = ANY (v_ids) GROUP BY 1, 2) g
          ON g.tablo_adi = l.tablo_adi AND g.satir_pk = l.satir_pk
       WHERE l.id > g.ilk_id AND l.id <> ALL (v_ids)), '{}'::bigint[]);

    -- (b1) FK çocuklar: zincirdeki INSERT adımlarının (silinecek satırlar)
    --      bağımlılık taraması — motorun mevcut deseni. İzlenen çocuğun
    --      hedef'ten sonraki girişleri bağımlı adım olur; izlenmeyen çocuk
    --      (logsuz) silmeyi bloklar → aşılamaz ENGEL (bypass yok).
    FOR e IN
      SELECT * FROM public.degisim_log
       WHERE id = ANY (v_ids) AND islem = 'I' AND id <> ALL (v_taranan)
       ORDER BY id
    LOOP
      v_taranan := v_taranan || e.id;
      FOR fk IN
        SELECT cc.relname::text AS child, con.conrelid AS child_rel, con.confdeltype,
               array_agg(ca.attname::text ORDER BY k.ord) AS ccols,
               array_agg(pa.attname::text ORDER BY k.ord) AS pcols
          FROM pg_constraint con
          JOIN pg_class cc ON cc.oid = con.conrelid
          CROSS JOIN LATERAL unnest(con.conkey, con.confkey) WITH ORDINALITY AS k(ck, pk, ord)
          JOIN pg_attribute ca ON ca.attrelid = con.conrelid AND ca.attnum = k.ck
          JOIN pg_attribute pa ON pa.attrelid = con.confrelid AND pa.attnum = k.pk
         WHERE con.contype = 'f'
           AND con.confrelid = format('public.%I', e.tablo_adi)::regclass
           AND cc.relnamespace = 'public'::regnamespace
         GROUP BY 1, 2, 3
      LOOP
        FOR ch IN EXECUTE format(
            'SELECT to_jsonb(c) AS j FROM public.%I c WHERE (%s) = (SELECT %s FROM jsonb_populate_record(NULL::public.%I, $1))',
            fk.child,
            (SELECT string_agg(format('c.%I', x), ', ') FROM unnest(fk.ccols) x),
            (SELECT string_agg(format('%I', x), ', ') FROM unnest(fk.pcols) x),
            e.tablo_adi)
          USING e.yeni
        LOOP
          SELECT jsonb_object_agg(a.attname, ch.j -> a.attname) INTO v_cpk
            FROM pg_constraint pc
            CROSS JOIN LATERAL unnest(pc.conkey) AS u(n)
            JOIN pg_attribute a ON a.attrelid = pc.conrelid AND a.attnum = u.n
           WHERE pc.conrelid = fk.child_rel AND pc.contype = 'p';
          CONTINUE WHEN EXISTS (
            SELECT 1 FROM public.degisim_log d
             WHERE d.id = ANY (v_ids) AND d.tablo_adi = fk.child AND d.satir_pk = v_cpk);

          SELECT array_agg(id), array_agg(DISTINCT txid) INTO v_cids, v_ctx
            FROM public.degisim_log WHERE tablo_adi = fk.child AND satir_pk = v_cpk;

          IF v_cids IS NULL THEN
            v_bag := v_bag || jsonb_build_object(
              'tablo', fk.child, 'pk', surum_gizli._pk_gorunum(v_cpk), 'satir_pk', v_cpk,
              'iliski', format('%s(%s) -> %s', fk.child, array_to_string(fk.ccols, ','), e.tablo_adi),
              'etki', CASE WHEN fk.confdeltype = 'n' THEN 'UYARI' ELSE 'ENGEL' END);
            IF fk.confdeltype <> 'n' THEN
              v_eng := v_eng || format('%s kaydı %s geçmişi olmayan bağımlı kayıt', fk.child, surum_gizli._pk_gorunum(v_cpk));
            END IF;
          ELSE
            v_bag := v_bag || jsonb_build_object(
              'tablo', fk.child, 'pk', surum_gizli._pk_gorunum(v_cpk), 'satir_pk', v_cpk,
              'iliski', format('%s(%s) -> %s', fk.child, array_to_string(fk.ccols, ','), e.tablo_adi),
              'etki', CASE WHEN v_ctx = ARRAY[v_hedef_txid] THEN 'KADEMELI' ELSE 'BAGIMLI_ADIM' END);
            -- yalnız hedef adımından sonraki girişler (çocuğun hedef-öncesi
            -- geçmişi geri alınmaz)
            v_add := v_add || coalesce(ARRAY(
                       SELECT x FROM unnest(v_cids) x WHERE x > v_min), '{}'::bigint[]);
          END IF;
        END LOOP;
      END LOOP;
    END LOOP;

    -- (b2) hayvan köprüsü: hedef satırın hayvanına FK'lı satırlarda, hedef
    --      adımından SONRA doğmuş (INSERT) kayıtlar — bağımlı adım. Üst taraf
    --      (hayvanlar satırının kendisi — ör. kilo güncellemesi) ve kardeş
    --      satırların U/D düzenlemeleri zincire GİRMEZ (ilgisiz olay).
    FOR r IN
      SELECT l.id, l.tablo_adi, l.satir_pk
        FROM public.degisim_log l
       WHERE l.islem = 'I'
         AND l.tablo_adi <> 'hayvanlar'
         AND l.id > v_min AND l.id <> ALL (v_ids)
         AND EXISTS (SELECT 1 FROM pg_attribute la
                      WHERE la.attrelid = format('public.%I', l.tablo_adi)::regclass
                        AND la.attname = ANY (c_hayvan_kolonlar)
                        AND la.attnum > 0 AND NOT la.attisdropped)
         AND EXISTS (
               SELECT 1
                 FROM unnest(c_hayvan_kolonlar) lk
                WHERE coalesce(l.yeni, l.eski) ->> lk IS NOT NULL
                  AND EXISTS (
                        SELECT 1
                          FROM public.degisim_log d
                         WHERE d.id = ANY (v_ids)
                           AND d.tablo_adi <> 'hayvanlar'
                           AND EXISTS (
                                 SELECT 1 FROM unnest(c_hayvan_kolonlar) dk
                                  WHERE coalesce(d.yeni, d.eski) ->> dk
                                        IS NOT DISTINCT FROM coalesce(l.yeni, l.eski) ->> lk)))
    LOOP
      v_add := v_add || r.id;
      CONTINUE WHEN EXISTS (
        SELECT 1 FROM jsonb_array_elements(v_bag) b
         WHERE b ->> 'etki' = 'BAGIMLI_ADIM' AND b ->> 'tablo' = r.tablo_adi
           AND b -> 'satir_pk' IS NOT DISTINCT FROM r.satir_pk);
      v_bag := v_bag || jsonb_build_object(
        'tablo', r.tablo_adi, 'pk', surum_gizli._pk_gorunum(r.satir_pk), 'satir_pk', r.satir_pk,
        'iliski', format('%s kaydı hedefin hayvanına bağlı (hayvan köprüsü) ve hedef adımından sonra doğmuş', r.tablo_adi),
        'etki', 'BAGIMLI_ADIM');
    END LOOP;

    v_add := ARRAY(SELECT DISTINCT x FROM unnest(v_add) x WHERE x <> ALL (v_ids));
    EXIT WHEN cardinality(v_add) = 0;

    v_ids := v_ids || v_add;
    IF cardinality(v_ids) > c_adim_siniri THEN
      RETURN jsonb_build_object('ok', false, 'hata', 'GECERSIZ_HEDEF',
        'detay', jsonb_build_object('neden', 'ZINCIR_COK_UZUN',
                                    'zincir_adim', cardinality(v_ids),
                                    'sinir', c_adim_siniri));
    END IF;
  END LOOP;

  -- engel sayısı anlık görüntüsü: çakışma metinleri v_eng'e birleştirilmeden
  -- ÖNCE (yoksa ZINCIR_DISI_ENGEL ayrımı ölü kod olur)
  v_eng_sayi := cardinality(v_eng);

    -- EKLE adımları (D girişleri) üst kayıt ister — f2 planıyla aynı ENGEL
    -- kuralı (bypass yok): ilk durumda üst kayıt yoksa ve o üst de zincirde
    -- geri eklenecek değilse, otomatik zincir kurulamaz → rehber düşer.
    FOR e IN SELECT * FROM public.degisim_log WHERE id = ANY (v_ids) AND islem = 'D' LOOP
      FOR fk IN
        SELECT pcl.relname::text AS parent, con.confdeltype,
               array_agg(ca.attname::text ORDER BY k.ord) AS ccols,
               array_agg(pa.attname::text ORDER BY k.ord) AS pcols
          FROM pg_constraint con
          JOIN pg_class pcl ON pcl.oid = con.confrelid
          CROSS JOIN LATERAL unnest(con.conkey, con.confkey) WITH ORDINALITY AS k(ck, pk, ord)
          JOIN pg_attribute ca ON ca.attrelid = con.conrelid AND ca.attnum = k.ck
          JOIN pg_attribute pa ON pa.attrelid = con.confrelid AND pa.attnum = k.pk
         WHERE con.contype = 'f'
           AND con.conrelid = format('public.%I', e.tablo_adi)::regclass
           AND pcl.relnamespace = 'public'::regnamespace
         GROUP BY 1, 2
      LOOP
        CONTINUE WHEN EXISTS (SELECT 1 FROM unnest(fk.ccols) c WHERE e.eski ->> c IS NULL);
        EXECUTE format(
          'SELECT EXISTS (SELECT 1 FROM public.%I p WHERE (%s) = (SELECT %s FROM jsonb_populate_record(NULL::public.%I, $1)))',
          fk.parent,
          (SELECT string_agg(format('p.%I', x), ', ') FROM unnest(fk.pcols) x),
          (SELECT string_agg(format('%I', x), ', ') FROM unnest(fk.ccols) x),
          e.tablo_adi)
          INTO v_exists USING e.eski;
        IF NOT v_exists AND NOT EXISTS (
             SELECT 1 FROM public.degisim_log d
              WHERE d.id = ANY (v_ids) AND d.tablo_adi = fk.parent AND d.islem = 'D'
                AND NOT EXISTS (SELECT 1 FROM unnest(fk.pcols, fk.ccols) AS u(p, c)
                                 WHERE d.eski ->> u.p IS DISTINCT FROM e.eski ->> u.c)) THEN
          v_bag := v_bag || jsonb_build_object(
            'tablo', fk.parent, 'pk', NULL,
            'iliski', format('%s(%s) -> %s(%s)', e.tablo_adi, array_to_string(fk.ccols, ','),
                             fk.parent, array_to_string(fk.pcols, ',')),
            'etki', 'ENGEL');
          v_eng := v_eng || format('%s kaydı geri eklenemez: üst kayıt (%s) yok', e.tablo_adi, fk.parent);
          -- bu EKLE birimi rehberde tekil geri alınamaz → işaretle (süzülür)
          v_bloke_birim := v_bloke_birim || jsonb_build_object(
            'tablo', e.tablo_adi, 'satir_pk', e.satir_pk, 'txid', e.txid::text);
        END IF;
      END LOOP;
    END LOOP;

  -- bilgi (engel değil): zincirdeki D girişiyle aynı tx'te kademeli silinmiş
  -- ama zincire girmemiş çocuklar — f2 planındaki UYARI paritesi
  FOR e IN SELECT * FROM public.degisim_log WHERE id = ANY (v_ids) AND islem = 'D' LOOP
    FOR ch IN
      SELECT c.* FROM public.degisim_log c
       WHERE c.txid = e.txid AND c.islem = 'D' AND c.id <> ALL (v_ids)
         AND surum_gizli._ekle_bagli(e, c)
    LOOP
      v_bag := v_bag || jsonb_build_object(
        'tablo', ch.tablo_adi, 'pk', surum_gizli._pk_gorunum(ch.satir_pk), 'satir_pk', ch.satir_pk,
        'iliski', format('%s kaydı %s ile aynı işlemde silinmiş ve bu geri almaya dahil değil',
                         ch.tablo_adi, e.tablo_adi),
        'etki', 'UYARI');
    END LOOP;
  END LOOP;

  -- ── 3. çakışmalar: zincire DAHİL OLMAYAN satırların sonraki değişiklikleri
  --    sayılmaz; yalnız izlenmeyen yolcularla durum kayması (drift) çakışmadır
  FOR r IN
    SELECT tablo_adi, satir_pk, max(id) AS son_id
      FROM public.degisim_log WHERE id = ANY (v_ids) GROUP BY 1, 2
  LOOP
    SELECT * INTO e FROM public.degisim_log WHERE id = r.son_id;
    v_cur := surum_gizli._guncel_satir(r.tablo_adi, r.satir_pk);
    IF e.islem = 'D' THEN
      IF v_cur IS NOT NULL THEN
        v_cak := v_cak || jsonb_strip_nulls(jsonb_build_object(
          'tablo', r.tablo_adi, 'pk', surum_gizli._pk_gorunum(r.satir_pk), 'satir_pk', r.satir_pk,
          'neden', 'GUNCEL_DURUM_FARKLI'));
      END IF;
    ELSE
      v_fields := ARRAY(SELECT jsonb_object_keys(e.yeni));
      IF v_cur IS NULL OR EXISTS (
           SELECT 1 FROM unnest(v_fields) f
            WHERE f <> ALL (c_teknik) AND v_cur ? f
              AND (v_cur -> f) IS DISTINCT FROM (e.yeni -> f)) THEN
        v_cak := v_cak || jsonb_strip_nulls(jsonb_build_object(
          'tablo', r.tablo_adi, 'pk', surum_gizli._pk_gorunum(r.satir_pk), 'satir_pk', r.satir_pk,
          'neden', 'GUNCEL_DURUM_FARKLI'));
      END IF;
    END IF;
  END LOOP;

  SELECT v_eng || coalesce(array_agg(format('%s kaydı %s: %s', c ->> 'tablo', c -> 'pk', c ->> 'neden')), '{}')
    INTO v_eng FROM jsonb_array_elements(v_cak) c;

  -- ── 4. stok uyarıları (bilgi; engel değil) ──
  FOR r IN
    SELECT DISTINCT tablo_adi, satir_pk FROM public.degisim_log
     WHERE id = ANY (v_ids) AND tablo_adi <> 'stok_hareket'
       AND (SELECT count(*) FROM jsonb_object_keys(satir_pk)) = 1
  LOOP
    FOR e IN
      SELECT * FROM public.degisim_log l
       WHERE l.tablo_adi = 'stok_hareket' AND l.id <> ALL (v_ids)
         AND coalesce(l.yeni, l.eski) ->> 'referans_id' = (SELECT v #>> '{}' FROM jsonb_each(r.satir_pk) AS x(k, v))
    LOOP
      v_stok := v_stok || jsonb_build_object(
        'stok_id', coalesce(e.yeni, e.eski) ->> 'stok_id',
        'metin', format('%s kaydına bağlı stok hareketi (txid %s) bu geri almaya dahil değil; stok elle kontrol edilmeli',
                        r.tablo_adi, e.txid));
    END LOOP;
  END LOOP;

  -- ── 5. plan adımları: aynı satırda en yeni önce (id DESC); bağımlı adımlar
  --    (daha büyük log id) doğal olarak bağlandıkları adımdan ÖNCE gelir;
  --    EKLE adımları (D girişleri) mevcut topolojik desenle anne-önce ──
  SELECT coalesce(array_agg(x ORDER BY x.id), ARRAY[]::public.degisim_log[])
    INTO v_ekle
    FROM public.degisim_log x
   WHERE x.id = ANY (v_ids) AND x.islem = 'D';
  SELECT coalesce(array_agg(x ORDER BY x.id DESC), ARRAY[]::public.degisim_log[])
    INTO v_sirali
    FROM public.degisim_log x
   WHERE x.id = ANY (v_ids) AND x.islem <> 'D';

  v_n := coalesce(cardinality(v_ekle), 0);
  IF v_n > 0 THEN
    v_derece := array_fill(0, ARRAY[v_n]);
    v_cikti  := array_fill(false, ARRAY[v_n]);
    FOR i IN 1 .. v_n LOOP
      FOR j IN 1 .. v_n LOOP
        CONTINUE WHEN i = j;
        IF surum_gizli._ekle_bagli(v_ekle[j], v_ekle[i]) THEN
          v_derece[i] := v_derece[i] + 1;
        END IF;
      END LOOP;
    END LOOP;
    v_kalan := v_n;
    WHILE v_kalan > 0 LOOP
      v_bulundu := false;
      FOR i IN 1 .. v_n LOOP
        CONTINUE WHEN v_cikti[i] OR v_derece[i] > 0;
        v_cikti[i] := true;
        v_kalan := v_kalan - 1;
        v_bulundu := true;
        v_topo := v_topo || v_ekle[i];
        FOR j IN 1 .. v_n LOOP
          CONTINUE WHEN v_cikti[j];
          IF surum_gizli._ekle_bagli(v_ekle[i], v_ekle[j]) THEN
            v_derece[j] := v_derece[j] - 1;
          END IF;
        END LOOP;
        EXIT;
      END LOOP;
      IF NOT v_bulundu THEN
        FOR i IN 1 .. v_n LOOP
          CONTINUE WHEN v_cikti[i];
          v_cikti[i] := true;
          v_kalan := v_kalan - 1;
          v_topo := v_topo || v_ekle[i];
        END LOOP;
      END IF;
    END LOOP;
    v_sirali := v_topo || v_sirali;
  END IF;

  FOREACH e IN ARRAY v_sirali LOOP
    v_sira := v_sira + 1;
    v_plan := v_plan || jsonb_build_object(
      'sira', v_sira,
      'log_id', e.id,
      'txid', e.txid::text,
      'tablo', e.tablo_adi,
      'pk', surum_gizli._pk_gorunum(e.satir_pk),
      'satir_pk', e.satir_pk,
      'islem', e.islem,
      'alanlar', CASE WHEN e.islem = 'U' THEN to_jsonb(e.degisen_alanlar) END,
      'eski', CASE e.islem WHEN 'U' THEN (SELECT jsonb_object_agg(f, e.eski -> f) FROM unnest(e.degisen_alanlar) f)
                           WHEN 'D' THEN e.eski END,
      'yeni', CASE e.islem WHEN 'U' THEN (SELECT jsonb_object_agg(f, e.yeni -> f) FROM unnest(e.degisen_alanlar) f)
                           WHEN 'I' THEN e.yeni END,
      'zaman', e.kayit_zamani,
      'yapilacak', CASE e.islem WHEN 'U' THEN 'GUNCELLE' WHEN 'I' THEN 'SIL' ELSE 'EKLE' END);
  END LOOP;

  v_ga := jsonb_array_length(v_cak) = 0 AND cardinality(v_eng) = 0
          AND jsonb_array_length(v_plan) > 0;

  -- ── 6. sıralı rehber (K1): otomatik zincir kurulamıyorsa kullanıcıya TEK
  --    TEK geri alma listesi. Sıra = plan adım sırası (aynı satırda en yeni
  --    önce; bağımlı birim bağlandığı birimden ÖNCE) → rehberi bu sırayla
  --    izleyen kullanıcı her birimi tekil (satir) hedefle geri alabilir.
  --    Durum kaymalı satırlar tekil geri alınamaz → rehber dışı. ──
  IF NOT v_ga THEN
    v_rehber := '[]'::jsonb;
    FOR s IN
      SELECT x.tablo, x.satir_pk, x.txid, x.islem, x.zaman
        FROM jsonb_to_recordset(v_plan)
          AS x(sira int, tablo text, satir_pk jsonb, txid text, islem text,
               zaman timestamptz)
       ORDER BY x.sira
    LOOP
      CONTINUE WHEN EXISTS (   -- durum kayması: tekil geri alınamaz
        SELECT 1 FROM jsonb_array_elements(v_cak) c
         WHERE c ->> 'tablo' = s.tablo
           AND c -> 'satir_pk' IS NOT DISTINCT FROM s.satir_pk
           AND c ->> 'neden' = 'GUNCEL_DURUM_FARKLI');
      CONTINUE WHEN EXISTS (   -- üst kaydı yok: EKLE birimi tekil geri alınamaz
        SELECT 1 FROM jsonb_array_elements(v_bloke_birim) bb
         WHERE bb ->> 'tablo' = s.tablo
           AND bb -> 'satir_pk' IS NOT DISTINCT FROM s.satir_pk
           AND bb ->> 'txid' = s.txid);
      CONTINUE WHEN EXISTS (
        SELECT 1 FROM jsonb_array_elements(v_rehber) rb
         WHERE rb -> 'hedef' ->> 'tablo' = s.tablo
           AND rb -> 'hedef' ->> 'txid' = s.txid
           AND rb -> 'hedef' -> 'pk' IS NOT DISTINCT FROM
               surum_gizli._pk_gorunum(s.satir_pk));
      v_rehber := v_rehber || jsonb_build_object(
        'sira', jsonb_array_length(v_rehber) + 1,
        'hedef', jsonb_build_object('tablo', s.tablo,
                                    'pk', surum_gizli._pk_gorunum(s.satir_pk),
                                    'txid', s.txid,
                                    'l4_rehber', true),
        'zaman', s.zaman,
        'ozet', format('%s · %s', s.tablo, s.islem),
        'neden_dahil_degil', CASE
          WHEN v_eng_sayi > 0 THEN 'ZINCIR_DISI_ENGEL'
          ELSE 'ZINCIR_DISI_CAKISMA'
        END);
    END LOOP;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'seviye', 'zincir',
    'hedef', jsonb_strip_nulls(jsonb_build_object(
               'txid', v_hedef_txid::text, 'tablo', v_tablo,
               'pk', CASE WHEN v_pk IS NOT NULL THEN surum_gizli._pk_gorunum(v_pk) END,
               'satir_pk', v_pk)),
    'plan', v_plan,
    'cakismalar', v_cak,
    'bagimliliklar', v_bag,
    'stok_uyari', v_stok,
    'geri_alinabilir', v_ga,
    'engeller', to_jsonb(v_eng),
    'zincir_adim', jsonb_array_length(v_plan),
    'sirali_rehber', v_rehber);
END;
$$;

-- ── public RPCs: route 'zincir' (ADDITIVE; imzalar değişmedi) ───────────────

CREATE OR REPLACE FUNCTION public.degisim_onizle(p_hedef jsonb, p_seviye text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF p_seviye = 'zincir' THEN
    RETURN surum_gizli._l4_zincir(p_hedef);
  END IF;
  RETURN surum_gizli._degisim_plan(p_hedef, p_seviye);
END;
$$;

CREATE OR REPLACE FUNCTION public.degisim_geri_al(p_hedef jsonb, p_seviye text, p_bilet uuid,
                                                  p_gerekce text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  c_hayvan_kolonlar CONSTANT text[] := ARRAY['hayvan_id','ana_hayvan_id','animal_id',
                                             'anne_id','buzagi_id','farm_animal_id'];
  v_b    surum_gizli.geri_alma_bileti;
  v_plan jsonb;
  v_res  jsonb;
  v_n    int;
  s      record;
  v_htablo text;
  v_hsatir jsonb;
  v_ref    text;
  v_hayvan text;
  v_otip   text;
BEGIN
  IF p_bilet IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'hata', 'BILET_GECERSIZ', 'detay', '{}'::jsonb);
  END IF;
  SELECT * INTO v_b FROM surum_gizli.geri_alma_bileti WHERE bilet = p_bilet;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'hata', 'BILET_GECERSIZ', 'detay', '{}'::jsonb);
  END IF;
  IF v_b.son_gecerlilik <= clock_timestamp() THEN
    v_res := jsonb_build_object('ok', false, 'hata', 'BILET_SURESI_DOLMUS',
                                'detay', jsonb_build_object('son_gecerlilik', v_b.son_gecerlilik));
    INSERT INTO surum_gizli.geri_alma_kullanim (bilet, hedef, seviye, gerekce, sonuc, kaynak)
    VALUES (p_bilet, p_hedef, p_seviye, p_gerekce, v_res, surum_gizli._cagiran());
    RETURN v_res;
  END IF;

  -- serialize reverts; plan, lock the rows it touches, then re-plan so the
  -- conflict check runs against locked, current state (race-safe). The lock
  -- and re-plan sit in their own subtransaction: a deadlock/timeout there
  -- returns ok:false instead of escaping (which would skip the usage record).
  PERFORM pg_advisory_xact_lock(hashtext('degisim_geri_al'));
  v_plan := CASE WHEN p_seviye = 'zincir' THEN surum_gizli._l4_zincir(p_hedef)
                 ELSE surum_gizli._degisim_plan(p_hedef, p_seviye) END;
  IF (v_plan ->> 'ok')::boolean THEN
    BEGIN
      FOR s IN
        SELECT DISTINCT x.tablo, x.satir_pk FROM jsonb_to_recordset(v_plan -> 'plan') AS x(tablo text, satir_pk jsonb)
      LOOP
        EXECUTE format('SELECT 1 FROM public.%1$I WHERE (%2$s) = (SELECT %2$s FROM jsonb_populate_record(NULL::public.%1$I, $1)) FOR UPDATE',
                       s.tablo, surum_gizli._pk_kolonlar(s.tablo)) USING s.satir_pk;
      END LOOP;
      v_plan := CASE WHEN p_seviye = 'zincir' THEN surum_gizli._l4_zincir(p_hedef)
                     ELSE surum_gizli._degisim_plan(p_hedef, p_seviye) END;
    EXCEPTION WHEN others THEN
      v_res := jsonb_build_object('ok', false, 'hata', 'UYGULAMA_HATASI',
                                  'detay', jsonb_build_object('asama', 'KILIT_PLAN',
                                                              'sqlstate', SQLSTATE, 'mesaj', SQLERRM));
    END;
  END IF;

  IF v_res IS NOT NULL THEN
    NULL;  -- lock/plan phase already failed; fall through to the usage record
  ELSIF NOT (v_plan ->> 'ok')::boolean THEN
    v_res := jsonb_build_object('ok', false, 'hata', v_plan ->> 'hata',
                                'detay', coalesce(v_plan -> 'detay', '{}'::jsonb));
  ELSIF jsonb_array_length(v_plan -> 'cakismalar') > 0 THEN
    v_res := jsonb_build_object('ok', false, 'hata', 'CAKISMA',
                                'detay', jsonb_build_object('cakismalar', v_plan -> 'cakismalar',
                                                            'engeller', v_plan -> 'engeller')
                                          || CASE WHEN p_seviye = 'zincir'
                                                  THEN jsonb_build_object('sirali_rehber', v_plan -> 'sirali_rehber')
                                                  ELSE '{}'::jsonb END);
  ELSIF NOT (v_plan ->> 'geri_alinabilir')::boolean
        AND jsonb_array_length(v_plan -> 'plan') > 0 THEN
    v_res := jsonb_build_object('ok', false, 'hata', 'BAGIMLILIK_ENGELI',
                                'detay', jsonb_build_object('bagimliliklar', v_plan -> 'bagimliliklar',
                                                            'engeller', v_plan -> 'engeller')
                                          || CASE WHEN p_seviye = 'zincir'
                                                  THEN jsonb_build_object('sirali_rehber', v_plan -> 'sirali_rehber')
                                                  ELSE '{}'::jsonb END);
  ELSIF jsonb_array_length(v_plan -> 'plan') = 0 THEN
    v_res := jsonb_build_object('ok', false, 'hata', 'HEDEF_BULUNAMADI', 'detay', '{}'::jsonb);
  ELSE
    PERFORM set_config('app.geri_alma_bileti', p_bilet::text, true);
    PERFORM set_config('app.geri_alma_gerekce', coalesce(p_gerekce, ''), true);
    BEGIN
      v_n := surum_gizli._degisim_uygula(v_plan -> 'plan');
    EXCEPTION WHEN others THEN
      -- a business trigger/constraint refused a step: nothing was applied
      v_res := jsonb_build_object('ok', false, 'hata', 'UYGULAMA_HATASI',
                                  'detay', jsonb_build_object('sqlstate', SQLSTATE, 'mesaj', SQLERRM));
    END;

    IF v_res IS NULL THEN
      -- L4 §6: telafi kaydı — aynı transaction içinde; INSERT serbest
      -- (immutable guard yalnız UPDATE/DELETE'i bloklar). Telafi yazımı
      -- başarısızsa istisna yayılır → tüm geri alma transaction'ı geri
      -- döner (atomik; telafisiz revert kalmaz).
      v_htablo := v_plan -> 'hedef' ->> 'tablo';
      v_hsatir := v_plan -> 'hedef' -> 'satir_pk';
      IF v_htablo IS NULL THEN
        SELECT x.tablo, x.satir_pk INTO v_htablo, v_hsatir
          FROM jsonb_to_recordset(v_plan -> 'plan')
            AS x(sira int, tablo text, satir_pk jsonb)
         ORDER BY x.sira LIMIT 1;
      END IF;
      v_ref := CASE WHEN (SELECT count(*) FROM jsonb_object_keys(v_hsatir)) = 1
                    THEN (SELECT v #>> '{}' FROM jsonb_each(v_hsatir) AS e(k, v))
                    ELSE v_hsatir::text END;
      IF v_htablo = 'hayvanlar' THEN
        v_hayvan := (SELECT v #>> '{}' FROM jsonb_each(v_hsatir) AS e(k, v));
      ELSE
        SELECT coalesce(x.yeni, x.eski) ->> k INTO v_hayvan
          FROM jsonb_to_recordset(v_plan -> 'plan')
            AS x(sira int, tablo text, satir_pk jsonb, yeni jsonb, eski jsonb)
          CROSS JOIN LATERAL unnest(c_hayvan_kolonlar) AS k
         WHERE x.tablo = v_htablo AND x.satir_pk = v_hsatir
           AND coalesce(x.yeni, x.eski) ->> k IS NOT NULL
         ORDER BY x.sira LIMIT 1;
      END IF;
      SELECT string_agg(DISTINCT x.islem, ',' ORDER BY x.islem) INTO v_otip
        FROM jsonb_to_recordset(v_plan -> 'plan') AS x(islem text);

      INSERT INTO public.islem_log
        (tip, ref_id, ref_tablo, ana_hayvan_id, payload, snapshot)
      VALUES
        ('GERI_ALINDI', v_ref, v_htablo, v_hayvan,
         jsonb_build_object('orijinal_tip', v_otip, 'seviye', p_seviye, 'adim', v_n),
         '{}'::jsonb);

      v_res := jsonb_build_object('ok', true,
                                  'geri_alma_txid', txid_current()::text,
                                  'uygulanan_adim', v_n);
      IF p_seviye = 'zincir' THEN
        v_res := v_res || jsonb_build_object('zincir_adim', jsonb_array_length(v_plan -> 'plan'));
      END IF;
    END IF;
    PERFORM set_config('app.geri_alma_bileti', '', true);
    PERFORM set_config('app.geri_alma_gerekce', '', true);
  END IF;

  INSERT INTO surum_gizli.geri_alma_kullanim (bilet, hedef, seviye, gerekce, sonuc, geri_alma_txid, kaynak)
  VALUES (p_bilet, p_hedef, p_seviye, p_gerekce, v_res,
          CASE WHEN (v_res ->> 'ok')::boolean THEN txid_current() END,
          surum_gizli._cagiran());
  RETURN v_res;
END;
$$;

REVOKE ALL ON FUNCTION surum_gizli._l4_zaman_txid(text, jsonb, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION surum_gizli._l4_zincir(jsonb)                   FROM PUBLIC, anon, authenticated;

COMMIT;
