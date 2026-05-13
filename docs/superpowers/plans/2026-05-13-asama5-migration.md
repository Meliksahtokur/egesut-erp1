# Aşama 5 — Migration ve Drift Yönetimi

> **REQUIRED SUB-SKILL:** Use the executing-plans skill.

**Goal:** Eksik migration'ları tamamla, ground truth oluştur, mevcut migration'ları idempotent yap.

**Architecture:** `supabase db diff` ile canlı DB'den eksik migration'lar çıkarılır, `IF NOT EXISTS` kontrolleri eklenir.

**Tech Stack:** PostgreSQL (Supabase), bash

---

### Task 1: Eksik Migration'ları Bul ve Dosyala

**Files:** Create: `supabase/migrations/20260513000007_eksik_migrationlar.sql`

**Step 1: Mevcut migration'ları listele**

```bash
ls supabase/migrations/*.sql | sort
```

**Step 2: ARCHITECTURE.md'de belirtilen 013 ve 014'ü kontrol et**

```bash
grep -i "013\|014" ARCHITECTURE.md 2>/dev/null || echo "ARCHITECTURE.md yok"
```

**Step 3: Eksikleri belirle ve dosyala**

Migration numaralarında boşluk varsa, atlanmış olanları not et. Yeni migration dosyası oluştur.

**Step 4: Commit**

---

### Task 2: Idempotent Kontrolleri Ekle

**Files:** Modify: `supabase/migrations/` altındaki migration'lar

**Step 1: IF NOT EXISTS/DROP IF EXISTS eksiklerini tara**

```bash
grep -L "IF NOT EXISTS\|DROP IF EXISTS" supabase/migrations/*.sql | head -20
```

**Step 2: ALTER TABLE ADD COLUMN → IF NOT EXISTS ekle**

```sql
-- ESKI:
ALTER TABLE hayvanlar ADD COLUMN kisir boolean DEFAULT false;

-- YENI:
ALTER TABLE hayvanlar ADD COLUMN IF NOT EXISTS kisir boolean DEFAULT false;
```

**Step 3: CREATE OR REPLACE kullanıldığından emin ol**

Tüm RPC'ler `CREATE OR REPLACE FUNCTION` ile başlamalı.

**Step 4: Commit**

---

### Task 3: Ground Truth Migration (Referans)

**Files:** Create: `supabase/migrations/99999999999999_ground_truth.sql`

**Step 1: Tüm migration'ları birleştir**

```bash
cat supabase/migrations/20*.sql > supabase/migrations/99999999999999_ground_truth.sql
```

**Step 2: Başına açıklama ekle**

```sql
-- ═══════════════════════════════════════════════════════
-- GROUND TRUTH MIGRATION (REFERANS — CALISTIRMAYIN)
-- Tarih: 2026-05-13
-- Bu dosya tum migration'larin birlestirilmis halidir.
-- Sadece referans amacli — normal gelistirmede calistirilmaz.
-- ═══════════════════════════════════════════════════════
```

**Step 3: Commit**

---

## Test Instructions

```bash
# Migration'lar idempotent mi?
grep -c "CREATE OR REPLACE" supabase/migrations/*.sql
grep -c "IF NOT EXISTS" supabase/migrations/*.sql
```
