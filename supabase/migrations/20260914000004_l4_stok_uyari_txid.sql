-- 20260914000004_l4_stok_uyari_txid.sql — L4-07 alt bulgu onarımı (W6).
-- luna 2. tur (2026-09-14-luna-denetim-l4-tur2.md, MEDIUM): stok_uyari `metin`
-- alanına gömülü `(txid %s)` görünür "📦 Stok uyarısı" bloğunda basılıyordu;
-- frozen sözleşme (G-20260914-GERI-ALMA-AKISI md.7) tx/UUID ayrıntısını
-- teknik katlamaya hapseder. Aynı-tx döngüsünün metnine gömülü ham hareket
-- kimliği de UUID'dir (stok_hareket.id text PK, app crypto.randomUUID) —
-- o da görünürden kalkar.
-- Değişiklik (yalnız stok uyarı üretimi):
--   * metin: tanımlayıcı içermeyen cümle (alan KORUNUR),
--   * txid: bağlı stok hareketinin degisim_log txid'i AYRI alan (text),
--   * hareket_id: aynı-tx stok hareketinin satır pk'ı AYRI alan (text).
-- UI (degisiklikler.js _dgTeknikDetayHtml) bu alanları yalnız teknik
-- katlamada gösterir; görünür alanda txid/UUID kalmaz.
-- Replay-safe: gövdeler 20260914000003_l4_onarim.sql'in _degisim_plan +
-- _l4_zincir tanımlarının birebir kopyasıdır; tek fark yukarıdaki satırlar
-- (tests/unit/l4-stok-uyari-txid.test.js pinler). Create/Replace → idempotent.
BEGIN;

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
  v_rehber  boolean;   -- L4-01: sunucu-üretimi rehber adımı mı?
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

  -- L4-01: rehber gevşetme yetkisi istemciden OKUNMAZ — sunucunun
  -- l4_rehber_adimlari kaydından doğrulanır; yalnız satır-seviyesi hedeflerde
  -- (L4-04) geçerlidir. p_hedef'teki herhangi bir 'l4_rehber' anahtarı
  -- bilinçli olarak yok sayılır.
  v_rehber := p_seviye = 'satir' AND surum_gizli._l4_rehber_uyesi(p_hedef);

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
       -- L4 sıralı rehber (L4-01): gevşetme yalnız sunucunun l4_rehber_adimlari
       -- kaydında adımı barındırması hâlinde ve yalnız satır-seviyesinde geçerli
       -- ("önce 5'i, sonra 4'ü geri al" akışı). İşaretsiz/üye-olmayan her
       -- çağrıda L2'nin katı kuralı AYNEN korunur (k3 S6c).
       AND (
             NOT coalesce(v_rehber, false)
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
        'metin', 'Aynı işlemdeki stok hareketi bu geri almaya dahil değil; stok elle kontrol edilmeli',
        'hareket_id', e.satir_pk ->> 'id');
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
        'metin', format('%s kaydına bağlı stok hareketi bu geri almaya dahil değil; stok elle kontrol edilmeli',
                        r.tablo_adi),
        'txid', e.txid::text);
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

CREATE OR REPLACE FUNCTION surum_gizli._l4_zincir(p_hedef jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path = pg_catalog, public
AS $$
DECLARE
  c_teknik  CONSTANT text[] := ARRAY['created_at','updated_at','olusturma',
                                     'guncelleme','guncelleme_tarihi','guncellendi'];
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

  -- ── 2. yineli kapsam kapanışı (K1 YENİ, luna L4-03): (a) zincir
  --    satırlarında hedef adımından SONRAKİ tüm değişiklikler; (b)
  --    pg_constraint'ten doğrulanan GERÇEK FK alt kayıtlarında planı
  --    GERÇEKTEN engelleyen değişiklikler. Aynı hayvanın İLİGSİZ olayları
  --    (aşı, kilo, başka kayıt) zincire GİRMEZ — eski kolon-adı hayvan
  --    köprüsü kaldırıldı. Bağımlılık FK yoluyla güvenle belirlenemeyen
  --    satırlar zincire otomatik girmez; çakışma/engel varsa sirali_rehber. ──
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

    -- (b) FK çocuklar: zincirdeki INSERT adımlarının (silinecek satırlar)
    --     bağımlılık taraması — yalnız pg_constraint'ten doğrulanan gerçek
    --     FK'lar. İzlenen çocuğun hedef'ten sonraki girişleri bağımlı adım
    --     olur; izlenmeyen çocuk (logsuz) silmeyi bloklar → aşılamaz ENGEL
    --     (bypass yok).
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

  -- ── 3. çakışmalar: zincire DAHIL OLMAYAN satırların sonraki değişiklikleri
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
        'metin', format('%s kaydına bağlı stok hareketi bu geri almaya dahil değil; stok elle kontrol edilmeli',
                        r.tablo_adi),
        'txid', e.txid::text);
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
  --    Durum kaymalı satırlar tekil geri alınamaz → rehber dışı.
  --    L4-01/L4-04: hedef artık 'l4_rehber' bayrağı TAŞIMAZ — gevşetme
  --    yetkisi sunucunun l4_rehber_adimlari kaydından gelir (aşağıda yazılır). ──
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
                                    'txid', s.txid),
        'satir_pk', s.satir_pk,
        'zaman', s.zaman,
        'ozet', format('%s · %s', s.tablo, s.islem),
        'neden_dahil_degil', CASE
          WHEN v_eng_sayi > 0 THEN 'ZINCIR_DISI_ENGEL'
          ELSE 'ZINCIR_DISI_CAKISMA'
        END);
    END LOOP;

    -- L4-01: sunucu-üretimi rehber adımları kalıcı kayda geçer — gevşetme
    -- yetkisi yalnız bu kayıttan okunur (_l4_rehber_uyesi). İstemci bayrağı
    -- hiçbir yerde okunmaz. 7 günden eski adımlar tembel temizlikle düşer.
    IF jsonb_array_length(v_rehber) > 0 THEN
      DELETE FROM surum_gizli.l4_rehber_adimlari
       WHERE olusturma < now() - interval '7 days';
      INSERT INTO surum_gizli.l4_rehber_adimlari (tablo, satir_pk, txid, kok_txid)
      SELECT g.hedef ->> 'tablo', g.satir_pk, (g.hedef ->> 'txid')::bigint, v_hedef_txid
        FROM jsonb_to_recordset(v_rehber)
          AS g(sira int, hedef jsonb, satir_pk jsonb, zaman timestamptz,
               ozet text, neden_dahil_degil text)
       WHERE g.hedef ->> 'txid' ~ '^[0-9]+$'
      ON CONFLICT (tablo, txid, satir_pk) DO NOTHING;
    END IF;
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

REVOKE ALL ON FUNCTION surum_gizli._degisim_plan(jsonb, text) FROM PUBLIC, anon, authenticated;

COMMIT;
