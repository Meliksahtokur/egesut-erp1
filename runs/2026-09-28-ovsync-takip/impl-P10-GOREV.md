# impl-P10 — GOREV zarfı: TAKIP_ACIK/PG_KAPI onay zinciri (birleşik kapı)

- **Goal:** `G-20260930-OVSYNC-TAKIP-IMPL` (active)
- **Plan madde:** **P10** — `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/docs/plans/2026-09-28-ovsync-takip-ekrani/plan.md:638-658` (MADDE DRIFT KAPISI: yalnız P10)
- **Önkoşul:** P3b (sunucu — bitik; **H5 alan adı tablosu `runs/2026-09-28-ovsync-takip/impl-P3b-DONE.md`'da — UI bu tabloya bağlanır**), P8 (sheet deseni), P9 (çağrı noktaları).
- **GOREV (bu dosya):** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P10-GOREV.md`
- **DONE:** `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P10-DONE.md`

## Yazma manifesti (TEK YAZICI — liste dışı YASAK)

1. `js/ui.js` (MODIFY — `_takipAcikHata`/`_takipAcikAc` + çağrı noktası catch'leri + bulk satır listesi sheet'i)
2. `js/forms.js` (MODIFY — PG/Ovsync çağıran noktaların catch'leri)
3. `tests/unit/ovsync-takip-kapi.test.js` (create — kapı-çağrı noktası envanter senkron testi, grep tabanlı)
4. `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-takip/runs/2026-09-28-ovsync-takip/impl-P10-DONE.md` (create)

## Zorunlu davranış protokolü

1. **İLK İŞ:** `/home/melik/.claude/skills/using-superpowers-obra/SKILL.md` oku ve uygula (sahip kuralı; SUBAGENT-STOP geçersiz).
2. **Kod öncesi:** domain-rules.md + ui-map.md + code-change-precheck; `atlas_query` ile çağrı noktası konumlarını doğrula (plan satır numaraları bayat olabilir); mockup 04 copy BİREBİR (`runs/2026-09-28-ovsync-takip/mockup/`).
3. **Kırmızı test ÖNCE:** kapı-çağrı noktası envanter senkron testi (grep tabanlı — P3b listesiyle birebir).
4. **Bitiş kapısı:** `verification-before-completion-obra`; `node --check` + test koşumu.

## Görev (plan P10 birebir — plan.md:645-654; çağrı noktası listesi plan.md:651'den KESİN + atlas doğrulamalı)

**Arayüz (Produces):** `_takipAcikHata(e, retry)` + `_takipAcikAc(detay, retry)` — `_pgKapiHata`/`_pgKapiAc` deseninin TAKIP_ACIK ikizi [ui.js:1384-1478 kalıbı]. **Birleşik:** payload `PG_KAPI:TAKIP_ACIK:{...}` → TEK bottom-sheet iki gerekce alt alta, tek "Evet, uygula" — retry `p_onay=true` VE `p_takip_onay=true` tek çağrı. **Alan adları P3b DONE H5 tablosundan** (uydurma yok).

**İş:**
1. Onay bottom-sheet copy (mockup 04 aynen): başlık "🔍 Bu hayvan takipte"; metin küpe+zaman+fiil şablonu; butonlar "Evet, takibi kapat ve uygula" / "Vazgeç". `confirm()` YASAK; düz "Hata" toast YASAK.
2. Catch'e TAKIP_ACIK/birleşik dalı eklenen noktalar (P3b kapı listesiyle birebir): `_hayvanHizliUygulaKaydet`, `_protokolUygulaKaydet`, `_gorevStokTamamlaSubmit`, seans tamamlama UI'sı, toplu ilaç UI yolu, `ovsyncBaslat` (start_first_service_protocol), elle vaka aç submit (create_case), toplu vaka aç UI (vaka_toplu_ac), kızgınlık sorun vaka yolu (`sorunVakaAc` [ui.js:5737-5742] / `sorunBottomSheet` [ui.js:5655-5662] — C4), `_pgKapiBosAtaUygula`, sarmal RPC PG/OVSYNC seçimleri (P8'den yönlendirme).
3. **D4 UI — bulk satır-bazlı onay listesi:** red payload `{hayvan_id, pg_kapi_karar, takip_acik, takip_bilgi}` listesi tek sheet'te satır satır (küpe + iki gerekce alt alta); "Evet, seçilenleri uygula" → **onaylı alt kümeyle YENİ ÇAĞRI** (`p_animal_ids`=onaylananlar + `p_takip_onaylar` aynı küme); onaysız satırların sonucu listede (`TAKIP_ACIK` — uygulanmadı).
4. Retry: `__pgKapiTekrar` closure deseni [ui.js:1432-1438]; tekil `p_takip_onay=true`, toplu `p_takip_onaylar` id dizisi (C2 imza tablosu).

## Kabul ölçütleri (plan.md:656 — PW kanıtları P12'de)

1. **Grep denetimi testi yeşil:** sunucudaki her TAKIP_ACIK üreticisi için UI'da işleyen dal (nokta listesi = P3b listesiyle birebir: hizli_uygulama/seans_tamamla/bulk_ilac/start_first_service_protocol/create_case/vaka_toplu_ac/kizginlik_vaka_ac).
2. Birim testler: birleşik payload ayrıştırma + retry parametre seti + bulk alt-küme çağrısı.
3. `node --check` değişen JS; `git diff --check` temiz; kırmızı→yeşil çıktıları.
4. Tüm süit: yeni kırmızı KALMAZ (3 pre-existing hariç).

## Yasaklar

- `js/api.js` yazımı; `confirm()`; düz hata toast; alan adı uydurma (H5 tablosu dışı); mevcut `_pgKapi*` davranışını bozma.
- Commit atma; PROD; `.ss/`, `main`; sessiz varsayılan; 2 self-repair tavanı.

## DONE şablonu

Başlık: `impl-P10-DONE — TAMAM|KISMI|BLOKE` · kabul maddeleri kanıtlı · grep envanter çıktısı · kırmızı→yeşil çıktıları · yazılan dosyalar · açık kalem.
