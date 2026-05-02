# Task-arge-004: Gwen Kalite Araçları — Reviewer + Domain Skill

**Durum:** bekliyor
**Branch:** gwen/arge
**Session:** arge

---

## Açıklama

Developer'ın ihtiyaç analizinden (FULLSTACK_AGENT ihtiyaclar.md) gelen geçerli istekler.
MCP kararı nedeniyle MCP tabanlı istekler düştü. Geriye kalan: reviewer güçlendirme + domain skill zenginleştirme.

---

## 1. gwen-reviewer güçlendir

Dosya: `/root/.qwen/agents/gwen-reviewer.md`

Mevcut reviewer'a şu custom check kurallarını ekle:

### RPC Bypass Tespiti
```
- supabase.from('X').insert() → YASAK (RPC kullan)
- supabase.from('X').update() → YASAK (RPC kullan)
- supabase.from('X').delete() → YASAK (RPC kullan)
- İstisna: ui_logs tablosu (telemetry — direkt insert OK)
```

### Duplikat Fonksiyon Kontrolü
```
- git diff HEAD içindeki her yeni fonksiyon adını grep ile tüm js/*.js'de ara
- Aynı isim başka dosyada varsa → BLOKE + rapor et
```

### Türkçe Mesaj Kontrolü
```
- toast() çağrılarında İngilizce string varsa → UYARI (bloke değil)
- alert() kullanımı → UYARI (toast kullan)
```

### State Machine İhlali
```
- tohumlama tablosuna direkt write → BLOKE
- dogum tablosuna direkt write → BLOKE
```

---

## 2. egesut-fullstack skill zenginleştir

Dosya: `/root/.qwen/skills/egesut-fullstack/SKILL.md`

Şu bölümleri ekle/güncelle:

### RPC Hızlı Referans (en çok kullanılanlar)
```
tohumlama_kaydet(p_hayvan_id, p_tarih, p_sperma_kodu, p_teknisyen)
tohumlama_sonuc_gebe(p_tohumlama_id)
tohumlama_sonuc_bos(p_tohumlama_id)
dogum_kaydet(p_anne_id, p_tarih, p_buzagi_cinsiyet, p_buzagi_kupe)
hayvan_ekle(p_kupe_no, p_grup_id, p_dogum_tarihi, p_cinsiyet)
hayvan_guncelle(p_id, p_alan, p_deger)
hastalik_kaydet / hastalik_kapat / hastalik_sil
tedavi_ekle / tedavi_sil / tedavi_guncelle
```

### Yaygın Hata Kalıpları
```
❌ supabase.from('tohumlama').insert() → ✅ rpc('tohumlama_kaydet', {...})
❌ supabase.from('hayvanlar').update() → ✅ rpc('hayvan_guncelle', {...})
❌ write('tohumlama', ...) → ✅ rpcOptimistic('tohumlama_kaydet', {...})
```

### Context Yükleme Rehberi
```
Tohumlama işi → domain-rules.md bölüm 4 + rpc-reference.md tohumlama bölümü
Doğum işi    → domain-rules.md bölüm 5 + rpc-reference.md dogum bölümü
Hastalık işi → domain-rules.md bölüm 6 + rpc-reference.md hastalik bölümü
UI işi       → ui-map.md ilgili bölüm
```

---

## 3. gwen.md — Dokümantasyon Kuralı

Dosya: `/root/.qwen/agents/gwen.md`

MCP Kullanımı bölümüne şu kuralı ekle:

```markdown
### Dokümantasyon Araştırma (KRİTİK)
✅ context7 MCP → mcp__context7__resolve-library-id + mcp__context7__get-library-docs
❌ Dokümantasyon için agent spawn YASAK
❌ web_search YASAK — context7 yeterli

Kütüphane adı `gwen-context7` değil → `context7`
```

---

## Kabul Kriterleri

- [ ] gwen-reviewer'da RPC bypass, duplikat, Türkçe mesaj, state machine kuralları var
- [ ] egesut-fullstack skill'de RPC hızlı referans var
- [ ] egesut-fullstack skill'de yaygın hata kalıpları var
- [ ] egesut-fullstack skill'de context yükleme rehberi var
- [ ] gwen.md'de dokümantasyon → context7 kuralı var, MCP adı düzeltildi
- [ ] Branch: gwen/arge
- [ ] js/ dosyalarına dokunma
- [ ] Tamamlanınca `task-arge-004-done.md` yaz
