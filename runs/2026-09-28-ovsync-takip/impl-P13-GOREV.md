# impl-P13 — GOREV zarfı: Doküman yüzeyleri (SIRALI EN SONDA)

- **Goal:** `G-20260930-OVSYNC-TAKIP-IMPL` (active)
- **Plan madde:** **P13** — `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:705-721` (MADDE DRIFT KAPISI: yalnız P13; SIRA: yalnız P1–P12 TAMAMSA koşar)
- **GOREV (bu dosya):** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P13-GOREV.md`
- **DONE:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P13-DONE.md`

## Yazma manifesti (TEK YAZICI — liste dışı YASAK)

1. `.harness/references/rpc-reference.md` (MODIFY)
2. `.harness/references/ui-map.md` (MODIFY)
3. `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P13-DONE.md` (create)

## Zorunlu davranış protokolü

1. **İLK İŞ:** `/home/melik/.claude/skills/using-superpowers-obra/SKILL.md` oku ve uygula (sahip kuralı; SUBAGENT-STOP geçersiz).
2. Kaynak gerçeği: teslim maddelerin DONE'ları (`runs/2026-09-28-ovsync-takip/impl-*-DONE.md`) + canlı demo şema (psql pg_get_functiondef — migration geçmişi değil, CANLI otorite). domain-rules.md §18.15-17 spec'le uyumluysa DOKUNMA; çelişki görürsen DUR ve DONE'da sahibe soru olarak yaz.
3. En fazla 2 self-repair; commit atma; sessiz varsayılan yasak.

## Görev (plan.md:713-717 birebir)

1. **rpc-reference.md:** 2 yeni RPC (`ovsync_takip_listele`, `tohumlama_bos_ve_devam` — parametre/red/geri dönüş tabloları canlı gövdeden), `gorev_tamamla` guard (H6 üç-dal: MUAYENE_SONUC_GEREKLI / p_iptal muaf / mevcut davranış), `gebelik_muayene` sistemi değişiklikleri, red kod tabloları: OVSYNC_SECIM_KISIR/ERKEN, TAKIP_ACIK:*, TAKIP_UZADI, TOH_SONUCLU, TAKIP_KAPALI, MUAYENE_SONUC_GEREKLI, GIRIS_CIFT_ANLAMLI, OZELLIK_KAPALI, ERTALE kuralları; C2 tablosundaki 6 üreticinin p_takip_onay/p_takip_onaylar imzaları; H5 satır-sonucu alan adları (impl-P3b-DONE.md tablosu).
2. **ui-map.md:** `#pg-ovsync` sayfası + 3 yeni bottom-sheet (devam seçici `_devamSeciciAc`, muayene sonuç ekranı `_muayeneSonucAc`, TAKIP_ACIK/birleşik onay `_takipAcikAc`) + görev tipleri TAKIP_MUAYENE/GEBELIK_KONTROL özel tamamlama akışı (jenerik buton exclusion — P10 envanteri) + 6. stat hücresi/🔔/Görevler köprüleri (P7).
3. **Ground-truth kapısı (#12) — RAPOR KALEMİ (dosya yazma YOK):** plan.md:717'deki değişen-fonksiyonlar listesini + tam migration replay sonrası `pg_proc` son-kazanan doğrulama gereksinimini DONE'da sahibe-rapor bölümü olarak yaz; `99999999999999_ground_truth.sql` dosyasına DOKUNULMAZ; ground-truth yenileme talebi manifest kapısına (sahip) bırakılır.
4. domain-rules.md: yalnız OKU — §18.15-17 uyum kontrolü; çelişki yoksa DONE'da tek satır teyit.

## Kabul ölçütleri (plan.md:719)

1. docs-update `pre-commit` checkpoint PASS/PARTIAL makul gerekçeli (dokunulmayan dosyalar gerekçelenir).
2. Replay doğrulama raporu (adım 3) DONE'da — sahibe-rapor formatında, ayrıntılı fonksiyon listesiyle.
3. rpc-reference tabloları canlı gövdeyle eşleşiyor (nokta kontrol: en az 3 RPC imzası psql'den kanıtlı).
4. `git diff --check` temiz.

## Yasaklar

- Kod dosyaları (js/, tests/, supabase/); `99999999999999_ground_truth.sql`; domain-rules.md yazımı (yalnız okuma + rapor); design/plan dosyaları; PROD; `.ss/`, `main`; commit atma.

## DONE şablonu

Başlık: `impl-P13-DONE — TAMAM|KISMI|BLOKE` · dokunan dosya listesi + gerekçe · nokta-kanıtlar (psql çıktıları) · ground-truth sahibe-raporu · domain-rules teyit satırı · açık kalem.
