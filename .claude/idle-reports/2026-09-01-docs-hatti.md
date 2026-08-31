# Idle-A Raporu — Canlı-Şema Doküman Hattı (2026-09-01)

**Worktree:** `/home/melik/egesut-wt/docs-hatti` · branch `idle/docs-hatti` · Görev: `IDLE-GOREV.md`
**Guardrail durumu:** Supabase'e sıfır çağri (tek şema kaynağı 2026-08-31 snapshot'ı) · push yok · kod değişikliği yok.

## Durum: TAMAM (4/4 çıktı + rapor, tek commit)

| Çıktı | Dosya | Satır | İçerik |
|---|---|---|---|
| 1 | `.claude/rpc-reference.md` | 551 | Sıfırdan regen: snapshot'ın **185 benzersiz adı / 189 imzasının tamamı**; her girdide imza + dönüş şekli + js çağrı yeri (grep, güncel satırlar) veya "kullanılmıyor (cron/Edge/legacy/trigger/internal)" notu. C1-C4 düzeltmeleri + D1/D2 kontrat notları + geri_al tek girdi + 73 eksik RPC dahil. **Git'e işlendi** (untracked'tı). |
| 2 | `.claude/schema-snapshots/2026-09-01-gt-v5-audit.md` | 71 | GT v5 AUDIT (regen değil): 22 satırlık sapma tablosu — 11 canlıda-var/GT'de-yok fn, 2 imza sapması, 2 id-tip sapması, 5 GT iç tutarsızlık, 2 kozmetik. **17 madde denetimli regen gerektiriyor** (madde listesi tabloda). |
| 3 | `.claude/domain-rules.md` | 338 | §2.2'nin 8 çelişkisi + §2.3'ün 8 bayatlığı düzeltildi; dosya sonunda **Düzeltme Günlüğü** tablosu — 16 satırın her biri "hangi taraf doğru + kanıt" gerekçesiyle. |
| 4 | `.claude/ui-map.md` | 128 | Mevcut koddan yeniden üretildi: ui.js (8513 satır, 40 bölüm) + forms.js (20 bölüm) + api.js (8 bölüm) + app.js (7 bölüm) + güncel aralıklarla dispatch rehberi. Eski 2.8k-dönemi aralıkları tamamen atıldı. |

## Yöntem

- RPC çağrı envanteri: Python regex taraması (`rpc(`, `rpcOptimistic(`, `db.rpc(`) → 105 doğrudan +
  ternary/dinamik çağrılar el ile (`tohumlama_kaydet`/`planli_tohumlama_kaydet` forms.js:295, `geri_al`
  forms.js:1336-1355 dinamik rpcName, `kategori_ekle/guncelle` ui.js:4042, `disease_ekle/guncelle` ui.js:3422)
  + `buildRpcParams` replay seti (ui.js:6789, 13 case) + Edge `tools.ts` (4 asistan RPC'si) + cron seti.
- GT karşılaştırması: Python normalize (DEFAULT atma, `without time zone`/alias normalize, `int`≡`integer`).
  İlk geçişte argsız fn'ler falsy-`[]` bug'ıyla yanlış FARKLI görünmüştü — düzeltilince gerçek sapma sayısı 2'ye indi.

## Bulunan Çelişkiler (kaynak değiştirilmeden rapora işlendi)

1. **Snapshot başlık sayımı:** dosya "195 giriş" diyor; fiziksel imza satırı **189**, benzersiz ad **185**.
   (Muhtemelen pg_proc satır sayımı; GT v5 regen oturumunda netleşmeli.)
2. **`hekim_listesi`:** js çağırıyor (app.js:30), migration 20260308000009:321 tanımlıyor, ama canlı snapshot'ta
   YOK ve GT'de CREATE'siz GRANT (GT:2609) duruyor → canlıdan düşmüş görünüyor. Uygulama config.js fallback'le
   çalışmaya devam ediyor (catch bloğu). rpc-reference'a "CANLIDA YOK" notuyla işlendi; DB'de karara gerek
   (geri yükleme veya GT temizliği) — audit #16.
3. **docs-tutarlilik §4.2 çürütüldü:** rapor "stok_hareket.id = text, GT doğru" demişti; snapshot canlıda
   **uuid** diyor. AGENTS.md'in uuid'li hali doğru, GT bayat (audit #15).
4. **Denetim bulguları 2'si tarihe karıştı:** §2.2/7 (erkek↔grup backend guard yok) ve §2.3/8 (ileri doğum tarihi
   backend yok) — 20260831000003 tablo guard trigger'ları bunları karşılıyor; canlıda deploy'lu (snapshot
   envanteri). domain-rules'a "düzeltilmiş" işlendi, kod eksiği olarak değil.
5. **`_gorev_dinle` YENİ sapma:** canlıda 4 param (`p_tarih` ekli), GT'de 3 (audit #13).
6. **docs-tutarlilik satır numaraları eski dönemden:** ör. `hekim_ekle` ui.js:6867→6990, `stok_hareket_ekle`
   ui.js:6678→buildRpcParams içi. Tüm yeni referanslar worktree kodundan taze grep ile alındı.
7. **`drug_product_ekle` çağrısı bulunamadı:** js'te doğrudan çağrı yok; `ilac_ekle` gövdesi drug_products satırı
   üretiyor olabilir (gövde incelemesi gerekir) → "kullanılmıyor" notu şüpheli işaretli, kaynak değiştirilmedi.
8. **Kullanılmayan canlı RPC'ler:** `stat_gebelik_ozet`, `get_vaccination_schedule`, `list_vaccinations`,
   `asi_sil`, `drug_ekle/guncelle/sil`, `sperma_sil`, `case_geri_al`, `case_plan_notu_guncelle`,
   `hastalik_kaydet`, `tedavi_guncelle`, `abort_kaydet` (legacy) — hepsi rpc-reference'ta durum notuyla.
9. **Demo RPC'leri** (`demo_klonla`, `demo_sema_diff`) PROD snapshot'ında yok — ayrı demo projesine ait;
   rpc-reference'ta ayrı bölümde (public-by-design kararıyla uyumlu).

## Kabul Kriterleri Karşılaması

- ✅ rpc-reference: 185/185 ad kapsandı (script doğrulaması: 0 eksik), her girdide çağrı yeri veya not
- ✅ GT audit: 22 satırlık tablo + 17 denetimli-regen maddesi işaretli
- ✅ domain-rules: 16 düzeltme + Düzeltme Günlüğü gerekçe tablosu
- ✅ Worktree'de tek commit + bu rapor

## Sonraki Adımlar (ana oturum için)

1. GT v5 gövde regen'i denetimli oturumda (audit tablosundaki 17 madde; özellikle hekim_listesi kararı).
2. `buildRpcParams` (ui.js:6789) imza düzeltmesi — kod tarafı, ayrı görev (docs-tutarlilik §1.6).
3. `stat_suru_ozet` × sessiz liste 9999 tutarsızlığı hâlâ açık (domain-rules §4 notu).
