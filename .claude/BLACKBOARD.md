# Gwen Task Board

**Güncelleme:** 2026-04-01 17:30

> Canlı task dağıtım tablosu. Her Gwen giriş yapar, task alır, çıkış yapar.

---

## 🔒 Departman İzolasyonu

```
┌─────────────────────────────────────────────────────────┐
│  İZOLASYON KURALI — KRİTİK                              │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  🏭 DEV AGENT:                                          │
│     - SADECE dev task'larını görür                      │
│     - ARGE task'ları GİZLİ                              │
│                                                         │
│  🔬 ARGE AGENT:                                         │
│     - SADECE arge task'larını görür                     │
│     - DEV task'ları GİZLİ                               │
│                                                         │
│  AMAÇ:                                                  │
│  - Çakışma önleme                                       │
│  - Odaklanma                                            │
│  - Departman otonomisi                                  │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 🏭 DEV Task'ları (SADECE DEV AGENT GÖRÜR)

### 🏃 Aktif Dev Task'ları

| Task | Session | Agent | Durum | Başlangıç | Dosyalar |
|------|---------|-------|-------|-----------|----------|
| — | — | — | — | — | — |

### 📋 Bekleyen Dev Task'ları

| Task | Session | Öncelik | Açıklama |
|------|---------|---------|----------|
| task-dev-007 | dev | yüksek | UI bug fix'leri |
| task-dev-008 | dev | tamamlandı | UI telemetry (merge bekliyor) |

### ✅ Tamamlanan Dev Task'ları (Son 24s)

| Task | Session | Bitiş | Merge |
|------|---------|-------|-------|
| task-bug003-revize | dev | 2026-04-02 05:50 | ⏳ review bekliyor |
| task-dev-006 | dev | 14:00 | ✅ |

---

## 🔬 ARGE Task'ları (SADECE ARGE AGENT GÖRÜR)

### 🏃 Aktif Arge Task'ları

| Task | Session | Agent | Durum | Başlangıç | Dosyalar |
|------|---------|-------|-------|-----------|----------|
| — | — | — | — | — | — |

### 📋 Bekleyen Arge Task'ları

| Task | Session | Öncelik | Açıklama |
|------|---------|---------|----------|
| task-arge-007 | arge | orta | Sıradaki task |

### ✅ Tamamlanan Arge Task'ları (Son 24s)

| Task | Session | Bitiş | Merge |
|------|---------|-------|-------|
| task-arge-004 | arge | 21:35 | ✅ (repo dışı) |
| task-arge-006 | arge | 17:45 | ✅ |
| task-arge-002 | arge | 15:45 | ⏳ bekliyor |
| task-arge-003 | arge | 16:30 | ⏳ bekliyor |
| task-arge-005 | arge | 17:15 | ⏳ bekliyor |

---

## 📜 Otonom Workflow

**Yeni task alırken:**
1. **Kendi departmanının bölümünü oku** (DEV veya ARGE)
2. Başka Gwen'in yaptığı task'a DOKUNMA
3. Boş task seç
4. BLACKBOARD.md güncelle → "devam ediyor"

**Çalışırken:**
- SADECE kendi task dosyalarına dokun
- Başka departmanın dosyalarına YASAK

**Bitirirken (OTONOM):**
1. `/review` → gwen-reviewer agent'ı çalışır
2. ✅ PUSH ONAYLI → Direkt push (SORMA!)
3. ❌ PUSH BLOKE → Otonom fix + tekrar review (max 3 deneme)
4. **Kendi departmanının bölümünü güncelle** → "tamamlandı"
5. task-XXX-done.md yaz
6. SONRAKI TASK'A GEÇ (otonom)

**⚠️ REVIEW ZORUNLULUĞU:**
- `/review` komutu → gwen-reviewer agent'ı çalışır
- general-purpose YASAK!
- ✅ PUSH ONAYLI → SORMADAN push et!
- ❌ PUSH BLOKE → Otonom fix loop (kullanıcıya sorma!)

---

## 🔄 Otonom Fix Loop

```
❌ PUSH BLOKE gelirse:
1. Raporu oku
2. Hataları tespit et
3. Otonom düzelt (SORMA!)
4. git add + git commit -m "fix: [açıklama]"
5. TEKRAR /review
6. Loop → ✅ PUSH ONAYLI veya 3 deneme
```

**Max 3 deneme başarısız → Kullanıcıya rapor et**
