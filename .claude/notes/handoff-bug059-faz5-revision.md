# Handoff — BUG-059 Faz 5 Revizyon Gerekli (UI Reddedildi)

> ## ✅ REVİZYON TAMAMLANDI (2026-06-12, sonraki oturum)
> Karar: **in-place revizyon** (kullanıcı tercihi: "var olan ana modal geliştirilsin").
> - 3 modal template + `.med-*` karanlık CSS sistemi + JetBrains Mono **silindi**
> - Seans UI `m-case-det` gün akordeonlarına **inline** entegre edildi (mevcut `caseDrugFormAc` pattern'i):
>   şerit (`renderSeansSerit`), seans satırları (`renderSeansRow`), inline plan editörü (`caseSeansFormAc`),
>   erken kapat inline onay bölümü (`caseErkenKapatToggle/Onayla`) — hepsi pastoral tema token'larıyla
> - **Kritik bulgu:** 4 RPC wrapper'dan 3'ü yanlış parametre adı kullanıyordu (`p_vaka_id`/`p_tarih`/`p_not`
>   vs gerçek `p_case_id`/`p_date`/`p_existing_day_id`) → reddedilen UI backend'e hiç bağlanamıyordu. Düzeltildi.
> - Plan düzenleme `recete_guncelle` yerine `add_treatment_day_with_sessions(p_existing_day_id)` replace modunu kullanır
> - Undo chip kaldırıldı (backend'de undo RPC yok), `HIZLI_SAATLER` 24:00→20:00 (input[type=time] kabul etmiyor)
> - `planned_time` HH:MM:SS normalizasyonu eklendi (PostgREST time formatı eski regex'i kırıyordu)
> - Spec (`2026-06-12-bug059-ui-design-klinisyen-monitoru.md`) hâlâ karanlık estetiği anlatıyor — **OBSOLETE sayılmalı**
> Sıradaki: Faz 6 (E2E test) artık açık.

**Tarih:** 2026-06-12
**Oturum:** Faz 5 UI implementasyonu commit edildi ama kullanıcı tarafından **reddedildi**
**Durum:** Commit `4c732a6` main'de ama **kabul edilmedi** — revizyon gerekiyor

---

## 🚨 Kritik Karar

Commit `4c732a6` ("feat(BUG-059): Faz 5 UI - Klinisyen Monitörü") main branch'e push edildi, ancak kullanıcı tarafından **revize edilmesi gerektiği** bildirildi. Bir sonraki oturum (veya bu oturumun devamı) bu commit'i ya revert edip sıfırdan yapacak, ya da mevcut implementation'ı düzeltecek.

### Neden Reddedildi (Kullanıcı Söyledi)

> "yaptigin ui'dan memnun degilim revize edilmesi gerek. var olan modali gelistirmek yerine ucube bir ekleme yapmissin"

Çeviri: "UI'ından memnun değilim, revize edilmeli. Var olan modalı geliştirmek yerine ucube bir ekleme yaptın."

**Somut suç:** 3 yeni modal (m-tedavi-ekle, m-recete-duzenle, m-vaka-kapat) + paralel `.med-*` CSS sınıf sistemi ekledim, mevcut modal framework'ünü genişletmek yerine.

---

## 📊 Mevcut Durum

| Öğe | Durum |
|---|---|
| Commit `4c732a6` | main'de push edilmiş, **kullanıcı kabul etmedi** |
| Faz 5 implementasyonu | ❌ Revizyon gerekli |
| Faz 6 (10 E2E test) | ⏸️ Faz 5'e bağımlı, bloke |
| Faz 7 (Final handoff + ADR) | ⏸️ Faz 5 + 6'ya bağımlı, bloke |
| Spec | `.claude/specs/2026-06-12-bug059-ui-design-klinisyen-monitoru.md` — spec OK, implementasyon kötü |
| Dirty state | Önceki oturumdan: `supabase/migrations/20260611000002_bug059_rpcs.sql` (T2 parent_id fix, hâlâ uncommitted) |

---

## 🗺️ Commit 4c732a6 — Ne Nerede

**Diff özeti:** 6 dosya, 763 satır eklendi (13 silindi)

| Dosya | Eklenen | Sorun mu? |
|---|---|---|
| `js/config.js` | 6 sabit (UYGULAMA_YOLU, SEANS_STATE, SEANS_UNDO_WINDOW_MIN, PIP_STACK_OFFSETS, HIZLI_SAATLER, MAX_SEANS_PER_DAY) | ✅ Sorun yok — domain kuralları, kalabilir |
| `js/state.js` | 2 alan (tedaviPlan, aktifSeansUndo) | ✅ Sorun yok — kalabilir |
| `js/api.js` | 5 RPC_TABLES mapping + 4 wrapper (rpcAddTreatmentDayWithSessions, rpcSeansTamamla, rpcReceteGuncelle, rpcCloseCaseWithRemaining) | ✅ Sorun yok — kalabilir |
| `js/ui.js` | timeToRatio, computeSeansState, renderSessionsRibbon, renderSessionCard, updateNowCursor, openTaskDet extend, **openTedaviEkle + renderTedaviEkleForm, openReceteDuzenle + renderReceteDuzenleForm, openVakaKapat** | ⚠️ **Sadece ribbon logic + pure functions kalsın; 3 modal opener/func **silinecek** |
| `js/forms.js` | seansTamamla, **submitTedaviEkle, submitReceteDuzenle, submitVakaKapat**, event delegation | ⚠️ **seansTamamla kalsın; 3 submit handler + yeni data-action dispatch'leri **silinecek** |
| `index.html` | `--med-*` tokenlar, `.med-*` CSS (ribbon/pip/card/animasyonlar/3 modal template), JetBrains Mono font, **m-tedavi-ekle, m-recete-duzenle, m-vaka-kapat modal template'leri**, m-case-det 3 buton | ❌ **3 modal template silinecek; `.med-*` CSS büyük kısmı silinecek; JetBrains Mono eklentisi tartışmalı; m-case-det 3 buton kalsın ama farklı modal açacak** |

---

## ❌ Somut Yanlış: 3 Yeni Modal + Paralel CSS Sistemi

### Yanlış 1: 3 yeni modal template (index.html)
- `m-tedavi-ekle` (form: tarih + dinamik seans listesi + mini ribbon + hızlı saat + ekle/çıkar)
- `m-recete-duzenle` (form: gün × seans matris düzenleme)
- `m-vaka-kapat` (form: kapatma nedeni + onay + iade edilecek stok önizleme)
- Bunlar mevcut `m-case-det`'in yanına eklendi, **mevcut modal pattern'ine uygun değil**

### Yanlış 2: `.med-*` paralel CSS sınıf sistemi
- `--med-*` tokenlar + `.med-modal`, `.med-ribbon`, `.med-pip`, `.med-session-card`, `.med-undo-chip` vs.
- Uygulamanın geri kalanıyla görsel/dilsel tutarlılık **yok**
- 12px modal radius, JetBrains Mono, scan-line, blink, halo — eklediğim "karanlık monitör" estetiği, ERP'nin pastoral/utility diline aykırı

### Yanlış 3: Render fonksiyonları yanlış yerde
- `openTedaviEkle()`, `openReceteDuzenle()`, `openVakaKapat()`, `renderTedaviEkleForm()`, `renderReceteDuzenleForm()` → `ui.js`'e kondu
- Mevcut pattern: form render'ları `forms.js`'de, modal açma `ui.js`'de. Ben karıştırdım.

### Yanlış 4: m-case-det 3 buton hardcode
- Butonlar `index.html`'e yazıldı (style inline), `data-action` ile tetikleniyor
- Doğru yaklaşım: butonları `renderCaseDet()` (ui.js) içinde dinamik oluştur, mevcut `renderModal` pattern'ini kullan

---

## ✅ Neyi Koruyalım (Revizyon Sonrası da Kalsın)

1. **Ribbon + pure functions** (ui.js):
   - `timeToRatio(timeStr)` — saat → 0..1 ratio
   - `computeSeansState(seans, now)` — 6-state (scheduled/due-soon/now/overdue/done/cancelled)
   - `renderSessionsRibbon(sessions, opts)` — EKG-style 24h timeline (KALMALI — bu işin kalbi)
   - `renderSessionCard(seans, opts)` — session card (kısmen revize)
   - `updateNowCursor()` + `startNowCursorLoop()` — 60s interval (kalsın)
2. **RPC wrappers** (api.js): 4 yeni wrapper'ın tamamı
3. **Config sabitleri** (config.js): 6 sabit
4. **State alanları** (state.js): `tedaviPlan`, `aktifSeansUndo`
5. **`seansTamamla()` handler** (forms.js): optimistic UI + rollback pattern doğru
6. **`openTaskDet` extension** (ui.js): ribbon + session list render — bu iyi, kalsın

---

## 🔧 Revizyon Planı (Önerilen)

### Aşama 1: 3 modal'ı sil
- `index.html`'den `m-tedavi-ekle`, `m-recete-duzenle`, `m-vaka-kapat` template'lerini çıkar
- `.med-modal`, `.med-btn-primary/secondary/danger`, `.med-undo-chip`, `.med-scan-line` CSS'lerini çıkar
- `--med-*` token'larından sadece renkler kalsın (ribbon/pip için), radius ve Mono font çıksın

### Aşama 2: m-case-det'i genişlet
- 3 yeni buton `renderCaseDet()` içinde dinamik oluşturulsun
- Butonlar mevcut "btn" class'ını kullansın (inline style değil)
- Click handler mevcut event delegation'a eklensin (`data-action="..."`)

### Aşama 3: Yeni formları forms.js'e taşı + mevcut modal pattern'ini kullan
- `renderTedaviEkleForm(caseId)` → forms.js
- `renderReceteDuzenleForm(caseId)` → forms.js
- `openVakaKapat(caseId)` → forms.js
- Her biri **mevcut generic modal**'ı (m-generic-form veya benzeri) kullansın, ayrı template değil

### Aşama 4: ui.js'ten 3 opener'ı kaldır
- `openTedaviEkle`, `openReceteDuzenle`, `openVakaKapat` ui.js'ten silinsin
- `renderTedaviEkleForm`, `renderReceteDuzenleForm` silinsin
- `openTaskDet` extension'daki sadece ribbon render kalsın

### Aşama 5: forms.js'ten 3 submit'i revize et
- `submitTedaviEkle`, `submitReceteDuzenle`, `submitVakaKapat` → kalabilir ama mevcut form submit pattern'ine uyarla
- Event delegation'daki `data-action` dispatch'leri sadeleştir

### Aşama 6: Doğrulama
- Mevcut modallara görsel tutarlılık kontrolü (font, radius, spacing)
- Form flow test (aç → doldur → submit → kapan)
- Ribbon + cursor render hâlâ çalışıyor mu

---

## 📋 Mevcut Modal Pattern'i (Referans)

Revizyon yapacak agent/human önce **mevcut modal pattern'ini** okumalı:

| Dosya | Ne var |
|---|---|
| `index.html` | Mevcut modal template'leri: `m-case-det`, `m-task-det`, `m-generic-*` |
| `js/ui.js` | `openM(modalId)`, `closeM()`, `renderModal(...)` helper'ları, `renderCaseDet()` |
| `js/forms.js` | Form render + submit pattern, event delegation |

**Aksiyon:** Önce mevcut pattern'i anla, sonra yeni formları **o pattern'e uydur**. Tersi değil.

---

## ⏭️ Sıradaki Adımlar (Revizyon İçin)

1. **Karar: revert mi, in-place revize mi?**
   - Revert (`git revert 4c732a6`): Temiz başlangıç, ama Faz 5 tamamen sıfırlanır
   - In-place: Yukarıdaki Aşama 1-6'yı uygula, sadece kötü kısımları sıfırla
   - Kullanıcıya sor
2. **Mevcut modal pattern'ini oku** (ui.js'te `openM`, `renderCaseDet`, forms.js'te mevcut submit'ler)
3. **Ribbon visual design'ı gözden geçir** — karanlık monitör estetiği yerine uygulamanın pastoral utility dili
4. **Aşama 1-6'yı uygula**
5. **Doğrula** (görsel + fonksiyonel)
6. **Faz 5 commit'i yeniden yaz** (squash veya yeni commit)
7. **Push** (pre-push hook otomatik çalışır)

---

## 🔗 İlgili Dosyalar

| Dosya | İçerik |
|---|---|
| `js/config.js` (son 29 satır) | 6 yeni sabit (KORUNACAK) |
| `js/state.js` (constructor, 2 alan) | tedaviPlan, aktifSeansUndo (KORUNACAK) |
| `js/api.js` (RPC_TABLES + 4 wrapper) | 5 mapping + 4 wrapper (KORUNACAK) |
| `js/ui.js` (son ~310 satır) | ribbon logic KORUNACAK; 3 modal opener SİLİNECEK |
| `js/forms.js` (son ~215 satır) | seansTamamla KORUNACAK; 3 submit revize edilecek |
| `index.html` (3 modal template + ~100 satır CSS) | 3 modal template SİLİNECEK; `.med-*` büyük kısmı SİLİNECEK |
| `.claude/specs/2026-06-12-bug059-ui-design-klinisyen-monitoru.md` | Spec (OK, implementasyon kötü) |

---

## 🎯 Sonraki Oturum İçin Net Görev

> **Faz 5 revizyonu: 3 modal + paralel CSS'i sil, mevcut pattern'i genişlet**

Sıra:
1. Kullanıcıya sor: revert mi, in-place mi?
2. Mevcut modal pattern'ini oku
3. Revizyon uygula
4. Doğrula + commit + push
5. Faz 6 (E2E) için yeşil ışık
