-- tests/sql/sessiz_ovsync_dislama_test.sql
-- K1.5 — Aktif OVSYNC dışlama kilidi: sessiz_hayvanlar_listele RPC'si
-- aktif OVSYNC vakalı hayvanı DÜŞÜRÜR; kapalı vaka ve OVSYNC-dışı aktif
-- vaka düşürmez (domain-rules :138 korunur).
--
-- HEDEF: YALNIZ yerel izole baseline (db-build-baseline.sh çıktısı).
-- Canlıya (demo/prod) bu betikle erişilmez; yazmalar E2E-SESSIZ- önekli
-- kendi fixture'larıyla sınırlıdır (marker'sız veriye dokunmaz).
--
-- KOŞUM (izole DB URL'i ile):
--   psql "$ISO_URL" -X -v ON_ERROR_STOP=1 -f tests/sql/sessiz_ovsync_dislama_test.sql
--   rc=0 → üç senaryo da PASS; rc!=0 → en az biri FAIL (kırmızı).
--
-- TEMİZLİK: fixture blokları başta ve sonda kendi E2E-SESSIZ-% kayıtlarını
-- siler (idempotent, tekrar koşulabilir). Bağımlılık sırası:
-- cases → dogum → hayvanlar.
-- Tip gerçekleri (ayna information_schema): hayvanlar.id=text;
-- cases.id=uuid, cases.animal_id=text; dogum.id=uuid, dogum.anne_id=text.
-- Canlı protocol_family uzayı (2026-10-13 OBSERVED): NULL (29 aktif vaka)
-- ve 'OVSYNC' (4 aktif vaka) — OVSYNC-dışı aktif vaka = NULL family.

\echo '=== SESSIZ OVSYNC DISLAMA — izole DB testi ==='

-- ── F0. Fixture temizliği (baştan; idempotent) ──────────────────────────
DELETE FROM cases WHERE animal_id LIKE 'E2E-SESSIZ-H-%';
DELETE FROM dogum WHERE anne_id LIKE 'E2E-SESSIZ-H-%';
DELETE FROM hayvanlar WHERE id LIKE 'E2E-SESSIZ-H-%';
DELETE FROM diseases WHERE name = 'E2E-SESSIZ-Ovsync Protokol';

-- ── F1. Fixture: üç hayvan da 60 gündür sessiz (tek event: 60 gün önce doğum) ──
INSERT INTO hayvanlar(id, kupe_no, cinsiyet, durum, grup, padok)
VALUES ('E2E-SESSIZ-H-A', 'E2E-SESSIZ-A', 'Dişi', 'Aktif', 'Sağmal (Laktasyonda)', 'Sağmal Padok'),
       ('E2E-SESSIZ-H-B', 'E2E-SESSIZ-B', 'Dişi', 'Aktif', 'Sağmal (Laktasyonda)', 'Sağmal Padok'),
       ('E2E-SESSIZ-H-C', 'E2E-SESSIZ-C', 'Dişi', 'Aktif', 'Sağmal (Laktasyonda)', 'Sağmal Padok');

INSERT INTO dogum(id, anne_id, tarih)
VALUES ('aaaaaaaa-0000-4000-8000-0000000000a1', 'E2E-SESSIZ-H-A', CURRENT_DATE - 60),
       ('aaaaaaaa-0000-4000-8000-0000000000b1', 'E2E-SESSIZ-H-B', CURRENT_DATE - 60),
       ('aaaaaaaa-0000-4000-8000-0000000000c1', 'E2E-SESSIZ-H-C', CURRENT_DATE - 60);

-- (a) aktif OVSYNC vakası → listede YOK (dışlama hedefi)
-- (b) KAPALI OVSYNC vakası → listede VAR
-- (c) aktif OVSYNC-DIŞI vaka (mastit tipi: protocol_family NULL) → listede VAR
-- cases NN kolonları (disease_id, start_date) için ortak E2E-SESSIZ hastalık satırı.
INSERT INTO diseases(id, name)
VALUES ('cccccccc-0000-4000-8000-000000000001', 'E2E-SESSIZ-Ovsync Protokol');
INSERT INTO cases(id, animal_id, disease_id, start_date, status, protocol_family)
VALUES ('bbbbbbbb-0000-4000-8000-0000000000a1', 'E2E-SESSIZ-H-A', 'cccccccc-0000-4000-8000-000000000001', CURRENT_DATE - 5, 'active', 'OVSYNC'),
       ('bbbbbbbb-0000-4000-8000-0000000000b1', 'E2E-SESSIZ-H-B', 'cccccccc-0000-4000-8000-000000000001', CURRENT_DATE - 5, 'closed', 'OVSYNC'),
       ('bbbbbbbb-0000-4000-8000-0000000000c1', 'E2E-SESSIZ-H-C', 'cccccccc-0000-4000-8000-000000000001', CURRENT_DATE - 5, 'active', NULL);

-- ── S1. RPC çıktısında varlık/yokluk assertion'ları ─────────────────────
DROP TABLE IF EXISTS _sessiz_durum;
CREATE TEMP TABLE _sessiz_durum(senaryo text PRIMARY KEY, sonuc text, kanit text);

DO $do$
DECLARE
  v_res jsonb;
  v_a boolean; v_b boolean; v_c boolean;
BEGIN
  v_res := public.sessiz_hayvanlar_listele();

  v_a := v_res @> '[{"kupe_no":"E2E-SESSIZ-A"}]';
  v_b := v_res @> '[{"kupe_no":"E2E-SESSIZ-B"}]';
  v_c := v_res @> '[{"kupe_no":"E2E-SESSIZ-C"}]';

  INSERT INTO _sessiz_durum VALUES
    ('S-a aktif-OVSYNC yok',
     CASE WHEN NOT v_a THEN 'PASS' ELSE 'FAIL' END,
     'E2E-SESSIZ-A listede=' || v_a::text),
    ('S-b kapali-OVSYNC var',
     CASE WHEN v_b THEN 'PASS' ELSE 'FAIL' END,
     'E2E-SESSIZ-B listede=' || v_b::text),
    ('S-c aktif-OVSYNC-disi var',
     CASE WHEN v_c THEN 'PASS' ELSE 'FAIL' END,
     'E2E-SESSIZ-C listede=' || v_c::text);
END
$do$;

\echo '--- S1 özet ---'
SELECT senaryo, sonuc, kanit FROM _sessiz_durum ORDER BY senaryo;

-- ── F2. Fixture temizliği (sonda) ───────────────────────────────────────
DELETE FROM cases WHERE animal_id LIKE 'E2E-SESSIZ-H-%';
DELETE FROM dogum WHERE anne_id LIKE 'E2E-SESSIZ-H-%';
DELETE FROM hayvanlar WHERE id LIKE 'E2E-SESSIZ-H-%';
DELETE FROM diseases WHERE name = 'E2E-SESSIZ-Ovsync Protokol';

-- ── S2. Hüküm: FAIL varsa nonzero exit (kırmızı) ────────────────────────
DO $do$
DECLARE v_kotu int;
BEGIN
  SELECT count(*) INTO v_kotu FROM _sessiz_durum WHERE sonuc <> 'PASS';
  IF v_kotu > 0 THEN
    RAISE EXCEPTION 'SESSIZ-OVSYNC-DISLAMA TEST FAIL: % senaryo kirmizi', v_kotu;
  ELSE
    RAISE NOTICE 'SESSIZ-OVSYNC-DISLAMA TEST PASS: 3/3 senaryo yesil';
  END IF;
END
$do$;
