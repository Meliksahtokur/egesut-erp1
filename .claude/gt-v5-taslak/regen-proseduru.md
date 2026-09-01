# GT v5 Denetimli-Regen Prosedürü (gt-taslak hazırlık, 2026-09-02)

> Bu dosya, GT v5 regen'inin **denetimli oturumda** (kullanıcı gözetiminde, prod erişimiyle)
> uygulanacak adım listesidir. Idle görev yalnızca bu planı üretti — hiçbir adım burada
> çalıştırılmadı. Kapsam: 17 eski audit maddesi + 4 yeni delta maddesi (bkz. fark-matrisi §B) = **21 madde**.

## 0. Önkoşullar (kapı)

- [ ] Kullanıcının açık regen emri (DB'ye salt-okunur çağrı + GT dosyasına yazma).
- [ ] Prod token `tools-bank/.env`'te (demo token ile KARIŞTIRMA — demo proje ayrı hesap).
- [ ] Bu paketin 4 dosyası worktree'den main'e merge edilmiş olmalı: `gt-v5-taslak.sql`,
      `fark-matrisi.md`, `hekim_listesi-karar.md`, `regen-proseduru.md`.
- [ ] `hekim_listesi` kararı kullanıcıda alındı (karar dosyası §Öneri: (b) temizleme).

## 1. Taze kanıt çekimi (salt-okunur — tek sorgu paketi)

```sql
-- 1a. İmza envanteri (yeni snapshot'ın ham kaynağı):
SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args,
       pg_get_function_result(p.oid) AS ret, p.prokind
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' ORDER BY 1, 2;
-- 1b. Sayım gizemi kapanışı (fark-matrisi §C — başlıktaki "195" testi):
SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public';
SELECT p.prokind, count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' GROUP BY 1;
-- 1c. Tablo/view/trigger envanteri + id tipleri (information_schema.columns).
```

- [ ] 1a'yı 2026-08-31 snapshot'ıyla karşılaştır: farklar yalnız 20260901000001/000002'den
      gelenler olmalı (fark-matrisi §B listesi). Beklenmedik imza varsa DUR, raporla.
- [ ] Sayım gizemi sonucunu snapshot başlığına işle (195 mi, 189+6'nın ne olduğu).

## 2. Gövde çekimi ve taslak karşılaştırması

- [ ] 21 maddenin her biri için canlı `pg_get_functiondef` çıkar.
- [ ] Taslak gövdeleriyle (migration son-kazanan) normalize karşılaştır:
      - Eşit → taslak onaylanır, GT'ye taslak metni girer.
      - **Farklı → CANLI KAZANIR**; farkı kaydet ("migrations dışı canlı değişiklik" olarak
        docs'a not düş, sonraki migration disiplini için).
- [ ] #8-9 (`search_code`, `search_memory_notes`): gövde YALNIZ canlıdan gelir (stub'lar).
      TABLE kolon listelerini de canlıdan al.
- [ ] #12: canlıda `tohumlama_abort` 2 overload görünüyor — İKİSİNİN de tanımını çek.
- [ ] #13: canlıda `_gorev_dinle` kaç imza? (snapshot'ta yalnız 4p) — overload envanterini netle.

## 3. GT v5 dosyasının oluşturulması

Sıra (mevcut GT düzeni korunur — bölümler, GRANT blokları, seed INSERT'ler):

1. Mevcut GT'yi başlangıç temeli al; aşağıdaki YAMA sırasını uygula:
   - [ ] Bölüm A+C: 11 eksik fn + guard trigger'ları + `CREATE TRIGGER` blokları ekle
         (gövdeler adım 2'nin onaylı metinleri).
   - [ ] Bölüm B: `tohumlama_abort` (3p ana + 2p eski overload kararı: canlıda duruyorsa
         İKİSİ de GT'ye; 2p'yi düşürme kararı ayrı migration ister, regen'de yapılmaz) ve
         4-param `_gorev_dinle` (3p gövdesini DEĞİŞTİR, yan yana iki tanım BIRAKMA).
   - [ ] Bölüm C: `tohumlama.id` ve `stok_hareket.id` → `uuid` yaz (canlı gerçek).
   - [ ] Bölüm D: `kupe_musait_mi` / `hayvan_ekle`(15p) / `hayvan_guncelle`(18p) /
         `asistan_hayvan_detay` gövdelerini 20260901000002 tabanlı onaylı metinle değiştir.
   - [ ] Bölüm E: hekim_listesi kararı (b) ise GT:2610 GRANT satırını SİL; (a) ise CREATE+GRANT ekle.
   - [ ] Duplikatlar (#17-20): tek imza bırak (son kazanan gövde); ara `DROP FUNCTION`
         satırları yeniden-oynatma scripti özelliğidir — regen çıktısında yer almasın.
2. [ ] `dogum_kaydet`/`hayvan_belirsiz_ureme_listele` DOKUNMA (senkron doğrulandı).

## 4. Doğrulama (kapı — hepsi geçmeden commit yok)

- [ ] `scripts/ground-truth-audit.sh` çalışır (mevcut sayaçların üstüne yeni beklenti:
      tablo ~47, fn sayısı adım 1b'den; script raporu kayda geçsin).
- [ ] İmza düzeyi GT ↔ 1a envanteri diff = **0 sapma** (2026-09-01 audit metodolojisiyla
      normalize karşılaştırma — aynı Python normalizasyonu kullanılabilir).
- [ ] `grep -n "FUNCTION public.hekim_listesi\|GRANT EXECUTE ON FUNCTION public.hekim_listesi"`
      çıktısı kararla tutarlı.
- [ ] ID tipi: GT'de `tohumlama`/`stok_hareket` `id uuid` + `::text` gövde kalıntıları
     bilinçli bırakıldı notu (canlıyla aynı).
- [ ] Yeni GT dosyası HİÇBİR ortama ÇALIŞTIRILMADI (regen = dosya üretimi, deploy değil;
      canlı zaten hedef durumda).

## 5. Kapanış işleri

- [ ] `2026-09-01-gt-v5-audit.md`'ye kapanış damgası (21/21 madde + tarih + commit).
- [ ] `rpc-reference.md`: `hekim_listesi` notu karara göre güncelle; `agent_plans_prune`
      "GT'de YOK" notu düşer.
- [ ] AGENTS.md "ground_truth ONARILDI" bölümünü v5 ile güncelle (tarih + sayaçlar).
- [ ] `2026-08-31-live-schema-imzalar.md` başlık sayımı düzelt (§C sonucu) veya gerekçe notu.
- [ ] TEK commit: `docs(db): GT v5 regen — 21 madde kapandı (audit+delta)`.
- [ ] Session-update skill'i ile öğrenileri kaydet (migrations-dışı canlı değişiklik listesi varsa özellikle).
