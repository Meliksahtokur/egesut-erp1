# plan-fix2 DONE — 2026-09-29

**Sonuç: TAMAM** — `docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md` **v3** (§10d 4 sahip kararı uygulandı; SPEC SORULARI kapandı). Commit/kod/DB yazılmadı. Kırıntı: `.crumbs/ovsync-takip.jsonl` (3 kayıt).

## 1–6 kalemin kapanışı (birebir)

1. **+21/+35 kaldırma — YAPILDI: yeni P2c maddesi** (gerekçe: farklı migration dosyası 20260929000004 + farklı doğrulama döngüsü + P1/P2a ile paralel). `tohumlama_kaydet` güncel gövdesi (20260923000005) CREATE OR REPLACE birebir; **yalnız :438-444 görev INSERT bloğu çıkar; `protokol_instance` INSERT (:434-436) kalır**. Kabul: db-validate PASS + demo provada yeni tohumlamada GEBELIK_KONTROL doğmaz + cron ≥40 g doğurur + çift görev yok.
2. **Veri temizliği AYRI — YAPILDI: yeni P2d maddesi** (20260929000005): ölçüt `gorev_tipi='GEBELIK_KONTROL' AND NOT tamamlandi AND NOT iptal AND kaynak LIKE 'TOH-%'` (açıklama çapraz doğrulama); ÖNCE SAY (demo) → iptal + islem_log izi; idempotent; PROD sahip kapısı. Çift-görev-yok kabulü yazıldı (cron `NOT EXISTS` açık görev [20260925000002:352-354]).
3. **S2 görevsiz satır — YAPILDI:** varsayım → karar (hayvan detayı; görev ertesi sabah cron'la, satırdan doğmaz). P6 + P9 + A3/A4 notları; SPEC SORULARI bölümünden çıktı.
4. **Erteleme saati — YAPILDI:** `p_saat` varsayılan **NULL (saatsiz)**, iki görev tipinde; "ön ayar önceki hedef_saat" ifadesi P2b'den, P8'den, P12 senaryosundan ve Review kapanış tablosu #7'den KALDIRILDI; T-25/T-26 eşlemeleri güncellendi; genel ertele butonu YOK karar olarak P2a'ya işlendi.
5. **Dashboard 40 g satırı — YAPILDI:** P9'a alt madde + kabul + T eşlemesi: `acik_gorev_var=true` → IDB'den açık GEBELIK_KONTROL bulunup `_muayeneSonucAc`; bulunamazsa/false → `openDet` (bugünkü). A4 akış haritasına "to-be" dalı eklendi.
6. **Kapanış işlemleri — YAPILDI:** SPEC SORULARI → "Sahip cevapları — §10d" tablosu (4/4, açık soru kalmadı); KATALOG GÜNCELLEME'ye 9-11. kalemler; kapsama matrisine P2c/P2d/dashboard satırları; izlenebilirliğe §10d satırı; başlık v3 + sürüm bloğu.

## Etki analizi bulguları (dosya:satır; plan.md (d) bloğuna işlendi)

- **Güncel üretim yeri:** `supabase/migrations/20260923000005_ovsync_vaka_kapanis.sql:432-444` — `v_kaynak='TOH-'||v_toh_id`; iki GEBELIK_KONTROL INSERT (+21 `:441-442`, +35 `:443-444`), `protokol_instance_id` bağlantılı; **`protokol_instance` INSERT `:434-436` (UREME/TOHUMLAMA) görevden bağımsız — KALIR**.
- **Tarihî üreticiler** (dokunulmaz migration geçmişi): 20260306000008:217-218, 20260308000009:295-297, 20260326000030:70-71, 20260521000003:141-142, 20260522000002:334-336, 20260522000004:137-139, 20260522000005:83-85, 20260526000003:84-86, 20260531200000:106-108, 20260601000005:110-112, 20260605000002:102-104 — son kazanan 20260923000005.
- **Sonuç→görev kapanışı TİP bazlı, kaynak değil:** `tohumlama_sonuc_bos` `supabase/migrations/20260924000001:538-547` (`gorev_tipi IN ('GEBELIK_KONTROL','TOHUMLAMA_HAZIRLIK')`) → **Gebe/Boş sonucu cron görevini de kapatıyor**; K15 uyumu: muayene yolu görevi önce tamamlar (P2b) → filtre dokunmaz; m-toh-det'ten doğrudan Boş → açık görev iptali bugünkü gibi. `tohumlama_sonuc_gebe` aynı tip filtresi `20260830000031:52-57`.
- **Cron görevinin kaynağı:** `'GEBELIK-KONTROL-'||tohumlama_id` [20260925000002:369-374] — temizlik ölçütüyle (`TOH-` öneki) ayrışır; cron açık görev varsa üretmez [:352-354] → çift görev oluşmaz.
- **JS bağımlılığı YOK:** worktree grep — '21. Gün'/'35. Gün'/'TOH-' js/ altında yok (yalnız `ILK-TOH-`/`ACIK-DISI-` rozet ön ekleri js/ui.js:1678-1688, ilgisiz).
- **Test bağımlılığı YOK:** tests/ grep — yalnız `ILK-TOH-*` etiket testleri (tests/modal-router.spec.js:226, tests/unit/ovsync-pg-ui.test.js:35), +21/+35 görev üretimi beklentisi yok.
- **Eski-Bekliyor döngüsü etkilenmez:** `20260923000005:372-407` (yeni tohumlamada eski Bekliyor cycle kapatma) görev INSERT'inden ayrı satırlar.
- **Ground-truth riski:** `99999999999999_ground_truth.sql` içinde 2 adet "21. Gün" geçişi → P13 replay doğrulamasına P2c dahil edildi (son-kazanan yeni gövde olmalı; ground-truth dosyasına dokunulmaz).
- Atlas notu: `atlas_status` kurulumuzdu (önbellek yok); JS etkisi worktree grep + gövde okumasıyla kesinleştirildi — atlas sorgusu gerekmedi (JS'te hedef sembol kalmadı).

## Yeni SPEC SORULARI

**Yok** — 4 sorunun tamamı §10d ile cevaplandı; etki analizinden yeni soru doğmadı (uydurma cevap üretilmedi).

## Notlar

- Tarama alt-ajanı kullanılmadı (gerekmedi — 3 dar tarama doğrudan); süreç limitleri aşılmadı; tarayıcı yürüyüşü gerekmedi (yalnız to-be dalı eklendi).
- Çalışma 07:30–07:55; GLM durma penceresine (09:00) ~1 saat mesafe.
