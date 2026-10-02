# GÖREV — Plan ek düzeltmesi: sahip cevapları §10d (4 karar) — glm-max lead (aynı koltuk)

İlk iş: /using-superpowers-obra. **ultracode YASAK.** Commit, kod, DB yazma YOK.
**GLM saat kuralı:** 08:50'yi geçtiyse yeni adım/alt-ajan başlatma; adımı bitir, /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-fix2-ILERLEME.md'ye yaz, dur.

## Girdiler
- Sahip kararları: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/design.md **§10d** (+ §10c #7 satırı güncellendi)
- Domain kuralları: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/.harness/references/domain-rules.md §18.13 (tek üretici), §18.17 (ertele/dashboard)
- Düzeltilecek: /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md (v2 → v3)

## Yapılacak (numaralı; DONE birebir sayar)
1. **+21/+35 kaldırma (§10d #1):** yeni P maddesi (ya da P2a alt maddesi — gerekçeyle seç): `tohumlama_kaydet`'in güncel gövdesinden (`supabase/migrations/20260923000005_ovsync_vaka_kapanis.sql:438-444`) GEBELIK_KONTROL INSERT'i çıkar; gövdenin geri kalanı birebir. Etki analizini ÖNCE yap (atlas_status + atlas_query / gitnexus): `TOH-` kaynaklı görevlere, "21. Gün"/"35. Gün" metnine, `protokol_instance` UREME/TOHUMLAMA bağına dayanan RPC/JS/test noktaları (ör. `tohumlama_sonuc_bos`/`tohumlama_sonuc_gebe`'nin `kaynak='TOH-…'` görev iptali, tohumlama_kaydet'in eski Bekliyor döngüsü). Cron görevi (`gebelik_muayene_gorev_uret`) hangi `kaynak`'la doğuyor — Gebe/Boş sonucu cron görevini de kapatıyor mu? Kapanmıyorsa plan bunu K15 çakışma tasarımına bağlar. Kabul: db-validate PASS, demo provada yeni tohumlama sonrası GEBELIK_KONTROL doğmaz, cron ≥40 g doğurur.
2. **Veri temizliği AYRI P maddesi (§10d #1):** açık (tamamlanmamış, iptal değil) `+21/+35` GEBELIK_KONTROL görevleri — seçim ölçütü (aciklama/kaynak/hedef_tarih), önce SAY (demo), sonra iptal; kod fix'ten ayrı madde; PROD uygulaması sahip kapısı. Cron'un aynı hayvana ≥40 g'de görev doğurmasıyla çift görev oluşmadığını kabul ölçütüne yaz.
3. **S2 görevsiz satır (§10d #2):** varsayım → karar; hayvan detayı; SPEC SORUSU'ndan çıkar.
4. **Erteleme saati (§10d #3):** P2b ERTALE `p_saat` varsayılanı **NULL (saatsiz)** — iki görev tipinde; "ön ayar önceki hedef_saat" ifadesini her yerden kaldır (P2b, P8, kapanış tablosu #7, T eşlemeleri). Genel ertele butonu yok (seed eklenmez) — karar olarak yaz.
5. **Dashboard 40 g satırı (§10d #4):** açık GEBELIK_KONTROL görevi varsa birleşik muayene ekranı (`_muayeneSonucAc`), yoksa hayvan detayı — ilgili P maddesine (P9 uygun görünüyor) + kabul + T eşlemesi; A4 akış haritasına "hedef (to-be)" dalı ekle.
6. SPEC SORULARI bölümünü "Sahip cevapları — §10d" olarak kapat; KATALOG GÜNCELLEME listesine yeni kalemleri ekle (21/35 görev beklentisi olan T'ler, dashboard satırı, ertele saatsiz); kapsama matrisi/izlenebilirlik tablosunu güncelle; başlığı v3 yap.

## Yazabileceğin dosyalar (liste dışı YASAK)
- /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md
- /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-fix2-DONE.md, /home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-fix2-ILERLEME.md
Okuma alt-ajanları ≤6, dosya yazmaz. Tarayıcı yürüyüşü bu turda gerekmez (yalnız to-be dal).

## DONE
/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/plan-fix2-DONE.md — TAMAM|KISMI|BLOKE; 1–6 kalemin her biri ayrı satır (yapıldı/yer); etki analizi bulguları (dosya:satır); yeni SPEC SORULARI (uydurma yok).
Sonra SendMessage ile tek satır: `DONE: <mutlak yol> · sonuc: <...>` → alıcı oturum: **ovsync-takip-dd**.
