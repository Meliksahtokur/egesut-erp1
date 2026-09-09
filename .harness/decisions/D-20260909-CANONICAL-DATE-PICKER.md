---
id: D-20260909-CANONICAL-DATE-PICKER
date: 2026-09-09
status: accepted
head: 5d604a5
---

# D-20260909 — Kanonik Tarih Seçimi (Calendar Modal Birliği)

## Context

Sahibe geri bildirimi (2026-09-09, aktif-vakaya-şablon özelliği testi sırasında):
farklı yüzeylerde native tarayıcı takvimi (Firefox'un kendi modalı) ve uygulama
takvimi karışık kullanılıyordu — "UI bütünlüğü bozuluyor, kafanıza göre takvim
eklemeyin". Native takvim modalı uygulamanın tema dilini taşımaz ve tarayıcılar
arasında farklı görünür. Uygulamada zaten iki yerleşik takvim dili vardı:
`gun-tarih-modal` (çoklu seçim, vaka detayı) ve W20 `bc-tarih-takvim`
(tek seçim, toplu vaka tedavi tarihi).

## Decision

Yeni UI yüzeylerinde **native `<input type="date">` kullanılmaz**. Tek-tarih
seçimi kanonik bileşenle yapılır: `js/ui.js:tekTarihTakvimAc({baslik, deger,
onSec})` — alt-sayfa takvim modalı, tek-seçim (hücre tıkı seçimi DEĞİŞTİRİR),
Onayla/İptal. Çoklu-tarih seçimi `js/ui.js:caseGunModalRender`
(`gun-tarih-modal`) ile kalır. Uygulama kuralları:

1. Tek-tarih gerektiren yeni form: görünür buton + (gerekirse) `type="hidden"`
   input kalıbı — takvim `onSec` hem hidden input değerini hem buton etiketini
   yazar; form gönderim akışı değişmez (örn. `cdtTakvimAc`, ui.js).
2. Görsel dil sabittir: `gun-tarih-modal` dili (‹ ›, Pt–Pz ızgarası, yeşil
   seçili hücre); seçim kuralı W20 `bc-tarih-takvim` (forms.js).
3. Toplu-vakanın W20 takvimi (`bcTarihTakvimRender`) kendi yüzeyinde kalır;
   o yüzey yeniden elden geçirilirse kanonik bileşene geçer.
4. Mevcut 10 native date input (k-tarih, i-tarih, tr-tarih, v-date, bv-tarih,
   sk-tarih, b-tarih, a-dt, ta-tarih, td-asi-tarih) bilinçli borç olarak
   listelidir; kademeli göç bekler (ayrı görev).

## Consequences

- Tek-tarih formları tarayıcı-bağımsız, tema-uyumlu tek görünüm sunar;
  uygulama içi takvim dili tek kaynağa (`tekTarihTakvimAc`) iner.
- `ui-map.md` § Canonical date selection bu kararı uygulama haritasına taşır;
  yeni UI işi yapan agent'lar sözleşme gereği bu haritayı okur.
- Kalan 10 native input bilinçli teknik borçtur: her biri kendi form akışı
  test edilerek göçmelidir (gizli-input kalıbı gönderim akışını korur).
- `time` tipi girişler bu kararın kapsamı dışındadır (saat seçiciler yerinde
  kalır; ayrıca ele alınır).
