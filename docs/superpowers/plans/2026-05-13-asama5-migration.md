# Aşama 5 — Migration ve Drift Yönetimi

> **REQUIRED SUB-SKILL:** Use the executing-plans skill.
> **Bağımlılık:** Yok — bağımsız.

**Goal:** Eksik migration'ları tamamla, mevcut migration'ları idempotent yap, ground truth referans dosyası oluştur.

**Tech Stack:** PostgreSQL (Supabase), bash

---

### Task 1: Eksik Migration'ları Bul ve Dosyala

**Files:** Create: `supabase/migrations/20260513000007_eksik_migrationlar.sql` (varsa)

**Step 1: Mevcut migration'ları listele**

```bash
ls supabase/migrations/*.sql | sort
```

**Step 2: ARCHITECTURE.md'de belirtilen 013 ve 014'ü kontrol et**

```bash
if [ -f ARCHITECTURE.md ]; then grep -i "013\|014" ARCHITECTURE.md; else echo "ARCHITECTURE.md bulunamadi — bu task atlanir"; fi
```

**Step 3: Eksik migration varsa dosyala, yoksa task'ı atla**

**Step 4: Commit**

```bash
git add supabase/migrations/
git commit -m "docs: eksik migration'lar tamamlandi (varsa)"
```

---

### Task 2: Idempotent Kontrolleri Ekle

**Files:** Modify: `supabase/migrations/` altındaki migration'lar

**Step 1: IF NOT EXISTS/DROP IF EXISTS eksiklerini tara**

```bash
grep -L "IF NOT EXISTS\|DROP IF EXISTS\|OR REPLACE" supabase/migrations/*.sql
```

**Step 2: ALTER TABLE ADD COLUMN → IF NOT EXISTS ekle**

```sql
-- ESKI: ALTER TABLE hayvanlar ADD COLUMN kisir boolean DEFAULT false;
-- YENI: ALTER TABLE hayvanlar ADD COLUMN IF NOT EXISTS kisir boolean DEFAULT false;
```

**Step 3: Tüm RPC'ler CREATE OR REPLACE kullanıyor mu kontrol et**

```bash
grep "CREATE FUNCTION" supabase/migrations/*.sql | grep -v "OR REPLACE"
# Boş çıkmalı — hepsi OR REPLACE olmalı
```

**Step 4: Commit**

```bash
git add supabase/migrations/
git commit -m "refactor: migration'lar idempotent hale getirildi"
```

---

### Task 3: Ground Truth Migration (Referans)

**Files:** Create: `supabase/migrations/99999999999999_ground_truth.sql`

**Step 1: Tüm migration'ları sıralı birleştir**

```bash
ls supabase/migrations/[0-9]*.sql | sort | xargs cat > supabase/migrations/99999999999999_ground_truth.sql
```

**Step 2: Başına açıklama ekle**

```sql
-- ═══════════════════════════════════════════════════════
-- GROUND TRUTH MIGRATION — REFERANS, CALISTIRMAYIN
-- Tarih: 2026-05-13
-- Tum migration'larin birlestirilmis hali, sifirdan kurulum icin referans.
-- ═══════════════════════════════════════════════════════
```

**Step 3: Commit**

```bash
git add supabase/migrations/99999999999999_ground_truth.sql
git commit -m "docs: ground truth migration referans dosyasi"
```

---

## Test Instructions

```bash
# Migration'lar idempotent mi?
grep -c "CREATE OR REPLACE" supabase/migrations/*.sql | grep -v ":0$"
grep -c "IF NOT EXISTS" supabase/migrations/*.sql | grep -v ":0$"

# Ground truth var mi?
wc -l supabase/migrations/99999999999999_ground_truth.sql
```
