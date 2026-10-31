# t2 — Görev ↔ Protokol Uyarıları senkron teşhisi
job_id: j-20261030T181742Z-9487d5
## Plan maddesi
Sahip şikayeti: "görevlerden done edilen bir şey protokol uyarılarından düşmüyor. protokol uyarılarından yapılan giriş görevlerden düşmüyor. DB'den check edelim." Daha önce fixlenmiş sanılıyor (bkz. commit 234aaec, b81829e / migration 20260710000001, 20261013000004_k8_gorev_senkron.sql). Kök nedeni kanıtla bul. FIX YAZMA.
Ekrandaki gecikmiş satırlar (küpe · uyarı · protokol):
169 · 39. Gün PG (Presynch-14 senkron) · 4 g gecikmiş · DOGUM_PROTOKOL
906 · Rota-Corona Aşısı 38 g · SC Ademin 18 g · IM E Vitamini 13 g · ILERI_GEBE_PROTOKOL
154 Rota-Corona 15 g · 155 Rota-Corona 25 g · 903 Rota-Corona 14 g · 191 Rota-Corona 15 g · 145 Rota-Corona 14 g · 201 Rota-Corona 17 g
207 Rota-Corona 26 g · SC Ademin 6 g · IM E Vitamini 1 g · 196 Rota-Corona 10 g (hepsi ILERI_GEBE_PROTOKOL)
Önce .harness/references/domain-rules.md §12, §15 oku; `ileri_gebe_gorev_kontrol` notu önemli.
İncele (hepsi):
1. Canlı prod (yalnız SELECT): `protokol_eksik_tara` gövdesi + hangi kaynaklara baktığı; bu RPC'nin bu 14 hayvan için şu anki çıktısı (fonksiyon salt-okuma ise çağır; değilse çağırma, kontrol et); protokol_dismiss tablosu.
2. Her satır için tablo tablo: gorev_log (açık/tamamlanmış/iptal, etken_kod, stok_id, hedef_tarih, tamamlanma_tarihi), vaccinations, uygulama_log, drug_administrations, protokol_dismiss. Tablo: satır → görev var mı/durumu → uygulama kaydı var mı → tarayıcı neden "eksik" diyor. Hangi satırlar GERÇEK eksik, hangileri false-positive? Ayrı say.
3. İki yön: (a) görev done → tarayıcı düşürüyor mu (eşleme alanı: etken_kod/stok/aşı adı/tarih penceresi); (b) uyarıdan 💉 Uygula → hangi RPC/kayıt yazılıyor, eşleşen açık görevi kapatıyor mu (DB ya da JS). Frontend: Uygula butonu handler'ı, dismiss ✕, k8 görev senkron kodu (atlas_query → gövde Read). 20261013000004 canlıda mı, gövdesi aynı mı (drift).
4. Son dönemde her iki yönde örnek gerçek olay bul (uygulama var, görev açık kaldı; görev kapalı, uyarı duruyor) — tarih/id ile.
Canlı sorgu yöntemi: `cd ~/egesut-erp1; set -a; source ./.env; set +a; curl -sS -X POST "https://api.supabase.com/v1/projects/${SB_PROJECT_REF:-zqnexqbdfvbhlxzelzju}/database/query" -H "Authorization: Bearer ${SB_MGMT_TOKEN}" -H "Content-Type: application/json" --data-binary @<json dosya>`. urllib kullanma, token'ı yazdırma. Geçici dosya: $HOME/tmp. Not: protokol_eksik_tara tek jsonb array döner. Prod'a yazma YOK; yan etkisi belirsiz fonksiyonu çağırma (`protokol_orphan_temizle`, `protokol_gorev_bol` yalnız p_dry_run=true).
Rapor: satır bazlı tablo, kök neden(ler) iki yön ayrı (dosya:satır / sorgu kanıtı, CONFIRMED/OBSERVED/INFERRED), minimal fix önerisi, veri onarımı gerekiyor mu (kaç satır).
## Model
opus
## Yazılabilir dosyalar
runs/2026-10-30-some-fixes/t2-report.md
## Review: T1
