# impl-P9 — GOREV zarfı: Boş/muayene giriş noktalarına bağlama + GEBELIK_KONTROL sonuç akışı (K15) + kalem 11

- **Goal:** `G-20260930-OVSYNC-TAKIP-IMPL` (active)
- **Plan madde:** **P9** — `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:590-617` (MADDE DRIFT KAPISI: yalnız P9; P10 onay zinciri YOK)
- **Önkoşul:** P8 KABUL (seçici bileşeni yerinde), P3b (DB guard — bitik).
- **GOREV (bu dosya):** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P9-GOREV.md`
- **DONE:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P9-DONE.md`

## Yazma manifesti (TEK YAZICI — liste dışı YASAK)

1. `js/forms.js` (MODIFY — `tohSonuc` :4335-4374 Boş dalı)
2. `js/ui.js` (MODIFY — muayene görev tamamlama akışı; görev listesi exclusion :2149; `_pgKapiBosAtaUygula` :1455; `_uremeTohumlama` :5978-6032 kalem 11; P6'nın `_ovsyncMuayeneSatirAc` köprüsünü gerçek `_muayeneSonucAc`'a bağla)
3. `js/utils/handlers.js` (MODIFY — yeni action kayıtları)
4. `js/gecmis.js` + `js/degisiklikler/etiketler.js` (MODIFY — TAKIP_MUAYENE etiketi)
5. `tests/unit/ovsync-takip.test.js` (MODIFY — kalem 11 testleri ekler; kalem 12 testi P9b-yardımcı'dan geliyor, koru)
6. `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P9-DONE.md` (create)

## Zorunlu davranış protokolü

1. **İLK İŞ:** `/home/melik/.claude/skills/using-superpowers-obra/SKILL.md` oku ve uygula (sahip kuralı; SUBAGENT-STOP geçersiz).
2. **Kod öncesi:** domain-rules.md + ui-map.md + code-change-precheck; JS keşfinde ÖNCE `atlas_query` (tohSonuc, detayTamamla, _pgKapiBosAtaUygula, _uremeTohumlama, _showSessizList/mRow), sonra bitişik JSDoc+gövde.
3. **Kırmızı test ÖNCE:** kalem 11 `_tohumlamaGecmisSatirlari` + bağlama testleri.
4. **Bitiş kapısı:** `verification-before-completion-obra`; `node --check` tüm değişen JS + test koşumu.

## Görev (plan P9 birebir — plan.md:600-613 tam liste; bölümden oku)

1. `tohSonuc('Boş')`: mevcut `confirm()` + doğrudan `tohumlama_sonuc_bos` KALKAR → `_devamSeciciAc('bos', {tohumlama_id})`. Gebe/Bekliyor yolları DEĞİŞMEZ.
2. **GEBELIK_KONTROL özel akışı (K15/§10c #5):** `detayTamamla` [ui.js:8956] görev_tipi dalı → jenerik doneTask DEĞİL → `ref_tohumlama_id`'den bağlam kurup `_muayeneSonucAc(gorev.id)`. Görev listesi exclusion [ui.js:2149]'a GEBELIK_KONTROL EKLENİR (TAKIP_MUAYENE ile; "✅ Tamamlandı" jenerik butonu gizlenir — P3b guard'ının UI ikizi). Gorev jenerik `gorev_tamamla`'ya ASLA düşmez.
3. **TAKIP_MUAYENE özel akışı:** aynı `_muayeneSonucAc` — iki görev tipi AYNI ekran (K15; T-04/T-05 ekran-özdeşliği).
4. **GEBE seçilince (muayene modu):** `tohumlamaBosVeDevam({p_muayene_gorev_id, p_secim:'GEBE'})` — sunucu görevi tamamlar + çekirdek uygular (P2b); UI'da ayrı gebeAta çağrısı YOK.
5. **PG kapısı değişir (#2):** `_pgKapiBosAtaUygula` [ui.js:1455] gövdesi: iki-RPC zinciri → `tohumlamaBosVeDevam({p_tohumlama_id, p_secim:'PG', p_notlar:'PG öncesi değerlendirme: '+gerekce})` TEK TRANSACTION; yarım durum YOK (T-11). Kapı = seçicinin "Boş + PG" karşılığı; seçici AÇILMAZ (S7).
6. **S2 "muayene vakti" satırı (A4):** aksiyon `satir.muayene_gorev_id` → `_muayeneSonucAc`; görev yoksa openDet (§10d #2 — görev ertesi sabah cron'la doğar).
7. **Dashboard 40 g listesi (§10d #4):** `_showSessizList` mRow [ui.js:2759] tıklaması: `acik_gorev_var=true` → IDB gorev_log'tan açık GEBELIK_KONTROL bul → `_muayeneSonucAc`; bulunamazsa/acik_gorev_var=false → openDet (bugünkü davranış; fail-closed).
8. 6c.4 "🐄 Kızgınlıkta → tohumlama kaydına geç": mevcut tohumlama formuna hayvan prefill geçişi.
9. S3'te takip rozeti + "Boş hayvan hiçbir bölümden düşmez" (§6c.5).
10. **Kalem 11 / D1-UI — üreme geçmişinde düzeltilen tohumlama İKİ SATIR:** `_uremeTohumlama` — IDB tohumlama `sonuc='Gebe'` VE islem_log GEBE_ATAMA snapshot'ında `bos_duzeltme` bloğu → aynı hist-row içinde üstte üstü-çizili `❌ Boş (Boş giris tarihi)` (tarih = bos_duzeltme.bos_atama_tarihi), altta `✅ Gebe (muayene tarihi)`; tahmini doğum Gebe satırından (mevcut hesap değişmez). Saf yardımcı `_tohumlamaGecmisSatirlari(t, islemLogKayitlari)` (test). İz Gebe kaydı tek satır kalır. **C1 normatif okuma:** GEBE_ATAMA seçerken `durum IS DISTINCT FROM 'geri_alindi'` + `ORDER BY tarih DESC, id DESC LIMIT 1` (P2b çözücüsünün UI ikizi); her iki tarih Europe/Istanbul yerel takvim gününe normalize — **fmtTarih ilk-10-karakter kesimi bu iki tarih için KULLANILMAZ** [helpers.js:58-64].
11. **P9b bağlama (P9b-yardımcı hazır gelince):** `_uremeTohumlama` satırına `gunFarkiEtiket(t.tarih)` etiketi; kalem 11 iki-satır görünümünde her satırın KENDİ tarihinden (Boş satırı Boş giris, Gebe satırı muayene tarihi).
12. Etiket sözlükleri: `js/gecmis.js` + `js/degisiklikler/etiketler.js`'e TAKIP_MUAYENE etiketi.

## Kabul ölçütleri (plan.md:615 birebir — PW kanıtları P12'de, P9'da birim/dolaylı)

1. Kalem 11 birim testi yeşil (`_tohumlamaGecmisSatirlari` iki-satır + izsiz tek satır + geri_alindi hariç + çoklu kayıtta son kazanır).
2. K15 kabul birim karşılıkları: GEBELIK_KONTROL/TAKIP_MUAYENE aynı `_muayeneSonucAc`; jenerik buton exclusion; gorev_tamamla'ya UI yolu yok; PG kapısı tek RPC (`_pgKapiBosAtaUygula` gövdesinde tek çağrı [CONFIRMED satır]).
3. `node --check` tüm değişen JS; `git diff --check` temiz; kırmızı→yeşil çıktıları.
4. Tüm süit: P9 öncesi kırmızı olmayan hiçbir test P9 sonrası kırmızı KALMAZ (mevcut 3 pre-existing hariç).

## Yasaklar

- `js/api.js` yazımı; P10 onay zinciri/birleşik sheet; Gebe/Bekliyor tohSonuc yollarında değişiklik; sunucu davranışı varsayma (P2b/P3b DONE'larındaki gerçek sözleşmeler).
- Commit atma; PROD; `.ss/`, `main`; sessiz varsayılan; 2 self-repair tavanı.

## DONE şablonu

Başlık: `impl-P9-DONE — TAMAM|KISMI|BLOKE` · kabul maddeleri kanıtlı · kırmızı→yeşil çıktıları · yazılan dosyalar · açık kalem.
